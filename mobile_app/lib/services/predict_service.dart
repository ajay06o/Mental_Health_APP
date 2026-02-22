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

      // ApiClient.post returns parsed JSON (decoded body) or throws.
      final decoded = await ApiClient.post(
        "/predict",
        {"text": text},
      );

      if (decoded is Map<String, dynamic>) {
        return {
          "emotion": decoded["emotion"] ?? "neutral",
          "confidence": (decoded["confidence"] is num)
              ? (decoded["confidence"] as num).toDouble()
              : 0.5,
          "severity": decoded["severity"] ?? 1,
          "timestamp": decoded["timestamp"] ?? DateTime.now().toIso8601String(),
        };
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

      final decoded = await ApiClient.get("/history");

      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
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

      final decoded = await ApiClient.post(
        "/semantic-search",
        {"query": query},
      );

      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
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

      final decoded = await ApiClient.get("/profile");

      if (decoded is Map<String, dynamic>) {
        return decoded;
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
  String? name,
  String? email,
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

    final Map<String, dynamic> body = {};

    if (name != null && name.isNotEmpty) {
      body["name"] = name;
    }

    if (email != null && email.isNotEmpty) {
      body["email"] = email;
    }

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

    await ApiClient.put("/profile", body);

    return true;
  } catch (e) {
    throw Exception(e.toString());
  }
}
}
