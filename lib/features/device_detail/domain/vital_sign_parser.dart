import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../ble/domain/entities/characteristic_value.dart';
import '../../../core/services/ble_uuid_names.dart';

// ── Vital Sign Types ─────────────────────────────────────────────────────────

enum VitalType {
  heartRate,
  spo2,
  temperature,
  battery,
  hrv,
  stress,
  steps,
  skinTemp,
  unknown
}

enum VitalStatus { normal, warning, critical }

// ── Parsed Result ────────────────────────────────────────────────────────────

/// A fully parsed, human-readable vital sign extracted from raw BLE bytes.
class ParsedVitalSign {
  const ParsedVitalSign({
    required this.type,
    required this.value,
    required this.displayValue,
    required this.unit,
    required this.label,
    required this.status,
    required this.statusMessage,
    required this.icon,
    required this.color,
    required this.statusColor,
  });

  final VitalType type;

  /// Numeric value for charting and comparison.
  final double value;

  /// Formatted display string (e.g. `"96.9"`, `"73"`).
  final String displayValue;

  /// Unit label (e.g. `"bpm"`, `"%"`, `"°C"`).
  final String unit;

  /// Human label (e.g. `"Heart Rate"`).
  final String label;

  /// Health classification.
  final VitalStatus status;

  /// Explanation for the status (e.g. `"Normal resting range"`).
  final String statusMessage;

  /// Suggested icon for this vital type.
  final IconData icon;

  /// Brand color for this vital type.
  final Color color;

  /// Semantic colour matching [status].
  final Color statusColor;
}

// ── Parser ───────────────────────────────────────────────────────────────────

/// Attempts to parse a [CharacteristicValue] into a single [ParsedVitalSign].
///
/// Kept for backwards compatibility with single value views. For characteristics
/// that contain multiple values (e.g. HRV & Stress), this returns the first vital.
ParsedVitalSign? parseVitalSign(CharacteristicValue cv) {
  final list = parseVitalSigns(cv);
  return list.isNotEmpty ? list.first : null;
}

/// Parses a [CharacteristicValue] and yields all decoded [ParsedVitalSign]s.
///
/// Supports standard BLE SIG services and custom/ring properties.
List<ParsedVitalSign> parseVitalSigns(CharacteristicValue cv) {
  final uuid = _normalise(cv.characteristicUuid);
  final serviceUuid = _normalise(cv.serviceUuid);
  final results = <ParsedVitalSign>[];

  // Heart Rate Measurement (0x2A37) or under Heart Rate Service (0x180D)
  if (uuid == _normalise('00002a37-0000-1000-8000-00805f9b34fb') ||
      serviceUuid == _normalise('0000180d-0000-1000-8000-00805f9b34fb')) {
    results.add(_parseHeartRate(cv));
  }

  // Battery Level (0x2A19) or under Battery Service (0x180F)
  else if (uuid == _normalise('00002a19-0000-1000-8000-00805f9b34fb') ||
      serviceUuid == _normalise('0000180f-0000-1000-8000-00805f9b34fb')) {
    results.add(_parseBattery(cv));
  }

  // SensioVital SpO2
  else if (uuid == _normalise(kSensioSpO2CharUuid)) {
    results.add(_parseSpO2(cv));
  }

  // SensioVital Temperature
  else if (uuid == _normalise(kSensioTemperatureCharUuid)) {
    results.add(_parseTemperature(cv));
  }

  // SensioRing HRV & Stress Index
  else if (uuid == _normalise(kSensioRingHrvStressCharUuid)) {
    results.addAll(_parseHrvStress(cv));
  }

  // SensioRing Steps Counter
  else if (uuid == _normalise(kSensioRingStepsCharUuid)) {
    results.add(_parseSteps(cv));
  }

  // SensioRing Skin Temperature
  else if (uuid == _normalise(kSensioRingSkinTempCharUuid)) {
    results.add(_parseSkinTemp(cv));
  }

  // SpO2 PLX (Spot Check)
  else if (uuid == _normalise(kBtSigSpo2PlxCharUuid)) {
    results.add(_parseSpo2Plx(cv));
  }

  return results;
}

