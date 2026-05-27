import '../repositories/i_history_repository.dart';

class SaveDeviceToHistoryUseCase {
  final IHistoryRepository _repository;

  SaveDeviceToHistoryUseCase(this._repository);

  Future<void> call({required String id, required String name}) {
    return _repository.saveConnectedDevice(id: id, name: name);
  }
}
