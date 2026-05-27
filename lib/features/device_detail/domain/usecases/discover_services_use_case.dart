import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../ble/domain/entities/ble_service.dart';
import '../../../ble/domain/repositories/i_ble_repository.dart';

class DiscoverServicesUseCase {
  final IBleRepository _repository;

  DiscoverServicesUseCase(this._repository);

  Future<Either<BleFailure, List<BleService>>> call(
    String deviceId, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _repository.discoverServices(deviceId, timeout: timeout);
  }
}
