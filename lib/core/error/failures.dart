import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Base
// ─────────────────────────────────────────────────────────────────────────────

/// Base class for all domain failures.
///
/// Use [BleFailure] and its subtypes for BLE-specific errors.
/// Sealed so exhaustive matching is enforced at every call-site.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType(message: $message)';
}

// ─────────────────────────────────────────────────────────────────────────────
// BLE Failures
// ─────────────────────────────────────────────────────────────────────────────

/// Root class for all BLE-related failures.
///
/// Use the concrete subtypes for more granular error handling in the UI.
sealed class BleFailure extends Failure {
  const BleFailure(super.message);
}

/// Failure during BLE device scanning (adapter off, scan rejected, etc.).
final class ScanFailure extends BleFailure {
  const ScanFailure(super.message);
}

/// Failure while connecting to or maintaining a connection with a device.
///
/// Includes connection timeouts, GATT transport errors, and pairing failures.
final class ConnectionFailure extends BleFailure {
  const ConnectionFailure(super.message);
}

/// Failure during GATT service/characteristic discovery.
///
/// Common causes: discovery timeout (slow peripheral stack), device disconnected
/// mid-discovery, or the peripheral rejected the GATT operation.
final class GattFailure extends BleFailure {
  const GattFailure(super.message);
}

/// BLE permission denied or Bluetooth adapter unavailable.
///
/// Distinct from [PermissionDenied] in PermissionService so that the BLE
/// repository layer can surface permission issues without a dependency on
/// permission_handler.
final class BlePermissionFailure extends BleFailure {
  const BlePermissionFailure(super.message);
}

/// Failure during characteristic read, write, or subscribe operations.
///
/// Common causes: characteristic not found, write rejected by peripheral,
/// notification not supported, or device out of range mid-stream.
final class CharacteristicFailure extends BleFailure {
  const CharacteristicFailure(super.message);
}
