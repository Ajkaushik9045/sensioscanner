import '../entities/history_item.dart';
import '../repositories/i_history_repository.dart';

class GetHistoryUseCase {
  final IHistoryRepository _repository;

  GetHistoryUseCase(this._repository);

  Future<List<HistoryItem>> call() {
    return _repository.getHistory();
  }
}
