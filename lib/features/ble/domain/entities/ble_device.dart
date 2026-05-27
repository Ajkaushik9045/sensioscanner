import 'package:equatable/equatable.dart';

/// A discovered BLE peripheral.
///
/// Immutable value object. RSSI and advertisement data can change between
/// scan results — use [copyWith] to produce updated instances.
class BleDevice extends Equatable {
  const BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.isConnectable,
    this.manufacturerData = const {},
  });

  /// Unique device identifier (platform-assigned MAC on Android,
  /// CBUUID on iOS).
  final String id;

  /// Advertised local name; falls back to 'Unknown Device' if empty.
  final String name;

  /// Received signal strength indicator in dBm. Higher (less negative) = closer.
  final int rssi;

  /// Whether the peripheral is accepting connection requests.
  final bool isConnectable;

  /// Manufacturer-specific advertisement data, keyed by company identifier.
  final Map<int, List<int>> manufacturerData;

  /// Signal quality bucket — useful for displaying bars in the UI.
  SignalStrength get signalStrength {
    if (rssi >= -60) return SignalStrength.excellent;
    if (rssi >= -75) return SignalStrength.good;
    if (rssi >= -85) return SignalStrength.fair;
    return SignalStrength.poor;
  }

  BleDevice copyWith({
    String? id,
    String? name,
    int? rssi,
    bool? isConnectable,
    Map<int, List<int>>? manufacturerData,
  }) {
    return BleDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isConnectable: isConnectable ?? this.isConnectable,
      manufacturerData: manufacturerData ?? this.manufacturerData,
    );
  }

  @override
  List<Object?> get props => [id, name, rssi, isConnectable, manufacturerData];

  @override
  String toString() =>
      'BleDevice(id: $id, name: "$name", rssi: ${rssi}dBm, '
      'connectable: $isConnectable)';
}

/// RSSI quality buckets for UI display (e.g. signal bars).
enum SignalStrength {
  excellent, // ≥ −60 dBm
  good,      // −61 to −75 dBm
  fair,      // −76 to −85 dBm
  poor,      // < −85 dBm
}
