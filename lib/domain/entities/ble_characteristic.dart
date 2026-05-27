import 'package:equatable/equatable.dart';

/// GATT characteristic properties as understood by the domain layer.
///
/// Mapped from [DiscoveredCharacteristic]'s boolean flags at the data boundary.
enum CharacteristicProperty {
  /// Characteristic value can be read with a GATT Read request.
  read,

  /// Characteristic value can be written with a GATT Write request (with ACK).
  write,

  /// Characteristic value can be written without a GATT response (fire-and-forget).
  writeWithoutResponse,

  /// Peripheral can push values to the client via GATT notifications.
  notify,

  /// Like [notify] but delivery is acknowledged (slower, more reliable).
  indicate,
}

/// A single GATT characteristic within a [BleService].
///
/// Pure domain object — no flutter_reactive_ble types leak through.
class BleCharacteristic extends Equatable {
  const BleCharacteristic({
    required this.uuid,
    required this.serviceUuid,
    required this.deviceId,
    required this.properties,
    this.descriptors = const [],
  });

  /// The characteristic UUID (e.g. "2A37" for Heart Rate Measurement).
  final String uuid;

  /// The parent service UUID.
  final String serviceUuid;

  /// The device this characteristic belongs to.
  final String deviceId;

  /// Set of supported operations for this characteristic.
  final List<CharacteristicProperty> properties;

  /// Descriptor UUIDs associated with this characteristic.
  ///
  /// Note: flutter_reactive_ble does not expose GATT descriptors directly;
  /// this list will be empty until explicit descriptor discovery is added.
  final List<String> descriptors;

  // ── Convenience property checks ────────────────────────────────────────────

  bool get isReadable => properties.contains(CharacteristicProperty.read);

  bool get isWritable =>
      properties.contains(CharacteristicProperty.write) ||
      properties.contains(CharacteristicProperty.writeWithoutResponse);

  bool get isNotifiable => properties.contains(CharacteristicProperty.notify);

  bool get isIndicatable =>
      properties.contains(CharacteristicProperty.indicate);

  /// Whether this characteristic can be subscribed to (notify OR indicate).
  bool get canSubscribe => isNotifiable || isIndicatable;

  @override
  List<Object?> get props => [uuid, serviceUuid, deviceId, properties, descriptors];

  @override
  String toString() =>
      'BleCharacteristic(uuid: $uuid, properties: $properties)';
}
