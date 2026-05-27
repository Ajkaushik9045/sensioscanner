import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../ble/domain/repositories/i_ble_repository.dart';

class RequestMtuUseCase {
  final IBleRepository _repository;

  RequestMtuUseCase(this._repository);

  Future<Either<BleFailure, int>> call(String deviceId, int mtu) {
    return _repository.requestMtu(deviceId, mtu);
  }
}
