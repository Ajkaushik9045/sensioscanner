import 'dart:async';

// Hide conflicting names from flutter_reactive_ble:
//   • CharacteristicValue — clashes with our domain entity of the same name
//   • ScanFailure — FRB exports an enum ScanFailure; ours is a class
//   • Unit — FRB and dartz both export a Unit type
import 'package:dartz/dartz.dart' hide Unit;
import 'package:dartz/dartz.dart' as dartz show Unit, unit;
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'
    hide CharacteristicValue, ScanFailure, Unit;
import 'package:rxdart/rxdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/ble_characteristic.dart';
import '../../domain/entities/ble_connection_status.dart';
import '../../domain/entities/ble_device.dart';
import '../../domain/entities/ble_service.dart';
import '../../domain/entities/characteristic_value.dart' as domain;
import '../../domain/repositories/i_ble_repository.dart';

/// Concrete [IBleRepository] implementation backed by [FlutterReactiveBle].
///
/// Responsibilities:
///   • Scan deduplication — same device ID → update RSSI in-place, re-sort
///   • Connection lifecycle — manages subscriptions, emits terminal events
///   • GATT discovery via discoverAllServices + getDiscoveredServices (current API)
///   • Characteristic subscription with 50 ms throttle (backpressure)
///   • Converts all flutter_reactive_ble types to pure domain entities
final class BleRepositoryImpl implements IBleRepository {
  BleRepositoryImpl(this._ble);

  final FlutterReactiveBle _ble;

  // ── Scan state ─────────────────────────────────────────────────────────────

  /// Deduplication map: deviceId → most recent device advertisement.
  final Map<String, BleDevice> _scannedDevices = {};

  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  /// BehaviorSubject gives new subscribers the last-known device list
  /// immediately — critical for screen rebuilds (e.g. rotation).
  final BehaviorSubject<Either<BleFailure, List<BleDevice>>> _scanSubject =
      BehaviorSubject();

  // ── Connection state ───────────────────────────────────────────────────────

  /// Active BLE connection subscriptions, keyed by deviceId.
  final Map<String, StreamSubscription<ConnectionStateUpdate>> _connectionSubs =
      {};

  /// Per-device stream controllers for connection state events.
  final Map<String, StreamController<BleConnectionStatus>>
      _connectionControllers = {};

  // ── Scan ───────────────────────────────────────────────────────────────────

  @override
  Stream<Either<BleFailure, List<BleDevice>>> scanDevices({
    List<Uuid> withServices = const [],
  }) {
    _startScanInternal(withServices);
    return _scanSubject.stream;
  }

  Future<void> _startScanInternal(List<Uuid> withServices) async {
    // Cancel any in-progress scan and wait a moment for the Android BLE stack
    // to actually stop the scan to prevent SCAN_FAILED_ALREADY_STARTED (code 1).
    await stopScan();
    await Future.delayed(const Duration(milliseconds: 250));

    _scannedDevices.clear();
    // Reset the scan subject to clear any cached errors from a previous scan
    _scanSubject.add(const Right([]));

    _scanSubscription = _ble
        .scanForDevices(
          withServices: withServices,
          scanMode: ScanMode.lowLatency,
        )
        .listen(
          _onScanResult,
          onError: (Object error) {
            debugPrint('[BleRepo] Scan error: $error');
            final errStr = error.toString();
            String message = errStr;
            
            // "Bluetooth disabled" string is thrown natively by the scanner in some conditions.
            // DO NOT map "code 1" to "Bluetooth disabled", code 1 is SCAN_FAILED_ALREADY_STARTED.
            if (errStr.contains('Bluetooth disabled') || errStr.toLowerCase().contains('bluetooth is turned off')) {
              message = 'Bluetooth is turned off. Please enable it to scan for nearby devices.';
            } else if (errStr.contains('Location services disabled') || errStr.contains('code 3')) {
              message = 'Location services are disabled. Please enable them to scan for BLE devices.';
            } else if (errStr.contains('code 1')) {
              message = 'Scan already in progress. Please wait a moment and try again.';
            } else {
              message = 'Scan failed: $errStr';
            }
            
            _scanSubject.add(Left(ScanFailure(message)));
          },
        );
  }

  void _onScanResult(DiscoveredDevice result) {
    final device = _mapDiscoveredDevice(result);
    // Deduplicate: same id → replace so RSSI is always up-to-date.
    _scannedDevices[device.id] = device;

    // Sort by RSSI descending (strongest signal first).
    final sorted = _scannedDevices.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    _scanSubject.add(Right(sorted));
  }

  @override
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  // ── Connection ─────────────────────────────────────────────────────────────

