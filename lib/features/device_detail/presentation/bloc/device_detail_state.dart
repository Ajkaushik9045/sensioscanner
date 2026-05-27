import 'package:equatable/equatable.dart';

import '../../../ble/domain/entities/ble_characteristic.dart';
import '../../../ble/domain/entities/ble_connection_status.dart';
import '../../../ble/domain/entities/ble_service.dart';
import '../../../ble/domain/entities/characteristic_value.dart' as domain;

// ─────────────────────────────────────────────────────────────────────────────
// State machine:
//
//  DetailInitial
//    └─ ConnectToDeviceEvent ──► DetailConnecting
//         └─ transport up ──────► DetailConnected (isDiscovering: true)
//              └─ GATT done ─────► DetailConnected (services loaded)
//                   ├─ SubscribeToCharacteristic ─► DetailConnected (streaming)
//                   └─ link loss ──────────────────► DetailConnectionLost
//                        ├─ reconnect (auto) ────────► DetailConnecting
//                        └─ max retries ─────────────► DetailConnectionLost(maxReached)
//                             └─ ManualReconnect ─────► DetailConnecting
//  DetailConnected ──► DisconnectDeviceEvent ──► DetailDisconnecting ──► DetailDisconnected
// ─────────────────────────────────────────────────────────────────────────────

sealed class DeviceDetailState extends Equatable {
  const DeviceDetailState();
}

/// Before [ConnectToDeviceEvent] is dispatched.
class DetailInitial extends DeviceDetailState {
  const DetailInitial();
  @override
  List<Object?> get props => [];
}

/// Transport connection in progress (or GATT discovery in progress when
/// [isDiscovering] is true).
class DetailConnecting extends DeviceDetailState {
  const DetailConnecting({
    required this.deviceId,
    required this.deviceName,
    this.isDiscovering = false,
  });
  final String deviceId;
  final String deviceName;

  /// True while GATT service discovery is running (post transport connect).
  final bool isDiscovering;

  String get statusLabel =>
      isDiscovering ? 'Discovering services…' : 'Connecting…';

  @override
  List<Object?> get props => [deviceId, deviceName, isDiscovering];
}

/// Transport + GATT discovery complete. May be streaming a characteristic.
///
/// This single state covers both "services loaded, idle" and "actively streaming"
/// to avoid duplicating all the device/services fields in two state classes.
class DetailConnected extends DeviceDetailState {
  const DetailConnected({
    required this.deviceId,
    required this.deviceName,
    required this.services,
    this.connectionStatus = BleConnectionStatus.ready,
    this.activeCharacteristic,
    this.latestValue,
    this.history = const [],
    this.isSubscribing = false,
    this.subscriptionError,
  });

  final String deviceId;
  final String deviceName;
  final List<BleService> services;
  final BleConnectionStatus connectionStatus;

  // ── Streaming fields (null when no characteristic is active) ───────────────
  final BleCharacteristic? activeCharacteristic;
  final domain.CharacteristicValue? latestValue;

  /// Sliding window of the last 20 values — used to drive the sparkline.
  final List<domain.CharacteristicValue> history;

  /// True while the subscribe call is in flight (shows loading indicator).
  final bool isSubscribing;

  /// Set when the subscription fails so the UI can show an inline error.
  final String? subscriptionError;

  bool get isStreaming => activeCharacteristic != null && !isSubscribing;

  DetailConnected copyWith({
    BleConnectionStatus? connectionStatus,
    BleCharacteristic? activeCharacteristic,
    domain.CharacteristicValue? latestValue,
    List<domain.CharacteristicValue>? history,
    bool? isSubscribing,
    String? subscriptionError,
    bool clearActiveChar = false,
    bool clearSubscriptionError = false,
  }) {
    return DetailConnected(
      deviceId: deviceId,
      deviceName: deviceName,
      services: services,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      activeCharacteristic:
          clearActiveChar ? null : (activeCharacteristic ?? this.activeCharacteristic),
      latestValue: clearActiveChar ? null : (latestValue ?? this.latestValue),
      history: clearActiveChar ? const [] : (history ?? this.history),
      isSubscribing: isSubscribing ?? this.isSubscribing,
      subscriptionError: clearSubscriptionError
          ? null
          : (subscriptionError ?? this.subscriptionError),
    );
  }

  @override
  List<Object?> get props => [
        deviceId,
        deviceName,
        services,
        connectionStatus,
        activeCharacteristic,
        latestValue,
        history,
        isSubscribing,
        subscriptionError,
      ];
}

/// Unexpected connection loss; auto-reconnect in progress or exhausted.
class DetailConnectionLost extends DeviceDetailState {
  const DetailConnectionLost({
    required this.deviceId,
    required this.deviceName,
    required this.reconnectAttempt,
    required this.maxReached,
  });

  final String deviceId;
  final String deviceName;

  /// Which attempt we just failed (1-based).
  final int reconnectAttempt;

  /// True when all [DeviceDetailBloc.maxReconnects] attempts are exhausted.
  final bool maxReached;

  String get statusMessage => maxReached
      ? 'Connection lost — could not reconnect after $reconnectAttempt attempts.'
      : 'Connection lost — reconnecting (attempt $reconnectAttempt)…';

  @override
  List<Object?> get props =>
      [deviceId, deviceName, reconnectAttempt, maxReached];
}

/// Clean disconnect requested by the user; waiting for GATT close.
class DetailDisconnecting extends DeviceDetailState {
  const DetailDisconnecting({
    required this.deviceId,
    required this.deviceName,
  });
  final String deviceId;
  final String deviceName;
  @override
  List<Object?> get props => [deviceId, deviceName];
}

/// Device is fully disconnected; safe to navigate away.
class DetailDisconnected extends DeviceDetailState {
  const DetailDisconnected();
  @override
  List<Object?> get props => [];
}

/// An unrecoverable error occurred (e.g. GATT discovery failed on all retries).
class DetailError extends DeviceDetailState {
  const DetailError({
    required this.message,
    this.deviceId,
    this.deviceName,
  });
  final String message;
  final String? deviceId;
  final String? deviceName;
  @override
  List<Object?> get props => [message, deviceId, deviceName];
}
