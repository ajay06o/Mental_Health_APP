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
        "severity": 1,
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

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        return {
          "emotion": decoded["emotion"] ?? "neutral",
          "confidence": (decoded["confidence"] is num)
              ? (decoded["confidence"] as num).toDouble()
              : 0.5,
          "severity": decoded["severity"] ?? 1,
          "timestamp":
              decoded["timestamp"] ?? DateTime.now().toIso8601String(),
        };
      }

      if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception("Session expired. Please login again.");
      }

      return _safePredictFallback();
    } catch (_) {
      return _safePredictFallback();
    }
  }

  static Map<String, dynamic> _safePredictFallback() {
    return {
      "emotion": "neutral",
      "confidence": 0.3,
      "severity": 1,
      "timestamp": DateTime.now().toIso8601String(),
    };
  }

  // ==============================
  // 📜 FETCH HISTORY
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
  // 🔎 SEMANTIC SEARCH (OPTIONAL)
  // ==============================
  static Future<List<Map<String, dynamic>>> semanticSearch(
      String query) async {
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
      return [];
    }
  }

  // ==============================
  // 👤 FETCH PROFILE
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
  // ✏️ UPDATE PROFILE (FULL SUPPORT)
  // ==============================
  static Future<bool> updateProfile({
    required String email,
    String? password,
    String? emergencyName,
    String? emergencyEmail,
    bool? alertsEnabled,
  }) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        throw Exception("User not authenticated");
      }

      final Map<String, dynamic> body = {
        "email": email,
      };

      if (password != null && password.isNotEmpty) {
        body["password"] = password;
      }

      if (emergencyName != null) {
        body["emergency_name"] = emergencyName;
      }

      if (emergencyEmail != null) {
        body["emergency_email"] = emergencyEmail;
      }

      if (alertsEnabled != null) {
        body["alerts_enabled"] = alertsEnabled;
      }

      final response = await ApiClient.put("/profile", body);

      if (response.statusCode == 200) {
        return true;
      }

      if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception("Session expired. Please login again.");
      }

      throw Exception("Failed to update profile");
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
