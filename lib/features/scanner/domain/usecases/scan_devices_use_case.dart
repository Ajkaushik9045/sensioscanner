import 'package:dartz/dartz.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../../../../core/error/failures.dart';
import '../../../ble/domain/entities/ble_device.dart';
import '../../../ble/domain/repositories/i_ble_repository.dart';

class ScanDevicesUseCase {
  final IBleRepository _repository;

  ScanDevicesUseCase(this._repository);

  Stream<Either<BleFailure, List<BleDevice>>> call({List<Uuid> withServices = const []}) {
    return _repository.scanDevices(withServices: withServices);
  }
}
