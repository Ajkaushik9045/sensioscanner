import 'package:dartz/dartz.dart' hide Unit;
import 'package:dartz/dartz.dart' as dartz show Unit;
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'
    hide CharacteristicValue;

import '../../core/error/failures.dart';
import '../entities/ble_connection_status.dart';
import '../entities/ble_device.dart';
import '../entities/ble_service.dart';
import '../entities/characteristic_value.dart' as domain;

/// Contract for all BLE operations.
///
/// Lives in the domain layer — has NO dependency on flutter_reactive_ble
/// except for the [Uuid] and [QualifiedCharacteristic] types which are
/// BLE-fundamental and re-exported cleanly by the package.
///
/// Consumers (BLoCs, use-cases, tests) depend only on this interface.
/// The concrete implementation ([BleRepositoryImpl]) lives in the data layer.
abstract interface class IBleRepository {
  // ── Scanning ───────────────────────────────────────────────────────────────

  /// Starts scanning for nearby BLE devices and emits deduplicated device lists.
  ///
  /// - Devices are identified by [BleDevice.id]; repeat advertisements update
  ///   the [BleDevice.rssi] in-place without adding a duplicate entry.
  /// - The emitted list is sorted by RSSI descending (strongest signal first).
  /// - Subscribers receive the last known list immediately upon subscription
  ///   (BehaviorSubject replay semantics).
  ///
  /// [withServices]: optional service UUID filter — only devices advertising
  /// these UUIDs appear in results. Pass an empty list to discover all devices.
  ///
  /// Calling this method a second time cancels the previous scan before
  /// starting a new one.
  Stream<Either<BleFailure, List<BleDevice>>> scanDevices({
    List<Uuid> withServices,
  });

  /// Stops any active scan. No-op if not scanning.
  Future<void> stopScan();

  // ── Connection ─────────────────────────────────────────────────────────────

  /// Initiates a connection to [deviceId] and streams state transitions.
  ///
  /// The first emitted value is always [BleConnectionStatus.connecting].
  ///
  /// State machine: connecting → connected → [disconnected | error]
  /// (The [discovering] and [ready] states are produced by
  /// [discoverServices] — see usage in the device-detail BLoC.)
  ///
  /// The stream completes when the device reaches a terminal state
  /// ([BleConnectionStatus.disconnected] or [BleConnectionStatus.error]).
  Stream<BleConnectionStatus> connectToDevice(String deviceId);

  // ── Service Discovery ──────────────────────────────────────────────────────

  /// Performs GATT service and characteristic discovery on a connected device.
  ///
  /// [timeout]: maximum time to wait for the peripheral's GATT stack to respond.
  /// Defaults to 5 seconds — increase for known slow peripherals.
  ///
  /// Returns [Right(services)] on success, or a [Left(GattFailure)] on timeout
  /// or discovery error.
  Future<Either<BleFailure, List<BleService>>> discoverServices(
    String deviceId, {
    Duration timeout,
  });

  // ── Characteristic Operations ──────────────────────────────────────────────

  /// Subscribes to a characteristic's notifications or indications.
  ///
  /// Backpressure is applied: events are throttled so the UI is never
  /// overwhelmed by high-frequency peripherals (e.g. IMU at 100 Hz).
  ///
  /// Errors are surfaced as [Left(CharacteristicFailure)] events — the stream
  /// does NOT close on error; it keeps running so transient errors are
  /// recoverable without re-subscribing.
  Stream<Either<BleFailure, domain.CharacteristicValue>> subscribeToCharacteristic(
    QualifiedCharacteristic characteristic,
  );

  // ── Disconnect ─────────────────────────────────────────────────────────────

  /// Disconnects from [deviceId].
  ///
  /// Cancels the active connection subscription for this device, which signals
  /// flutter_reactive_ble to close the GATT connection.
  /// No-op (returns [Right(unit)]) if the device is already disconnected.
  Future<Either<BleFailure, dartz.Unit>> disconnect(String deviceId);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Disposes all active scans, connections, and stream controllers.
  ///
  /// Must be called when the app is permanently done with BLE (e.g. on logout
  /// or app termination). After calling this, the repository must not be used.
  Future<void> dispose();
}