// ── Heart Rate ───────────────────────────────────────────────────────────────

ParsedVitalSign _parseHeartRate(CharacteristicValue cv) {
  final bytes = cv.value;
  int bpm = 0;

  if (bytes.length >= 2) {
    final flags = bytes[0];
    final isUint16 = (flags & 0x01) != 0;
    if (isUint16 && bytes.length >= 3) {
      bpm = (bytes[1] & 0xFF) | ((bytes[2] & 0xFF) << 8);
    } else {
      bpm = bytes[1] & 0xFF;
    }
  } else if (bytes.isNotEmpty) {
    bpm = bytes[0] & 0xFF;
  }

  final (status, message) = _classifyHR(bpm);

  return ParsedVitalSign(
    type: VitalType.heartRate,
    value: bpm.toDouble(),
    displayValue: '$bpm',
    unit: 'bpm',
    label: 'Heart Rate',
    status: status,
    statusMessage: message,
    icon: Icons.favorite_rounded,
    color: const Color(0xFFEF5350),
    statusColor: _statusColor(status),
  );
}

(VitalStatus, String) _classifyHR(int bpm) {
  if (bpm < 40) return (VitalStatus.critical, 'Dangerously low');
  if (bpm < 50) return (VitalStatus.warning, 'Below normal');
  if (bpm <= 100) return (VitalStatus.normal, 'Normal resting range');
  if (bpm <= 120) return (VitalStatus.warning, 'Elevated');
  return (VitalStatus.critical, 'Dangerously high');
}

// ── SpO2 ─────────────────────────────────────────────────────────────────────

ParsedVitalSign _parseSpO2(CharacteristicValue cv) {
  final bytes = cv.value;
  double spo2 = 0;

  // Simulator encodes as uint16 LE × 100 (97.5 → 9750)
  if (bytes.length >= 2) {
    final raw = (bytes[0] & 0xFF) | ((bytes[1] & 0xFF) << 8);
    spo2 = raw / 100.0;
  }

  final (status, message) = _classifySpO2(spo2);

  return ParsedVitalSign(
    type: VitalType.spo2,
    value: spo2,
    displayValue: spo2.toStringAsFixed(1),
    unit: '%',
    label: 'SpO₂',
    status: status,
    statusMessage: message,
    icon: Icons.air_rounded,
    color: const Color(0xFF42A5F5),
    statusColor: _statusColor(status),
  );
}

(VitalStatus, String) _classifySpO2(double spo2) {
  if (spo2 < 90) return (VitalStatus.critical, 'Critically low — seek help');
  if (spo2 < 95) return (VitalStatus.warning, 'Below normal');
  return (VitalStatus.normal, 'Healthy oxygen level');
}

// ── Temperature ──────────────────────────────────────────────────────────────

ParsedVitalSign _parseTemperature(CharacteristicValue cv) {
  final bytes = cv.value;
  double temp = 0;

  // Simulator encodes as uint32 LE × 100 (36.60 → 3660)
  if (bytes.length >= 4) {
    final raw = (bytes[0] & 0xFF) |
        ((bytes[1] & 0xFF) << 8) |
        ((bytes[2] & 0xFF) << 16) |
        ((bytes[3] & 0xFF) << 24);
    temp = raw / 100.0;
  } else if (bytes.length >= 2) {
    final raw = (bytes[0] & 0xFF) | ((bytes[1] & 0xFF) << 8);
    temp = raw / 100.0;
  }

  final (status, message) = _classifyTemp(temp);

  return ParsedVitalSign(
    type: VitalType.temperature,
    value: temp,
    displayValue: temp.toStringAsFixed(1),
    unit: '°C',
    label: 'Temperature',
    status: status,
    statusMessage: message,
    icon: Icons.thermostat_rounded,
    color: const Color(0xFFFFA726),
    statusColor: _statusColor(status),
  );
}

