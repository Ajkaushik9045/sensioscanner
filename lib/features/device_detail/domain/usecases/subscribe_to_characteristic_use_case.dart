import 'package:dartz/dartz.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' hide CharacteristicValue;
import '../../../../core/error/failures.dart';
import '../../../ble/domain/entities/characteristic_value.dart' as domain;
import '../../../ble/domain/repositories/i_ble_repository.dart';

class SubscribeToCharacteristicUseCase {
  final IBleRepository _repository;

  SubscribeToCharacteristicUseCase(this._repository);

  Stream<Either<BleFailure, domain.CharacteristicValue>> call(
    QualifiedCharacteristic characteristic,
  ) {
    return _repository.subscribeToCharacteristic(characteristic);
  }
}
