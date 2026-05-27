import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart' hide Unit;
import 'package:flutter/foundation.dart';
import '../../../../core/error/failures.dart';
import '../../../ble/domain/entities/ble_connection_status.dart';
import '../../../ble/domain/entities/characteristic_value.dart' as domain;
import '../../domain/usecases/connect_to_device_use_case.dart';
import '../../domain/usecases/disconnect_device_use_case.dart';
import '../../domain/usecases/discover_services_use_case.dart';
import '../../domain/usecases/request_mtu_use_case.dart';
import '../../domain/usecases/subscribe_to_characteristic_use_case.dart';
import '../../../history/domain/usecases/save_device_to_history_use_case.dart';
import 'device_detail_event.dart';
import 'device_detail_state.dart';

/// BLoC governing the full device detail lifecycle.
///
/// Responsibilities:
///   • Connection state machine (connecting → connected → lost → retry)
///   • MTU negotiation (best-effort, after transport connect)
///   • GATT service discovery (with timeout)
///   • Multiple characteristic subscriptions with backpressure
///   • Auto-reconnect with exponential backoff (1 s, 2 s, 4 s, max 3 attempts)
///   • GATT 133 detection and special 600 ms retry path
///   • Clean teardown on user disconnect or BLoC close
class DeviceDetailBloc extends Bloc<DeviceDetailEvent, DeviceDetailState> {
  DeviceDetailBloc({
    required ConnectToDeviceUseCase connectToDeviceUseCase,
    required DisconnectDeviceUseCase disconnectDeviceUseCase,
    required DiscoverServicesUseCase discoverServicesUseCase,
    required RequestMtuUseCase requestMtuUseCase,
    required SubscribeToCharacteristicUseCase subscribeToCharacteristicUseCase,
    required SaveDeviceToHistoryUseCase saveDeviceToHistoryUseCase,
  })  : _connectToDevice = connectToDeviceUseCase,
        _disconnectDevice = disconnectDeviceUseCase,
        _discoverServices = discoverServicesUseCase,
        _requestMtu = requestMtuUseCase,
        _subscribeToCharacteristic = subscribeToCharacteristicUseCase,
        _saveDeviceToHistory = saveDeviceToHistoryUseCase,
        super(const DetailInitial()) {
    on<ConnectToDeviceEvent>(_onConnect);
    on<DisconnectDeviceEvent>(_onDisconnect);
    on<ManualReconnectEvent>(_onManualReconnect);
    on<SubscribeToCharacteristicEvent>(_onSubscribe);
    on<UnsubscribeFromCharacteristicEvent>(_onUnsubscribe);
    on<ConnectionStateChangedEvent>(_onConnectionStateChanged);
    on<ValueReceivedEvent>(_onValueReceived);
    on<SubscriptionErrorEvent>(_onSubscriptionError);
    on<AttemptAutoReconnectEvent>(_onAttemptAutoReconnect);
  }

  final ConnectToDeviceUseCase _connectToDevice;
  final DisconnectDeviceUseCase _disconnectDevice;
  final DiscoverServicesUseCase _discoverServices;
  final RequestMtuUseCase _requestMtu;
  final SubscribeToCharacteristicUseCase _subscribeToCharacteristic;
  final SaveDeviceToHistoryUseCase _saveDeviceToHistory;

  // ── Device identity (set once on ConnectToDeviceEvent) ─────────────────────
  String? _deviceId;
  String? _deviceName;

  // ── Connection subscription ────────────────────────────────────────────────
  StreamSubscription<BleConnectionStatus>? _connectionSub;

  // ── Characteristic subscriptions (one per char UUID) ──────────────────────
  final Map<String, StreamSubscription<Either<BleFailure, domain.CharacteristicValue>>>
      _charSubs = {};