  @override
  Stream<BleConnectionStatus> connectToDevice(String deviceId) {
    // Tear down any stale connection for this device before starting fresh.
    _tearDownConnection(deviceId);

    final controller = StreamController<BleConnectionStatus>();
    _connectionControllers[deviceId] = controller;

    controller.onCancel = () => _tearDownConnection(deviceId);

    // onListen fires synchronously when the caller subscribes.
    // Emitting [connecting] here guarantees it's always the first event —
    // even before the BLE stack produces its first ConnectionStateUpdate.
    controller.onListen = () async {
      if (!controller.isClosed) {
        controller.add(BleConnectionStatus.connecting);
      }

      // CRITICAL FOR ANDROID: Stop any active scan before attempting to connect.
      // Scanning while connecting is highly unreliable and often causes the 
      // connection attempt to hang indefinitely or fail.
      await stopScan();

      final sub = _ble
          .connectToDevice(
            id: deviceId,
            connectionTimeout: const Duration(seconds: 10),
          )
          .listen(
            (update) => _onConnectionUpdate(deviceId, update, controller),
            onError: (Object error) {
              debugPrint('[BleRepo] Connection error for $deviceId: $error');
              if (!controller.isClosed) {
                controller
                  ..add(BleConnectionStatus.error)
                  ..close();
              }
              _connectionSubs.remove(deviceId);
              _connectionControllers.remove(deviceId);
            },
            onDone: () {
              if (!controller.isClosed) {
                controller
                  ..add(BleConnectionStatus.disconnected)
                  ..close();
              }
              _connectionSubs.remove(deviceId);
              _connectionControllers.remove(deviceId);
            },
          );

      _connectionSubs[deviceId] = sub;
    };

    return controller.stream;
  }

  void _onConnectionUpdate(
    String deviceId,
    ConnectionStateUpdate update,
    StreamController<BleConnectionStatus> controller,
  ) {
    if (controller.isClosed) return;

    final status = _mapConnectionState(update.connectionState);
    debugPrint('[BleRepo] $deviceId → $status');
    controller.add(status);

    if (status.isTerminal) {
      controller.close();
      _connectionSubs.remove(deviceId);
      _connectionControllers.remove(deviceId);
    }
  }

