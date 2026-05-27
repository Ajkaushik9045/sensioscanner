import 'package:dartz/dartz.dart' hide Unit;
import 'package:dartz/dartz.dart' as dartz show Unit;
import '../../../../core/error/failures.dart';
import '../../../ble/domain/repositories/i_ble_repository.dart';

class DisconnectDeviceUseCase {
  final IBleRepository _repository;

  DisconnectDeviceUseCase(this._repository);

  Future<Either<BleFailure, dartz.Unit>> call(String deviceId) async {
    return _repository.disconnect(deviceId);
  }
}
