import 'package:dartz/dartz.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' hide CharacteristicValue;
import '../../../../core/error/failures.dart';
import '../../../ble/domain/entities/characteristic_value.dart' as domain;
import '../../../ble/domain/repositories/i_ble_repository.dart';

/// Performs a one-shot read of a GATT characteristic value.
///
/// Used for READ-only characteristics (e.g. Battery Level) that don't
/// support NOTIFY/INDICATE.
class ReadCharacteristicUseCase {
  final IBleRepository _repository;

  ReadCharacteristicUseCase(this._repository);

  Future<Either<BleFailure, domain.CharacteristicValue>> call(
    QualifiedCharacteristic characteristic,
  ) {
    return _repository.readCharacteristic(characteristic);
  }
}
