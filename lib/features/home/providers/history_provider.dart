import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';
import '../models/history_item.dart';

class HistoryNotifier extends StateNotifier<List<HistoryItem>> {
  HistoryNotifier() : super([]) {
    _loadHistory();
  }

  static const String _boxName = 'transfer_history';

  Future<void> _loadHistory() async {
    final box = await Hive.openBox(_boxName);
    final List<HistoryItem> items = box.values.map((e) {
      return HistoryItem.fromJson(Map<String, dynamic>.from(e));
    }).toList();
    
    // Sort by timestamp descending
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = items;
  }

  Future<void> addHistoryItem(HistoryItem item) async {
    final box = await Hive.openBox(_boxName);
    await box.add(item.toJson());
    
    final newState = [item, ...state];
    // Keep only last 20 items for recent list
    if (newState.length > 20) {
      newState.removeLast();
    }
    state = newState;
  }

  Future<void> clearHistory() async {
    final box = await Hive.openBox(_boxName);
    await box.clear();
    state = [];
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, List<HistoryItem>>((ref) {
  return HistoryNotifier();
});
