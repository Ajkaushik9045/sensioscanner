import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart' hide Unit;
import 'package:flutter/foundation.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/permission_service.dart';
import '../../../ble/domain/entities/ble_device.dart';
import '../../domain/usecases/scan_devices_use_case.dart';
import '../../domain/usecases/stop_scan_use_case.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  ScannerBloc({
    required ScanDevicesUseCase scanDevicesUseCase,
    required StopScanUseCase stopScanUseCase,
    required PermissionService permissionService,
  })  : _scanDevices = scanDevicesUseCase,
        _stopScan = stopScanUseCase,
        _permissions = permissionService,
        super(const ScannerInitial()) {
    on<RequestPermissionsAndScanEvent>(_onRequestPermissionsAndScan);
    on<StopScanEvent>(_onStop);
    on<DeviceListUpdatedEvent>(_onDeviceListUpdated);
    on<ScanErrorEvent>(_onScanError);
  }

  final ScanDevicesUseCase _scanDevices;
  final StopScanUseCase _stopScan;
  final PermissionService _permissions;
  StreamSubscription<Either<BleFailure, List<BleDevice>>>? _scanSub;

  Future<void> _onRequestPermissionsAndScan(
    RequestPermissionsAndScanEvent event,
    Emitter<ScannerState> emit,
  ) async {
    // ── Check / request permissions ───────────────────────────────────────────
    final permResult = await _permissions.requestBlePermissions();
    final granted = permResult.fold((_) => false, (ok) => ok);
    if (!granted) {
      emit(const ScannerPermissionRequired());
      return;
    }

    // ── Start scan ────────────────────────────────────────────────────────────
    emit(const ScannerScanning(devices: [], isFirstScan: true));
    await _scanSub?.cancel();

    _scanSub = _scanDevices().listen((either) {
      if (isClosed) return;
      either.fold(
        (failure) => add(ScanErrorEvent(failure.message)),
        (devices) => add(DeviceListUpdatedEvent(devices)),
      );
    });
  }

  Future<void> _onStop(
    StopScanEvent event,
    Emitter<ScannerState> emit,
  ) async {
    await _scanSub?.cancel();
    _scanSub = null;
    await _stopScan();

    final devices = state is ScannerScanning
        ? (state as ScannerScanning).devices
        : const <BleDevice>[];
    emit(ScannerStopped(devices: devices));
  }

  void _onDeviceListUpdated(
    DeviceListUpdatedEvent event,
    Emitter<ScannerState> emit,
  ) {
    final devices = event.devices.cast<BleDevice>();
    final isFirst = state is ScannerScanning &&
        (state as ScannerScanning).isFirstScan &&
        devices.isEmpty;
    emit(ScannerScanning(devices: devices, isFirstScan: isFirst));
  }

  void _onScanError(
    ScanErrorEvent event,
    Emitter<ScannerState> emit,
  ) {
    debugPrint('[ScannerBloc] Scan error: ${event.message}');
    emit(ScannerError(event.message));
  }

  @override
  Future<void> close() async {
    await _scanSub?.cancel();
    await _stopScan();
    return super.close();
  }
}