(VitalStatus, String) _classifyTemp(double temp) {
  if (temp < 35.0) return (VitalStatus.critical, 'Hypothermia');
  if (temp < 36.0) return (VitalStatus.warning, 'Below normal');
  if (temp <= 37.5) return (VitalStatus.normal, 'Normal body temperature');
  if (temp <= 38.5) return (VitalStatus.warning, 'Mild fever');
  return (VitalStatus.critical, 'High fever');
}

// ── Battery ──────────────────────────────────────────────────────────────────

ParsedVitalSign _parseBattery(CharacteristicValue cv) {
  final bytes = cv.value;
  int level = 0;

  if (bytes.isNotEmpty) {
    level = bytes[0] & 0xFF;
  }

  final (status, message) = _classifyBattery(level);

  return ParsedVitalSign(
    type: VitalType.battery,
    value: level.toDouble(),
    displayValue: '$level',
    unit: '%',
    label: 'Battery',
    status: status,
    statusMessage: message,
    icon: level > 80
        ? Icons.battery_full_rounded
        : level > 30
            ? Icons.battery_5_bar_rounded
            : level > 15
                ? Icons.battery_2_bar_rounded
                : Icons.battery_alert_rounded,
    color: const Color(0xFF66BB6A),
    statusColor: _statusColor(status),
  );
}

(VitalStatus, String) _classifyBattery(int level) {
  if (level <= 10) return (VitalStatus.critical, 'Critically low');
  if (level <= 25) return (VitalStatus.warning, 'Low — charge soon');
  return (VitalStatus.normal, 'Good');
}

// ── SensioRing Custom Parsers ───────────────────────────────────────────────

List<ParsedVitalSign> _parseHrvStress(CharacteristicValue cv) {
  final bytes = cv.value;
  if (bytes.length < 3) return const [];

  final hrvRaw = (bytes[0] & 0xFF) | ((bytes[1] & 0xFF) << 8);
  final hrv = hrvRaw / 10.0;
  final stress = bytes[2] & 0xFF;

  final (hrvStatus, hrvMsg) = _classifyHrv(hrv);
  final (stressStatus, stressMsg) = _classifyStress(stress);

  return [
    ParsedVitalSign(
      type: VitalType.hrv,
      value: hrv,
      displayValue: hrv.toStringAsFixed(1),
      unit: 'ms',
      label: 'HRV',
      status: hrvStatus,
      statusMessage: hrvMsg,
      icon: Icons.insights_rounded,
      color: const Color(0xFFAB47BC), // purple
      statusColor: _statusColor(hrvStatus),
    ),
    ParsedVitalSign(
      type: VitalType.stress,
      value: stress.toDouble(),
      displayValue: '$stress',
      unit: '%',
      label: 'Stress Index',
      status: stressStatus,
      statusMessage: stressMsg,
      icon: Icons.psychology_rounded,
      color: const Color(0xFFFF7043), // orange-red
      statusColor: _statusColor(stressStatus),
    ),
  ];
}

(VitalStatus, String) _classifyHrv(double hrv) {
  if (hrv < 25) return (VitalStatus.critical, 'Very low (Highly stressed)');
  if (hrv < 40) return (VitalStatus.warning, 'Slightly low');
  return (VitalStatus.normal, 'Healthy range (Relaxed)');
}

(VitalStatus, String) _classifyStress(int stress) {
  if (stress < 35) return (VitalStatus.normal, 'Relaxed');
  if (stress < 60) return (VitalStatus.normal, 'Normal');
  if (stress < 80) return (VitalStatus.warning, 'Elevated stress');
  return (VitalStatus.critical, 'High stress');
}

