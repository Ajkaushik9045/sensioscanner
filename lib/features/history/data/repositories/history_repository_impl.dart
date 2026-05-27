import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/history_item.dart';
import '../../domain/repositories/i_history_repository.dart';

/// Implementation of [IHistoryRepository] using [SharedPreferences] for storage.
class HistoryRepositoryImpl implements IHistoryRepository {
  HistoryRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;
  static const _historyKey = 'ble_connection_history';

  @override
  Future<void> saveConnectedDevice({required String id, required String name}) async {
    final history = await getHistory();
    
    // Remove existing entry for this device if it exists to update timestamp and move to top
    history.removeWhere((item) => item.id == id);
    
    final newItem = HistoryItem(
      id: id,
      name: name,
      timestamp: DateTime.now(),
    );
    
    // Insert at the beginning (most recent first)
    history.insert(0, newItem);
    
    final jsonList = history.map((e) => e.toJson()).toList();
    await _prefs.setStringList(_historyKey, jsonList);
  }

  @override
  Future<List<HistoryItem>> getHistory() async {
    final jsonList = _prefs.getStringList(_historyKey) ?? [];
    return jsonList.map((json) {
      try {
        return HistoryItem.fromJson(json);
      } catch (e) {
        return null;
      }
    }).whereType<HistoryItem>().toList();
  }

  @override
  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
  }
}
