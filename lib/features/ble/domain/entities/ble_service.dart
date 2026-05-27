import 'package:equatable/equatable.dart';

import 'ble_characteristic.dart';

/// A GATT service discovered on a connected peripheral.
///
/// Contains all characteristics belonging to this service.
class BleService extends Equatable {
  const BleService({
    required this.uuid,
    required this.deviceId,
    required this.characteristics,
  });

  /// The service UUID (e.g. "180D" for Heart Rate Service).
  final String uuid;

  /// The device this service belongs to.
  final String deviceId;

  /// All characteristics discovered under this service.
  final List<BleCharacteristic> characteristics;

  // ── Filtered views ─────────────────────────────────────────────────────────

  /// Characteristics that support notifications or indications — the primary
  /// candidates for live-streaming in Phase 2.
  List<BleCharacteristic> get subscribableCharacteristics =>
      characteristics.where((c) => c.canSubscribe).toList();

  /// Characteristics that can be read on demand.
  List<BleCharacteristic> get readableCharacteristics =>
      characteristics.where((c) => c.isReadable).toList();

  /// Characteristics that can be written.
  List<BleCharacteristic> get writableCharacteristics =>
      characteristics.where((c) => c.isWritable).toList();

  @override
  List<Object?> get props => [uuid, deviceId, characteristics];

  @override
  String toString() =>
      'BleService(uuid: $uuid, characteristics: ${characteristics.length})';
}