ParsedVitalSign _parseSteps(CharacteristicValue cv) {
  final bytes = cv.value;
  int steps = 0;

  if (bytes.length >= 4) {
    steps = (bytes[0] & 0xFF) |
        ((bytes[1] & 0xFF) << 8) |
        ((bytes[2] & 0xFF) << 16) |
        ((bytes[3] & 0xFF) << 24);
  }

  return ParsedVitalSign(
    type: VitalType.steps,
    value: steps.toDouble(),
    displayValue: '$steps',
    unit: 'steps',
    label: 'Steps',
    status: VitalStatus.normal,
    statusMessage: 'Keep active!',
    icon: Icons.directions_walk_rounded,
    color: const Color(0xFFFFD54F), // yellow
    statusColor: _statusColor(VitalStatus.normal),
  );
}

ParsedVitalSign _parseSkinTemp(CharacteristicValue cv) {
  final bytes = cv.value;
  double temp = 0;

  if (bytes.length >= 4) {
    final raw = (bytes[0] & 0xFF) |
        ((bytes[1] & 0xFF) << 8) |
        ((bytes[2] & 0xFF) << 16) |
        ((bytes[3] & 0xFF) << 24);
    temp = raw / 100.0;
  }

  final (status, message) = _classifySkinTemp(temp);

  return ParsedVitalSign(
    type: VitalType.skinTemp,
    value: temp,
    displayValue: temp.toStringAsFixed(2),
    unit: '°C',
    label: 'Skin Temp',
    status: status,
    statusMessage: message,
    icon: Icons.device_thermostat_rounded,
    color: const Color(0xFF26A69A), // teal
    statusColor: _statusColor(status),
  );
}

(VitalStatus, String) _classifySkinTemp(double temp) {
  if (temp < 30.5) return (VitalStatus.critical, 'Cold skin');
  if (temp < 31.5) return (VitalStatus.warning, 'Cool skin');
  if (temp <= 34.5) return (VitalStatus.normal, 'Normal skin temp');
  if (temp <= 35.5) return (VitalStatus.warning, 'Warm skin');
  return (VitalStatus.critical, 'Hot skin');
}