  void _tearDownConnection(String deviceId) {
    _connectionSubs[deviceId]?.cancel();
    _connectionSubs.remove(deviceId);

    final ctrl = _connectionControllers[deviceId];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.close();
    }
    _connectionControllers.remove(deviceId);
  }

  // ── Service Discovery ──────────────────────────────────────────────────────

  @override
  Future<Either<BleFailure, List<BleService>>> discoverServices(
    String deviceId, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      // New API (flutter_reactive_ble ≥ 5.x):
      //   1. discoverAllServices(deviceId) → Future<void>  — triggers discovery
      //   2. getDiscoveredServices(deviceId) → Future<List<Service>> — reads results
      // The deprecated discoverServices() combined both steps but returned
      // List<DiscoveredService> with a different model.
      await _ble.discoverAllServices(deviceId).timeout(timeout);
      final services = await _ble.getDiscoveredServices(deviceId);

      final mapped = services.map((s) => _mapService(s, deviceId)).toList();
      debugPrint('[BleRepo] ${mapped.length} services discovered for $deviceId');
      return Right(mapped);
    } on TimeoutException {
      const msg =
          'Service discovery timed out. The peripheral may have a slow GATT '
          'stack — try increasing the timeout or reconnecting.';
      debugPrint('[BleRepo] GATT timeout for $deviceId');
      return const Left(GattFailure(msg));
    } catch (e) {
      debugPrint('[BleRepo] GATT error for $deviceId: $e');
      return Left(GattFailure('Service discovery failed: $e'));
    }
  }

  // ── MTU Negotiation ────────────────────────────────────────────────────────

  @override
  Future<Either<BleFailure, int>> requestMtu(String deviceId, int mtu) async {
    try {
      final negotiated =
          await _ble.requestMtu(deviceId: deviceId, mtu: mtu);
      debugPrint('[BleRepo] MTU negotiated to $negotiated for $deviceId');
      return Right(negotiated);
    } catch (e) {
      // MTU negotiation is best-effort; log and continue.
      debugPrint('[BleRepo] MTU negotiation failed for $deviceId: $e');
      return Left(GattFailure('MTU negotiation failed: $e'));
    }
  }

  // ── Characteristic Subscription ────────────────────────────────────────────


  @override
  Stream<Either<BleFailure, domain.CharacteristicValue>>
      subscribeToCharacteristic(
    QualifiedCharacteristic characteristic,
  ) {
    return _ble
        .subscribeToCharacteristic(characteristic)
        // ── Backpressure ───────────────────────────────────────────────────
        // Throttle to 1 event per 50 ms (leading edge, drop trailing bursts).
        // A 4 Hz heart-rate sensor emits every 250 ms — safe headroom.
        // A 100 Hz IMU would flood the Dart event queue without this;
        // with throttling at most ~20 values/s reach the BLoC.
        .throttleTime(
          const Duration(milliseconds: 50),
          leading: true,
          trailing: false,
        )
        // ── Error materialisation ──────────────────────────────────────────
        // Use StreamTransformer so errors become Left() events rather than
        // closing the stream. Transient GATT errors are surfaced to the UI
        // without requiring a full re-subscribe.
        .transform(
          StreamTransformer<List<int>,
              Either<BleFailure, domain.CharacteristicValue>>.fromHandlers(
            handleData: (data, sink) {
              sink.add(
                Right(
                  domain.CharacteristicValue(
                    characteristicUuid:
                        characteristic.characteristicId.toString(),
                    serviceUuid: characteristic.serviceId.toString(),
                    deviceId: characteristic.deviceId,
                    value: data,
                    timestamp: DateTime.now(),
                  ),
                ),
              );
            },
            handleError: (error, stackTrace, sink) {
              debugPrint(
                '[BleRepo] Characteristic error '
                '(${characteristic.characteristicId}): $error',
              );
              sink.add(Left(CharacteristicFailure(error.toString())));
            },
          ),
        );
  }

  // ── Characteristic Read ──────────────────────────────────────────────────────

  @override
  Future<Either<BleFailure, domain.CharacteristicValue>> readCharacteristic(
    QualifiedCharacteristic characteristic,
  ) async {
    try {
      final data = await _ble.readCharacteristic(characteristic);
      return Right(
        domain.CharacteristicValue(
          characteristicUuid: characteristic.characteristicId.toString(),
          serviceUuid: characteristic.serviceId.toString(),
          deviceId: characteristic.deviceId,
          value: data,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint(
        '[BleRepo] Read error (${characteristic.characteristicId}): $e',
      );
      return Left(CharacteristicFailure('Read failed: $e'));
    }
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────

  @override
  Future<Either<BleFailure, dartz.Unit>> disconnect(String deviceId) async {
    try {
      // Cancelling the connectToDevice subscription signals flutter_reactive_ble
      // to close the GATT connection. There is no explicit "disconnect" call.
      _tearDownConnection(deviceId);
      debugPrint('[BleRepo] Disconnected from $deviceId');
      return const Right(dartz.unit);
    } catch (e) {
      debugPrint('[BleRepo] Disconnect error for $deviceId: $e');
      return Left(ConnectionFailure('Failed to disconnect: $e'));
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    await stopScan();
    await _scanSubject.close();

    for (final deviceId in List<String>.from(_connectionControllers.keys)) {
      _tearDownConnection(deviceId);
    }
  }

  // ── Mappers ────────────────────────────────────────────────────────────────

  BleDevice _mapDiscoveredDevice(DiscoveredDevice result) {
    return BleDevice(
      id: result.id,
      name: result.name.isEmpty ? 'Unknown Device' : result.name,
      rssi: result.rssi,
      // Connectable.available = peripheral explicitly advertises connectability.
      // Connectable.unknown   = flag absent from advertisement packet.
      // We treat unknown as connectable so the user can at least attempt it.
      isConnectable: result.connectable != Connectable.unavailable,
      // manufacturerData is a flat Uint8List; store as a single entry
      // under key 0 when present, empty map when not.
      manufacturerData: result.manufacturerData.isNotEmpty
          ? {0: List<int>.from(result.manufacturerData)}
          : const {},
    );
  }

  BleConnectionStatus _mapConnectionState(DeviceConnectionState state) {
    return switch (state) {
      DeviceConnectionState.connecting => BleConnectionStatus.connecting,
      DeviceConnectionState.connected => BleConnectionStatus.connected,
      DeviceConnectionState.disconnecting => BleConnectionStatus.disconnecting,
      DeviceConnectionState.disconnected => BleConnectionStatus.disconnected,
    };
  }

  // Maps flutter_reactive_ble's new Service model to our domain BleService.
  BleService _mapService(Service service, String deviceId) {
    final characteristics = service.characteristics
        .map((c) => _mapCharacteristic(c, service))
        .toList();

    return BleService(
      uuid: service.id.toString(),
      deviceId: deviceId,
      characteristics: characteristics,
    );
  }

  BleCharacteristic _mapCharacteristic(Characteristic char, Service service) {
    final properties = <CharacteristicProperty>[];
    if (char.isReadable) properties.add(CharacteristicProperty.read);
    if (char.isWritableWithResponse) {
      properties.add(CharacteristicProperty.write);
    }
    if (char.isWritableWithoutResponse) {
      properties.add(CharacteristicProperty.writeWithoutResponse);
    }
    if (char.isNotifiable) properties.add(CharacteristicProperty.notify);
    if (char.isIndicatable) properties.add(CharacteristicProperty.indicate);

    return BleCharacteristic(
      uuid: char.id.toString(),
      serviceUuid: service.id.toString(),
      deviceId: service.deviceId,
      properties: List.unmodifiable(properties),
      // flutter_reactive_ble v5 does not expose GATT descriptors.
      // This list will remain empty until explicit descriptor reads are added.
      descriptors: const [],
    );
  }
}
