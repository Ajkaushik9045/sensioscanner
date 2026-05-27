import 'package:equatable/equatable.dart';

/// A single value emission from a subscribed GATT characteristic.
///
/// Carries raw bytes plus convenience decoders for common BLE value formats.
class CharacteristicValue extends Equatable {
  const CharacteristicValue({
    required this.characteristicUuid,
    required this.serviceUuid,
    required this.deviceId,
    required this.value,
    required this.timestamp,
  });

  /// UUID of the characteristic that emitted this value.
  final String characteristicUuid;

  /// UUID of the parent service.
  final String serviceUuid;

  /// ID of the device this value came from.
  final String deviceId;

  /// Raw byte payload from the BLE notification/indication.
  final List<int> value;

  /// Wall-clock time of reception — set by the data layer on arrival.
  final DateTime timestamp;

  // ── Value decoders ─────────────────────────────────────────────────────────

  /// Hex representation, e.g. `"FF 0A 3C"`. Always safe to call.
  String get hexString => value
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');

  /// Tries to interpret the bytes as a UTF-8 string; falls back to [hexString].
  String get asString {
    try {
      return String.fromCharCodes(value);
    } catch (_) {
      return hexString;
    }
  }

  /// Interprets the first two bytes as a **little-endian** unsigned 16-bit int.
  ///
  /// Returns `null` if there are fewer than 2 bytes.
  int? get asUint16LE {
    if (value.length < 2) return null;
    return (value[0] & 0xFF) | ((value[1] & 0xFF) << 8);
  }

  /// Interprets the first two bytes as a **big-endian** unsigned 16-bit int.
  int? get asUint16BE {
    if (value.length < 2) return null;
    return ((value[0] & 0xFF) << 8) | (value[1] & 0xFF);
  }

  /// First byte as an unsigned 8-bit int. Returns `null` if value is empty.
  int? get asByte => value.isNotEmpty ? value[0] & 0xFF : null;

  /// Interprets all bytes as a big-endian integer (arbitrary length).
  int get asInt {
    return value.fold(0, (acc, byte) => (acc << 8) | (byte & 0xFF));
  }

  /// True if this emission has no payload (empty notification).
  bool get isEmpty => value.isEmpty;

  @override
  List<Object?> get props => [
        characteristicUuid,
        serviceUuid,
        deviceId,
        value,
        timestamp,
      ];

  @override
  String toString() =>
      'CharacteristicValue('
      'char: $characteristicUuid, '
      'value: $hexString, '
      't: $timestamp)';
}
