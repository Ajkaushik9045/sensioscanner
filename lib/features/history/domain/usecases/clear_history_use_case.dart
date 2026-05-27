import '../repositories/i_history_repository.dart';

class ClearHistoryUseCase {
  final IHistoryRepository _repository;

  ClearHistoryUseCase(this._repository);

  Future<void> call() {
    return _repository.clearHistory();
  }
}
