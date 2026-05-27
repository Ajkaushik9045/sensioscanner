import 'dart:io' show Platform;

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Failure types
// ─────────────────────────────────────────────────────────────────────────────

/// Base class for permission-related failures.
sealed class PermissionFailure {
  const PermissionFailure();
}

/// One or more permissions were denied (user tapped "Deny").
final class PermissionDenied extends PermissionFailure {
  const PermissionDenied(this.permissions);
  final List<Permission> permissions;
}

/// User tapped "Deny & don't ask again" — must open settings.
final class PermissionPermanentlyDenied extends PermissionFailure {
  const PermissionPermanentlyDenied(this.permissions);
  final List<Permission> permissions;
}

/// Bluetooth is not available on this device (emulator or hardware missing).
final class BluetoothUnavailable extends PermissionFailure {
  const BluetoothUnavailable();
}

/// Platform is not Android/iOS (desktop, web) — BLE not supported.
final class UnsupportedPlatform extends PermissionFailure {
  const UnsupportedPlatform();
}

// ─────────────────────────────────────────────────────────────────────────────
// PermissionService
// ─────────────────────────────────────────────────────────────────────────────

/// Handles the complete BLE permission matrix across Android API levels.
///
/// Android Permission Matrix:
/// ┌─────────────────┬────────────────────────────────────────────────────────┐
/// │ API level       │ Required permissions                                   │
/// ├─────────────────┼────────────────────────────────────────────────────────┤
/// │ < 29 (< 10)     │ ACCESS_FINE_LOCATION                                   │
/// │ 29–30 (10, 11)  │ ACCESS_FINE_LOCATION                                   │
/// │ 31+ (12+)       │ BLUETOOTH_SCAN + BLUETOOTH_CONNECT                     │
/// └─────────────────┴────────────────────────────────────────────────────────┘
///
/// Note: On Android 12+ we set `neverForLocation` in the manifest for
/// BLUETOOTH_SCAN so location permission is NOT required there.
/// flutter_reactive_ble still calls `checkPermissions()` internally, so we
/// request all relevant permissions upfront via permission_handler.
abstract interface class PermissionService {
  /// Requests all BLE-related permissions appropriate for the current device.
  ///
  /// Returns [Right(true)] when all required permissions are granted.
  /// Returns [Left(PermissionFailure)] on any denial or error.
  Future<Either<PermissionFailure, bool>> requestBlePermissions();

  /// Checks whether all required BLE permissions are currently granted
  /// without prompting the user.
  Future<Either<PermissionFailure, bool>> checkBlePermissions();

  /// Opens the app settings screen so the user can manually grant permissions
  /// that were permanently denied.
  Future<bool> openSettings();
}

// ─────────────────────────────────────────────────────────────────────────────
// Implementation
// ─────────────────────────────────────────────────────────────────────────────

final class PermissionServiceImpl implements PermissionService {
  const PermissionServiceImpl();

  // ── Public API ─────────────────────────────────────────────────────────────

  @override
  Future<Either<PermissionFailure, bool>> requestBlePermissions() async {
    if (!_isSupportedPlatform) {
      return const Left(UnsupportedPlatform());
    }

    final required = _requiredPermissions();
    debugPrint('[PermissionService] Requesting permissions: $required');

    final results = await required.request();
    return _evaluateResults(results);
  }

  @override
  Future<Either<PermissionFailure, bool>> checkBlePermissions() async {
    if (!_isSupportedPlatform) {
      return const Left(UnsupportedPlatform());
    }

    final required = _requiredPermissions();
    final statuses = await Future.wait(required.map((p) => p.status));
    final Map<Permission, PermissionStatus> results = {
      for (var i = 0; i < required.length; i++) required[i]: statuses[i],
    };

    return _evaluateResults(results);
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  // ── Internals ──────────────────────────────────────────────────────────────

  /// Whether we're on a mobile platform that supports BLE.
  bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Returns the set of permissions appropriate for the current Android API.
  ///
  /// On iOS, [Permission.bluetooth] covers everything needed.
  List<Permission> _requiredPermissions() {
    if (Platform.isIOS) {
      return [Permission.bluetooth];
    }

    // Android branch — we gate on SDK version via permission_handler's
    // built-in awareness (it won't request API 31+ permissions on older SDKs).
    return [
      // Android 12+ (API 31+): granular BLE permissions
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // Android 10/11 (API 29-30): location required for BLE scan
      // On Android 12+ with neverForLocation this still appears in the list
      // but is already granted (system auto-grants it or skips the dialog).
      Permission.locationWhenInUse,
    ];
  }

  /// Interprets permission results and returns the appropriate Either.
  Either<PermissionFailure, bool> _evaluateResults(
    Map<Permission, PermissionStatus> results,
  ) {
    final permanentlyDenied = <Permission>[];
    final denied = <Permission>[];

    for (final entry in results.entries) {
      final status = entry.value;
      if (status.isPermanentlyDenied) {
        permanentlyDenied.add(entry.key);
      } else if (status.isDenied || status.isRestricted) {
        denied.add(entry.key);
      }
    }

    if (permanentlyDenied.isNotEmpty) {
      debugPrint(
        '[PermissionService] Permanently denied: $permanentlyDenied',
      );
      return Left(PermissionPermanentlyDenied(permanentlyDenied));
    }

    if (denied.isNotEmpty) {
      debugPrint('[PermissionService] Denied: $denied');
      return Left(PermissionDenied(denied));
    }

    debugPrint('[PermissionService] All permissions granted ✓');
    return const Right(true);
  }
}
