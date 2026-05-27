import 'package:equatable/equatable.dart';

import '../../../ble/domain/entities/ble_device.dart';

sealed class ScannerState extends Equatable {
  const ScannerState();
}

class ScannerInitial extends ScannerState {
  const ScannerInitial();
  @override
  List<Object?> get props => [];
}

class ScannerPermissionRequired extends ScannerState {
  const ScannerPermissionRequired();
  @override
  List<Object?> get props => [];
}

class ScannerScanning extends ScannerState {
  const ScannerScanning({required this.devices, this.isFirstScan = false});
  final List<BleDevice> devices;
  final bool isFirstScan;
  @override
  List<Object?> get props => [devices, isFirstScan];
}

class ScannerStopped extends ScannerState {
  const ScannerStopped({this.devices = const []});
  final List<BleDevice> devices;
  @override
  List<Object?> get props => [devices];
}

class ScannerError extends ScannerState {
  const ScannerError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