ParsedVitalSign _parseSpo2Plx(CharacteristicValue cv) {
  final bytes = cv.value;
  double spo2 = 0;

  if (bytes.length >= 3) {
    final rawSFloat = (bytes[1] & 0xFF) | ((bytes[2] & 0xFF) << 8);

    // Decode IEEE 11073 16-bit SFLOAT
    var mantissa = rawSFloat & 0x0FFF;
    if ((mantissa & 0x0800) != 0) {
      mantissa = mantissa - 4096;
    }
    var exponent = (rawSFloat >> 12) & 0x0F;
    if (exponent >= 8) {
      exponent = exponent - 16;
    }

    spo2 = (mantissa * math.pow(10, exponent)).toDouble();
  }

  final (status, message) = _classifySpO2(spo2);

  return ParsedVitalSign(
    type: VitalType.spo2, // maps to SpO2 type
    value: spo2,
    displayValue: spo2.toStringAsFixed(1),
    unit: '%',
    label: 'SpO₂ (PLX)',
    status: status,
    statusMessage: message,
    icon: Icons.air_rounded,
    color: const Color(0xFF29B6F6), // pulse ox blue
    statusColor: _statusColor(status),
  );
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Color _statusColor(VitalStatus status) {
  return switch (status) {
    VitalStatus.normal => const Color(0xFF4CAF50),
    VitalStatus.warning => const Color(0xFFFFA726),
    VitalStatus.critical => const Color(0xFFEF5350),
  };
}

String _normalise(String uuid) {
  var u = uuid.trim().toLowerCase();
  if (u.startsWith('0x')) u = u.substring(2);
  if (!u.contains('-')) {
    if (u.length <= 4) {
      u = u.padLeft(4, '0');
      u = '0000$u-0000-1000-8000-00805f9b34fb';
    } else if (u.length <= 8) {
      u = u.padLeft(8, '0');
      u = '$u-0000-1000-8000-00805f9b34fb';
    }
  }
  return u;
}

/// Returns a placeholder [ParsedVitalSign] with empty/waiting states for a [VitalType].
ParsedVitalSign getPlaceholderVital(VitalType type) {
  return switch (type) {
    VitalType.heartRate => const ParsedVitalSign(
        type: VitalType.heartRate,
        value: 0,
        displayValue: '--',
        unit: 'bpm',
        label: 'Heart Rate',
        status: VitalStatus.normal,
        statusMessage: 'Waiting for data…',
        icon: Icons.favorite_rounded,
        color: Color(0xFFEF5350),
        statusColor: Color(0xFF4CAF50),
      ),
    VitalType.spo2 => const ParsedVitalSign(
        type: VitalType.spo2,
        value: 0,
        displayValue: '--',
        unit: '%',
        label: 'SpO₂',
        status: VitalStatus.normal,
        statusMessage: 'Waiting for data…',
        icon: Icons.air_rounded,
        color: Color(0xFF42A5F5),
        statusColor: Color(0xFF4CAF50),
      ),
    VitalType.temperature => const ParsedVitalSign(
        type: VitalType.temperature,
        value: 0,
        displayValue: '--',
        unit: '°C',
        label: 'Temperature',
        status: VitalStatus.normal,
        statusMessage: 'Waiting for data…',
        icon: Icons.thermostat_rounded,
        color: Color(0xFFFFA726),
        statusColor: Color(0xFF4CAF50),
      ),
    VitalType.battery => const ParsedVitalSign(
        type: VitalType.battery,
        value: 0,
        displayValue: '--',
        unit: '%',
        label: 'Battery',
        status: VitalStatus.normal,
        statusMessage: 'Waiting for data…',
        icon: Icons.battery_unknown_rounded,
        color: Color(0xFF66BB6A),
        statusColor: Color(0xFF4CAF50),
      ),
    VitalType.hrv => const ParsedVitalSign(
        type: VitalType.hrv,
        value: 0,
        displayValue: '--',
        unit: 'ms',
        label: 'HRV',
        status: VitalStatus.normal,
        statusMessage: 'Waiting for HRV…',
        icon: Icons.insights_rounded,
        color: Color(0xFFAB47BC),
        statusColor: Color(0xFF4CAF50),
      ),
    VitalType.stress => const ParsedVitalSign(
        type: VitalType.stress,
        value: 0,
        displayValue: '--',
        unit: '%',
        label: 'Stress Index',
        status: VitalStatus.normal,
        statusMessage: 'Waiting for stress…',
        icon: Icons.psychology_rounded,
        color: Color(0xFFFF7043),
        statusColor: Color(0xFF4CAF50),
      ),
    VitalType.steps => const ParsedVitalSign(
        type: VitalType.steps,
        value: 0,
        displayValue: '--',
        unit: 'steps',
        label: 'Steps',
        status: VitalStatus.normal,
        statusMessage: 'Waiting for steps…',
        icon: Icons.directions_walk_rounded,
        color: Color(0xFFFFD54F),
        statusColor: Color(0xFF4CAF50),
      ),
    VitalType.skinTemp => const ParsedVitalSign(
        type: VitalType.skinTemp,
        value: 0,
        displayValue: '--',
        unit: '°C',
        label: 'Skin Temp',
        status: VitalStatus.normal,
        statusMessage: 'Waiting for temp…',
        icon: Icons.device_thermostat_rounded,
        color: Color(0xFF26A69A),
        statusColor: Color(0xFF4CAF50),
      ),
    VitalType.unknown => const ParsedVitalSign(
        type: VitalType.unknown,
        value: 0,
        displayValue: '--',
        unit: '',
        label: 'Unknown',
        status: VitalStatus.normal,
        statusMessage: 'Waiting for data…',
        icon: Icons.help_outline_rounded,
        color: Colors.grey,
        statusColor: Colors.grey,
      ),
  };
}
