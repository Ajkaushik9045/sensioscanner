import '../../../ble/domain/repositories/i_ble_repository.dart';

class StopScanUseCase {
  final IBleRepository _repository;

  StopScanUseCase(this._repository);

  Future<void> call() async {
    await _repository.stopScan();
  }
}
