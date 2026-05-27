import 'package:equatable/equatable.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart'
    hide CharacteristicValue, ScanFailure, Unit;

import '../../../../core/error/failures.dart';
import '../../../ble/domain/entities/ble_characteristic.dart';
import '../../../ble/domain/entities/ble_connection_status.dart';
import '../../../ble/domain/entities/characteristic_value.dart' as domain;

sealed class DeviceDetailEvent extends Equatable {
  const DeviceDetailEvent();
  @override
  List<Object?> get props => [];
}

// ── Public events (external callers) ──────────────────────────────────────────

/// Begin connecting to a BLE device.
class ConnectToDeviceEvent extends DeviceDetailEvent {
  const ConnectToDeviceEvent({
    required this.deviceId,
    required this.deviceName,
  });
  final String deviceId;
  final String deviceName;
  @override
  List<Object?> get props => [deviceId, deviceName];
}

/// User-initiated clean disconnect.
class DisconnectDeviceEvent extends DeviceDetailEvent {
  const DisconnectDeviceEvent();
}

/// Subscribe to a characteristic's notifications/indications.
class SubscribeToCharacteristicEvent extends DeviceDetailEvent {
  const SubscribeToCharacteristicEvent({
    required this.qualifiedCharacteristic,
    required this.bleCharacteristic,
  });
  final QualifiedCharacteristic qualifiedCharacteristic;
  final BleCharacteristic bleCharacteristic;
  @override
  List<Object?> get props => [qualifiedCharacteristic, bleCharacteristic];
}

/// Stop the active characteristic subscription.
class UnsubscribeFromCharacteristicEvent extends DeviceDetailEvent {
  const UnsubscribeFromCharacteristicEvent();
}

/// User taps "Reconnect" after max attempts are exhausted.
class ManualReconnectEvent extends DeviceDetailEvent {
  const ManualReconnectEvent();
}

// ── Internal events (BLoC → BLoC via add()) ───────────────────────────────────

class ConnectionStateChangedEvent extends DeviceDetailEvent {
  const ConnectionStateChangedEvent(this.status);
  final BleConnectionStatus status;
  @override
  List<Object?> get props => [status];
}

class ServicesDiscoveredEvent extends DeviceDetailEvent {
  const ServicesDiscoveredEvent(this.services);
  final List<dynamic> services; // List<BleService>
  @override
  List<Object?> get props => [services];
}

class DiscoveryFailedEvent extends DeviceDetailEvent {
  const DiscoveryFailedEvent(this.failure);
  final BleFailure failure;
  @override
  List<Object?> get props => [failure];
}

class ValueReceivedEvent extends DeviceDetailEvent {
  const ValueReceivedEvent(this.value);
  final domain.CharacteristicValue value;
  @override
  List<Object?> get props => [value];
}

class SubscriptionErrorEvent extends DeviceDetailEvent {
  const SubscriptionErrorEvent(this.failure);
  final BleFailure failure;
  @override
  List<Object?> get props => [failure];
}

/// Fired by a Timer when the backoff delay expires — triggers a reconnect attempt.
class AttemptAutoReconnectEvent extends DeviceDetailEvent {
  const AttemptAutoReconnectEvent();
}
