import 'dart:convert';
import 'api_client.dart';

class PredictService {
  // ==============================
  // 🧠 PREDICT EMOTION
  // ==============================
  static Future<Map<String, dynamic>> predictEmotion(String text) async {
    try {
      final response = await ApiClient.post(
        "/predict",
        {"text": text},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 401) {
        throw Exception("Session expired. Please login again.");
      }

      throw Exception("Prediction failed (${response.statusCode})");
    } catch (e) {
      throw Exception("Prediction error: $e");
    }
  }

  // ==============================
  // 📜 FETCH HISTORY
  // ==============================
  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    try {
      final response = await ApiClient.get("/history");

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        return decoded.whereType<Map<String, dynamic>>().toList();
      }

      if (response.statusCode == 401) {
        throw Exception("Session expired. Please login again.");
      }

      throw Exception("Failed to load history (${response.statusCode})");
    } catch (e) {
      throw Exception("History fetch error: $e");
    }
  }

  // ==============================
  // 🧠 AI SEMANTIC SEARCH ✅ FIXED
  // ==============================
  static Future<List<Map<String, dynamic>>> semanticSearch(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await ApiClient.post(
        "/semantic-search",
        {"query": query},
      );

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);

        return decoded.whereType<Map<String, dynamic>>().toList();
      }

      if (response.statusCode == 401) {
        throw Exception("Session expired. Please login again.");
      }

      throw Exception("Semantic search failed (${response.statusCode})");
    } catch (e) {
      throw Exception("Semantic search error: $e");
    }
  }

  // ==============================
  // 👤 FETCH PROFILE
  // ==============================
  static Future<Map<String, dynamic>> fetchProfile() async {
    try {
      final response = await ApiClient.get("/profile");

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 401) {
        throw Exception("Session expired. Please login again.");
      }

      throw Exception("Failed to load profile");
    } catch (e) {
      throw Exception("Profile fetch error: $e");
    }
  }

  // ==============================
  // ✏️ UPDATE PROFILE
  // ==============================
  static Future<void> updateProfile({
    required String email,
    String? password,
  }) async {
    try {
      final body = <String, dynamic>{
        "email": email,
      };

      if (password != null && password.isNotEmpty) {
        body["password"] = password;
      }

      final response = await ApiClient.put(
        "/profile",
        body,
      );

      if (response.statusCode != 200) {
        throw Exception("Profile update failed");
      }
    } catch (e) {
      throw Exception("Profile update error: $e");
    }
  }
}


