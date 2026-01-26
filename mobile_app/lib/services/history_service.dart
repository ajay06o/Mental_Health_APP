import 'dart:convert';
import 'api_client.dart';

class HistoryService {
  // ==============================
  // FETCH HISTORY FROM BACKEND
  // ==============================
  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    try {
      final response = await ApiClient.get("/history");

      if (response.statusCode != 200) {
        throw Exception(
          "Failed to load history: ${response.statusCode}",
        );
      }

      final List<dynamic> data = jsonDecode(response.body);

      return data.map<Map<String, dynamic>>((item) {
        return {
          "text": item["text"],
          "emotion": item["emotion"],
          "confidence": item["confidence"],
          "severity": item["severity"],
          "timestamp": item["timestamp"],
        };
      }).toList();
    } catch (e) {
      throw Exception("History fetch error: $e");
    }
  }

  // ==============================
  // OPTIONAL: CLEAR HISTORY (LOCAL ONLY)
  // Backend delete not implemented
  // ==============================
  static Future<void> clearLocalHistory() async {
    // Placeholder for future backend delete API
    return;
  }
}

