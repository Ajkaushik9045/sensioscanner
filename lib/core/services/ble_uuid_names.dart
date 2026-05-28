/// Maps well-known BLE service and characteristic UUIDs to human-readable names.
///
/// Supports both short (4-hex) UUIDs like `180D` and full 128-bit UUIDs.
/// Unknown UUIDs return a formatted fallback string.
library;

// ── SensioVital Custom UUIDs ─────────────────────────────────────────────────
const String kSensioVitalsServiceUuid =
    '12345678-1234-4678-8234-56789abcdef0';
const String kSensioSpO2CharUuid =
    '12345678-1234-4678-8234-56789abcdef1';
const String kSensioTemperatureCharUuid =
    '12345678-1234-4678-8234-56789abcdef2';

// ── Standard BLE SIG base UUID suffix ────────────────────────────────────────
const String _bleSigBaseSuffix = '-0000-1000-8000-00805f9b34fb';

/// Known GATT Service names keyed by normalised UUID.
const Map<String, String> _serviceNames = {
  // BLE SIG standard services
  '00001800$_bleSigBaseSuffix': 'Generic Access',
  '00001801$_bleSigBaseSuffix': 'Generic Attribute',
  '0000180a$_bleSigBaseSuffix': 'Device Information',
  '0000180d$_bleSigBaseSuffix': 'Heart Rate Service',
  '0000180f$_bleSigBaseSuffix': 'Battery Service',
  '00001810$_bleSigBaseSuffix': 'Blood Pressure Service',
  '00001809$_bleSigBaseSuffix': 'Health Thermometer',
  '00001816$_bleSigBaseSuffix': 'Cycling Speed & Cadence',
  '00001818$_bleSigBaseSuffix': 'Cycling Power',
  '00001826$_bleSigBaseSuffix': 'Fitness Machine',
  // SensioVital custom
  kSensioVitalsServiceUuid: 'SensioVital Vitals',
};

/// Known GATT Characteristic names keyed by normalised UUID.
const Map<String, String> _characteristicNames = {
  // Heart Rate
  '00002a37$_bleSigBaseSuffix': 'Heart Rate Measurement',
  '00002a38$_bleSigBaseSuffix': 'Body Sensor Location',
  '00002a39$_bleSigBaseSuffix': 'Heart Rate Control Point',
  // Battery
  '00002a19$_bleSigBaseSuffix': 'Battery Level',
  // Device Information
  '00002a29$_bleSigBaseSuffix': 'Manufacturer Name',
  '00002a24$_bleSigBaseSuffix': 'Model Number',
  '00002a25$_bleSigBaseSuffix': 'Serial Number',
  '00002a27$_bleSigBaseSuffix': 'Hardware Revision',
  '00002a26$_bleSigBaseSuffix': 'Firmware Revision',
  '00002a28$_bleSigBaseSuffix': 'Software Revision',
  // Blood Pressure
  '00002a35$_bleSigBaseSuffix': 'Blood Pressure Measurement',
  '00002a49$_bleSigBaseSuffix': 'Blood Pressure Feature',
  // Health Thermometer
  '00002a1c$_bleSigBaseSuffix': 'Temperature Measurement',
  '00002a1d$_bleSigBaseSuffix': 'Temperature Type',
  // Generic Access
  '00002a00$_bleSigBaseSuffix': 'Device Name',
  '00002a01$_bleSigBaseSuffix': 'Appearance',
  '00002a04$_bleSigBaseSuffix': 'Peripheral Preferred Connection Parameters',
  // GATT
  '00002a05$_bleSigBaseSuffix': 'Service Changed',
  // SensioVital custom
  kSensioSpO2CharUuid: 'SpO₂ (Oxygen Saturation)',
  kSensioTemperatureCharUuid: 'Body Temperature',
};

/// Brief descriptions for known characteristics (for tooltips / subtitles).
const Map<String, String> _characteristicDescriptions = {
  '00002a37$_bleSigBaseSuffix':
      'Heart rate in beats per minute, notified every 1 s',
  '00002a19$_bleSigBaseSuffix':
      'Battery charge level as a percentage (0–100 %)',
  kSensioSpO2CharUuid:
      'Blood oxygen saturation (%), notified every 1 s',
  kSensioTemperatureCharUuid:
      'Core body temperature in °C, notified every 1 s',
};

// ── Public API ───────────────────────────────────────────────────────────────

/// Returns a human-readable name for the given service UUID,
/// or a formatted unknown string.
String getServiceName(String uuid) {
  final key = _normalise(uuid);
  return _serviceNames[key] ?? 'Unknown Service';
}

/// Returns a human-readable name for the given characteristic UUID,
/// or a formatted unknown string.
String getCharacteristicName(String uuid) {
  final key = _normalise(uuid);
  return _characteristicNames[key] ?? 'Unknown Characteristic';
}

/// Returns a brief description for a known characteristic, or `null`.
String? getCharacteristicDescription(String uuid) {
  final key = _normalise(uuid);
  return _characteristicDescriptions[key];
}

/// Returns true if the UUID belongs to a known BLE SIG or SensioVital service.
bool isKnownService(String uuid) {
  return _serviceNames.containsKey(_normalise(uuid));
}

/// Returns true if the UUID belongs to a known characteristic.
bool isKnownCharacteristic(String uuid) {
  return _characteristicNames.containsKey(_normalise(uuid));
}

/// Returns a short display form of a UUID.
/// For standard BLE SIG: `0x180D`
/// For custom 128-bit: first 8 chars `1234-5678…`
String shortUuid(String uuid) {
  final norm = _normalise(uuid);
  if (norm.endsWith(_bleSigBaseSuffix)) {
    final hex = norm.substring(4, 8).toUpperCase();
    return '0x$hex';
  }
  return norm.length > 13
      ? '${norm.substring(0, 13)}…'
      : norm;
}

// ── Internals ────────────────────────────────────────────────────────────────

/// Normalises a UUID to lowercase full 128-bit form.
///
/// Handles:
///   • `180D`        → `0000180d-0000-1000-8000-00805f9b34fb`
///   • `0x2A37`      → `00002a37-0000-1000-8000-00805f9b34fb`
///   • Full 128-bit  → lowercased as-is
String _normalise(String uuid) {
  var u = uuid.trim().toLowerCase();

  // Strip `0x` prefix if present.
  if (u.startsWith('0x')) u = u.substring(2);

  // If short form (4 or 8 hex chars without dashes), expand to full 128-bit.
  if (!u.contains('-')) {
    if (u.length <= 4) {
      u = u.padLeft(4, '0');
      u = '0000$u$_bleSigBaseSuffix';
    } else if (u.length <= 8) {
      u = u.padLeft(8, '0');
      u = '$u$_bleSigBaseSuffix';
    }
  }

  return u;
}
