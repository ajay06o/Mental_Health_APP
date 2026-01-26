class HistoryService {
  static final List<Map<String, dynamic>> _history = [];

  // ==============================
  // ADD HISTORY
  // ==============================
  static Future<void> addHistory(
    String emotion,
    DateTime timestamp,
  ) async {
    _history.add({
      "emotion": emotion,
      "timestamp": timestamp.toIso8601String(),
    });
  }

  // ==============================
  // FETCH HISTORY
  // ==============================
  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List<Map<String, dynamic>>.from(_history);
  }

  // ==============================
  // CLEAR HISTORY (OPTIONAL)
  // ==============================
  static Future<void> clearHistory() async {
    _history.clear();
  }
}
