import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class PredictService {
  static const String baseUrl = "http://127.0.0.1:8000";

  // ==============================
  // COMMON HEADERS
  // ==============================
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getAccessToken();
    if (token == null) {
      throw Exception("User not authenticated");
    }

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ==============================
  // PREDICT EMOTION
  // ==============================
  static Future<Map<String, dynamic>> predictEmotion(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/predict"),
            headers: await _headers(),
            body: jsonEncode({"text": text}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 401) {
        throw Exception("Session expired. Please login again.");
      }

      throw Exception("Prediction failed (${response.statusCode})");
    } on SocketException {
      throw Exception("No internet connection");
    }
  }

  // ==============================
  // FETCH HISTORY
  // ==============================
  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/history"),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List decoded = jsonDecode(response.body);
        return decoded
            .whereType<Map<String, dynamic>>()
            .toList();
      }

      if (response.statusCode == 401) {
        throw Exception("Session expired. Please login again.");
      }

      throw Exception("Failed to load history (${response.statusCode})");
    } on SocketException {
      throw Exception("No internet connection");
    }
  }

  // ==============================
  // 🧠 AI SEMANTIC SEARCH (MULTILINGUAL)
  // ==============================
  static Future<List<Map<String, dynamic>>> semanticSearch(
    String query,
  ) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/semantic-search"),
            headers: await _headers(),
            body: jsonEncode({
              "query": query,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List decoded = jsonDecode(response.body);

        // 🔒 Strong type safety (prevents null/int crash)
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => {
                  "index": e["index"] ?? 0,
                  "score": (e["score"] ?? 0.0).toDouble(),
                  "text": e["text"] ?? "",
                  "emotion": e["emotion"] ?? "unknown",
                  "severity": e["severity"] ?? 0,
                  "confidence": (e["confidence"] ?? 0.0).toDouble(),
                  "timestamp": e["timestamp"] ?? "",
                })
            .toList();
      }

      if (response.statusCode == 401) {
        throw Exception("Session expired. Please login again.");
      }

      throw Exception("Semantic search failed (${response.statusCode})");
    } on SocketException {
      throw Exception("No internet connection");
    }
  }

  // ==============================
  // FETCH PROFILE
  // ==============================
  static Future<Map<String, dynamic>> fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/profile"),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 401) {
        throw Exception("Session expired. Please login again.");
      }

      throw Exception("Failed to load profile");
    } on SocketException {
      throw Exception("No internet connection");
    }
  }

  // ==============================
  // UPDATE PROFILE
  // ==============================
  static Future<void> updateProfile(String email) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/profile"),
        headers: await _headers(),
        body: jsonEncode({"email": email}),
      );

      if (response.statusCode != 200) {
        throw Exception("Profile update failed");
      }
    } on SocketException {
      throw Exception("No internet connection");
    }
  }
}
