import 'package:equatable/equatable.dart';

sealed class ScannerEvent extends Equatable {
  const ScannerEvent();
  @override
  List<Object?> get props => [];
}

class RequestPermissionsAndScanEvent extends ScannerEvent {
  const RequestPermissionsAndScanEvent();
}

class StopScanEvent extends ScannerEvent {
  const StopScanEvent();
}

class DeviceListUpdatedEvent extends ScannerEvent {
  const DeviceListUpdatedEvent(this.devices);
  final List<dynamic> devices; // List<BleDevice>
  @override
  List<Object?> get props => [devices];
}

class ScanErrorEvent extends ScannerEvent {
  const ScanErrorEvent(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
