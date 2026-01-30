import 'dart:convert';

import 'api_client.dart';
import 'auth_service.dart';

class PredictService {
  // ==============================
  // 🧠 PREDICT EMOTION (SAFE)
  // ==============================
  static Future<Map<String, dynamic>> predictEmotion(String text) async {
    if (text.trim().isEmpty) {
      return {
        "emotion": "neutral",
        "confidence": 0.0,
        "timestamp": DateTime.now().toIso8601String(),
      };
    }

    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        throw Exception("User not authenticated");
      }

      final response = await ApiClient.post(
        "/predict",
        {"text": text},
      );

      // ✅ SUCCESS
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        return {
          "emotion": decoded["emotion"] ?? "neutral",
          "confidence":
              (decoded["confidence"] is num)
                  ? (decoded["confidence"] as num).toDouble()
                  : 0.5,
          "timestamp":
              decoded["timestamp"] ??
              DateTime.now().toIso8601String(),
        };
      }

      // 🔐 SESSION EXPIRED
      if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception("Session expired. Please login again.");
      }

      // ⚠️ ANY OTHER ERROR → SAFE FALLBACK
      return {
        "emotion": "neutral",
        "confidence": 0.3,
        "timestamp": DateTime.now().toIso8601String(),
      };
    } catch (_) {
      // 🔥 NEVER CRASH UI
      return {
        "emotion": "neutral",
        "confidence": 0.3,
        "timestamp": DateTime.now().toIso8601String(),
      };
    }
  }

  // ==============================
  // 📜 FETCH HISTORY (SAFE)
  // ==============================
  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        throw Exception("User not authenticated");
      }

      final response = await ApiClient.get("/history");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      }

      if (response.statusCode == 401) {
        await AuthService.logout();
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  // ==============================
  // 🧠 AI SEMANTIC SEARCH (OPTIONAL)
  // ==============================
  static Future<List<Map<String, dynamic>>> semanticSearch(
    String query,
  ) async {
    if (query.trim().isEmpty) return [];

    try {
      final token = await AuthService.getAccessToken();
      if (token == null) return [];

      final response = await ApiClient.post(
        "/semantic-search",
        {"query": query},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (_) {
      // 🔥 Do not crash UI
      return [];
    }
  }

  // ==============================
  // 👤 FETCH PROFILE (SAFE)
  // ==============================
  static Future<Map<String, dynamic>> fetchProfile() async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        throw Exception("User not authenticated");
      }

      final response = await ApiClient.get("/profile");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }

      if (response.statusCode == 401) {
        await AuthService.logout();
      }

      return {};
    } catch (_) {
      return {};
    }
  }

  // ==============================
  // ✏️ UPDATE PROFILE (SAFE)
  // ==============================
  static Future<bool> updateProfile({
    required String email,
    String? password,
  }) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        throw Exception("User not authenticated");
      }

      final body = <String, dynamic>{
        "email": email,
      };

      if (password != null && password.isNotEmpty) {
        body["password"] = password;
      }

      final response = await ApiClient.put("/profile", body);

      if (response.statusCode == 200) {
        return true;
      }

      if (response.statusCode == 401) {
        await AuthService.logout();
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}
