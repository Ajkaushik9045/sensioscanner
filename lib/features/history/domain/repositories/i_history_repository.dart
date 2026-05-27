import '../entities/history_item.dart';

/// Contract for local connection history operations.
abstract interface class IHistoryRepository {
  Future<void> saveConnectedDevice({required String id, required String name});
  Future<List<HistoryItem>> getHistory();
  Future<void> clearHistory();
}
