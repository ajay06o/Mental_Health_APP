import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import 'api_client.dart';
import 'auth_service.dart';

class PredictService {
  // =====================================================
  // 🧠 PREDICT EMOTION
  // =====================================================
  static Future<Map<String, dynamic>> predictEmotion(String text) async {
    if (text.trim().isEmpty) {
      return _safePredictFallback();
    }

    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        throw Exception("User not authenticated");
      }

      final decoded = await ApiClient.post(
        "/predict",
        {"text": text.trim()},
      );

      if (decoded is Map<String, dynamic>) {
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

  // =====================================================
  // 📜 FETCH HISTORY
  // =====================================================
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

  // =====================================================
  // 👤 FETCH PROFILE
  // =====================================================
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

  // =====================================================
  // ✏️ UPDATE PROFILE
  // =====================================================
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

      if (name != null && name.trim().isNotEmpty) {
        body["name"] = name.trim();
      }

      if (email != null && email.trim().isNotEmpty) {
        body["email"] = email.trim();
      }

      if (password != null && password.trim().isNotEmpty) {
        body["password"] = password.trim();
      }

      if (emergencyName != null &&
          emergencyName.trim().isNotEmpty) {
        body["emergency_name"] = emergencyName.trim();
      }

      if (emergencyEmail != null &&
          emergencyEmail.trim().isNotEmpty) {
        body["emergency_email"] = emergencyEmail.trim();
      }

      if (alertsEnabled != null) {
        body["alerts_enabled"] = alertsEnabled;
      }

      if (body.isEmpty) {
        return true;
      }

      await ApiClient.put("/profile", body);

      return true;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // =====================================================
  // 🖼 UPLOAD PROFILE IMAGE (WEB + MOBILE SAFE)
  // =====================================================
  static Future<String?> uploadProfileImage(dynamic image) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        throw Exception("User not authenticated");
      }

      final decoded = await ApiClient.multipart(
        "/profile/upload-image",
        file: image,
        fieldName: "file",
      );

      if (decoded is Map<String, dynamic>) {
        return decoded["profile_image"];
      }

      return null;
    } catch (e) {
      throw Exception("Image upload failed: $e");
    }
  }
}