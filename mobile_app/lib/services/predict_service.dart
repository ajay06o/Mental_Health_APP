import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import 'api_client.dart';
import 'auth_service.dart';

class PredictService {
  // =====================================================
  // 🧠 PREDICT EMOTION (FULLY UPDATED + BACKWARD SAFE)
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
        final String emotion =
            decoded["emotion"] ?? "Neutral";

        final double confidence =
            (decoded["confidence"] is num)
                ? (decoded["confidence"] as num).toDouble()
                : 0.5;

        final String severityString =
            decoded["severity"] ?? "low";

        final String risk =
            decoded["risk"] ?? "low";

        final int mhi =
            (decoded["mental_health_index"] is num)
                ? (decoded["mental_health_index"] as num).toInt()
                : 70;

        final bool emergencyTriggered =
            decoded["emergency_triggered"] ?? false;

        // -------------------------------------------------
        // 🔁 BACKWARD COMPATIBILITY
        // Convert severity string → old int scale (1–5)
        // -------------------------------------------------
        int severityInt;

        switch (emotion) {
          case "Suicidal":
            severityInt = 5;
            break;
          case "Depression":
            severityInt = 4;
            break;
          case "Anxiety":
            severityInt = 3;
            break;
          case "Sad":
          case "Angry":
            severityInt = 2;
            break;
          case "Happy":
            severityInt = 1;
            break;
          default:
            severityInt = 1;
        }

        return {
          // Old fields (DO NOT REMOVE)
          "emotion": emotion,
          "confidence": confidence,
          "severity": severityInt,
          "timestamp": DateTime.now().toIso8601String(),

          // 🆕 New Dynamic Fields
          "severity_label": severityString,
          "risk": risk,
          "mental_health_index": mhi,
          "emergency_triggered": emergencyTriggered,
        };
      }

      return _safePredictFallback();
    } catch (_) {
      return _safePredictFallback();
    }
  }

  // =====================================================
  // 🛟 SAFE FALLBACK (FULLY COMPATIBLE)
  // =====================================================
  static Map<String, dynamic> _safePredictFallback() {
    return {
      "emotion": "Neutral",
      "confidence": 0.3,
      "severity": 1,
      "severity_label": "low",
      "risk": "low",
      "mental_health_index": 70,
      "emergency_triggered": false,
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
  // 🗑 DELETE HISTORY
  // =====================================================
  static Future<void> deleteHistory(int id) async {
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) {
        throw Exception("User not authenticated");
      }

      await ApiClient.delete("/history/$id");
    } catch (e) {
      throw Exception("Failed to delete history: $e");
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
  // 🖼 UPLOAD PROFILE IMAGE
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