  // ── Reconnect state ────────────────────────────────────────────────────────
  static const int maxReconnects = 3;
  static const List<Duration> _backoffDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];
  int _reconnectAttempt = 0;
  bool _userInitiatedDisconnect = false;
  Timer? _reconnectTimer;

  // ─────────────────────────────────────────────────────────────────────────────
  // Public event handlers
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _onConnect(
    ConnectToDeviceEvent event,
    Emitter<DeviceDetailState> emit,
  ) async {
    _deviceId = event.deviceId;
    _deviceName = event.deviceName;
    _userInitiatedDisconnect = false;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();

    emit(DetailConnecting(deviceId: event.deviceId, deviceName: event.deviceName));
    await _startConnection();
  }

  Future<void> _onDisconnect(
    DisconnectDeviceEvent event,
    Emitter<DeviceDetailState> emit,
  ) async {
    final deviceId = _deviceId;
    final deviceName = _deviceName;
    if (deviceId == null || deviceName == null) return;

    _userInitiatedDisconnect = true;
    _reconnectTimer?.cancel();

    emit(DetailDisconnecting(deviceId: deviceId, deviceName: deviceName));
    await _cancelAllCharSubscriptions();
    await _connectionSub?.cancel();
    _connectionSub = null;
    await _disconnectDevice(deviceId);
    emit(const DetailDisconnected());
  }

  Future<void> _onManualReconnect(
    ManualReconnectEvent event,
    Emitter<DeviceDetailState> emit,
  ) async {
    final deviceId = _deviceId;
    final deviceName = _deviceName;
    if (deviceId == null || deviceName == null) return;

    _userInitiatedDisconnect = false;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();

    emit(DetailConnecting(deviceId: deviceId, deviceName: deviceName));
    await _startConnection();
  }

  Future<void> _onSubscribe(
    SubscribeToCharacteristicEvent event,
    Emitter<DeviceDetailState> emit,
  ) async {
    if (state is! DetailConnected) return;
    final current = state as DetailConnected;

    // Cancel previous subscription for a different characteristic.
    final prevUuid = current.activeCharacteristic?.uuid;
    if (prevUuid != null && prevUuid != event.bleCharacteristic.uuid) {
      await _charSubs[prevUuid]?.cancel();
      _charSubs.remove(prevUuid);
    }

    emit(current.copyWith(
      activeCharacteristic: event.bleCharacteristic,
      isSubscribing: true,
      clearActiveChar: false,
      clearSubscriptionError: true,
    ));

    final sub = _subscribeToCharacteristic(event.qualifiedCharacteristic)
        .listen((either) {
      if (isClosed) return;
      either.fold(
        (failure) => add(SubscriptionErrorEvent(failure)),
        (value) => add(ValueReceivedEvent(value)),
      );
    });

    _charSubs[event.bleCharacteristic.uuid] = sub;

    // If we're still in the subscribing state (not blown away by a disconnect),
    // mark subscribing as done.
    if (state is DetailConnected) {
      emit((state as DetailConnected).copyWith(isSubscribing: false));
    }
  }

  Future<void> _onUnsubscribe(
    UnsubscribeFromCharacteristicEvent event,
    Emitter<DeviceDetailState> emit,
  ) async {
    if (state is! DetailConnected) return;
    final current = state as DetailConnected;

    final uuid = current.activeCharacteristic?.uuid;
    if (uuid != null) {
      await _charSubs[uuid]?.cancel();
      _charSubs.remove(uuid);
    }

    emit(current.copyWith(clearActiveChar: true, clearSubscriptionError: true));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Internal event handlers
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _onConnectionStateChanged(
    ConnectionStateChangedEvent event,
    Emitter<DeviceDetailState> emit,
  ) async {
    final deviceId = _deviceId!;
    final deviceName = _deviceName!;

    switch (event.status) {
      case BleConnectionStatus.connecting:
        if (state is! DetailConnecting) {
          emit(DetailConnecting(deviceId: deviceId, deviceName: deviceName));
        }

      case BleConnectionStatus.connected:
        // ── Step 1: MTU negotiation (best-effort) ─────────────────────────────
        // 512 is the GATT maximum. Android negotiates down to what the peripheral
        // supports (typically 247 = 244 bytes payload after 3 bytes ATT header).
        await _requestMtu(deviceId, 512);

        // ── Step 1.5: Save to history ────────────────────────────────────────
        await _saveDeviceToHistory(id: deviceId, name: deviceName);

        // ── Step 2: GATT service discovery ───────────────────────────────────
        emit(DetailConnecting(
          deviceId: deviceId,
          deviceName: deviceName,
          isDiscovering: true,
        ));

        final result = await _discoverServices(
          deviceId,
          timeout: const Duration(seconds: 5),
        );

        result.fold(
          (failure) => emit(DetailError(
            message: failure.message,
            deviceId: deviceId,
            deviceName: deviceName,
          )),
          (services) {
            _reconnectAttempt = 0; // Successful — reset retry counter.
            emit(DetailConnected(
              deviceId: deviceId,
              deviceName: deviceName,
              services: services,
            ));
          },
        );

      case BleConnectionStatus.disconnecting:
        if (!_userInitiatedDisconnect) {
          emit(DetailDisconnecting(deviceId: deviceId, deviceName: deviceName));
        }

      case BleConnectionStatus.disconnected:
        await _cancelAllCharSubscriptions();
        if (_userInitiatedDisconnect) {
          emit(const DetailDisconnected());
        } else {
          _handleUnexpectedDisconnect(emit, deviceId, deviceName);
        }

      case BleConnectionStatus.error:
        await _cancelAllCharSubscriptions();
        if (_userInitiatedDisconnect) {
          emit(const DetailDisconnected());
        } else {
          _handleUnexpectedDisconnect(emit, deviceId, deviceName);
        }

      // These states are managed by our own discovery flow above.
      case BleConnectionStatus.discovering:
      case BleConnectionStatus.ready:
        break;
    }
  }

  void _onValueReceived(
    ValueReceivedEvent event,
    Emitter<DeviceDetailState> emit,
  ) {
    if (state is! DetailConnected) return;
    final current = state as DetailConnected;
    if (current.activeCharacteristic == null) return;

    // Maintain sliding window of last 20 values for sparkline.
    final newHistory = [...current.history, event.value];
    if (newHistory.length > 20) newHistory.removeAt(0);

    emit(current.copyWith(latestValue: event.value, history: newHistory));
  }

  void _onSubscriptionError(
    SubscriptionErrorEvent event,
    Emitter<DeviceDetailState> emit,
  ) {
    // Don't crash — surface the error inline so user can try another char.
    if (state is! DetailConnected) return;
    final current = state as DetailConnected;
    emit(current.copyWith(
      isSubscribing: false,
      subscriptionError: event.failure.message,
      clearActiveChar: true,
    ));
  }

  Future<void> _onAttemptAutoReconnect(
    AttemptAutoReconnectEvent event,
    Emitter<DeviceDetailState> emit,
  ) async {
    final deviceId = _deviceId;
    final deviceName = _deviceName;
    if (deviceId == null || deviceName == null) return;

    emit(DetailConnecting(deviceId: deviceId, deviceName: deviceName));
    await _startConnection();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  /// Initiates the BLE connection and wires up the state-change listener.
  Future<void> _startConnection() async {
    final deviceId = _deviceId;
    if (deviceId == null) return;

    await _connectionSub?.cancel();

    _connectionSub = _connectToDevice(deviceId).listen(
      (status) {
        if (!isClosed) add(ConnectionStateChangedEvent(status));
      },
      onError: (Object error) {
        if (isClosed) return;
        final errStr = error.toString();
        final isGatt133 = errStr.contains('133') ||
            errStr.toLowerCase().contains('gatt_error');

        if (isGatt133) {
          // ── GATT 133 handling ───────────────────────────────────────────────
          // Android BLE bug: the GATT cache from a previous connection is stale.
          // Fix: disconnect immediately, wait 600 ms, reconnect.
          // This shorter delay is intentional — don't use the normal backoff.
          debugPrint('[DetailBloc] GATT 133 detected — will retry in 600 ms');
          _reconnectTimer?.cancel();
          _reconnectTimer = Timer(const Duration(milliseconds: 600), () {
            if (!isClosed) add(const AttemptAutoReconnectEvent());
          });
        } else {
          add(const ConnectionStateChangedEvent(BleConnectionStatus.error));
        }
      },
    );
  }

  /// Handles unexpected disconnects with exponential backoff reconnect logic.
  ///
  /// Called from within an event handler so [emit] is available.
  void _handleUnexpectedDisconnect(
    Emitter<DeviceDetailState> emit,
    String deviceId,
    String deviceName,
  ) {
    if (_reconnectAttempt >= maxReconnects) {
      emit(DetailConnectionLost(
        deviceId: deviceId,
        deviceName: deviceName,
        reconnectAttempt: _reconnectAttempt,
        maxReached: true,
      ));
      return;
    }

    final delay = _backoffDelays[_reconnectAttempt];
    _reconnectAttempt++;

    // Emit "trying to reconnect" state immediately.
    emit(DetailConnectionLost(
      deviceId: deviceId,
      deviceName: deviceName,
      reconnectAttempt: _reconnectAttempt,
      maxReached: false,
    ));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (!isClosed) add(const AttemptAutoReconnectEvent());
    });
  }

  Future<void> _cancelAllCharSubscriptions() async {
    for (final sub in _charSubs.values) {
      await sub.cancel();
    }
    _charSubs.clear();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Future<void> close() async {
    _reconnectTimer?.cancel();
    await _connectionSub?.cancel();
    await _cancelAllCharSubscriptions();
    return super.close();
  }
}
