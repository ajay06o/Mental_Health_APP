import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  // =========================
  // KEYS
  // =========================
  static const String _trendKey = "trend_points";
  static const String _tokenKey = "access_token";

  // =========================
  // SAVE TRENDS
  // =========================
  static Future<void> saveTrends(
    List<Map<String, dynamic>> trends,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trendKey, jsonEncode(trends));
  }

  // =========================
  // LOAD TRENDS (SAFE)
  // =========================
  static Future<List<Map<String, dynamic>>> loadTrends() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_trendKey);

    if (raw == null || raw.isEmpty) return [];

    try {
      final List<dynamic> decoded = jsonDecode(raw);

      return decoded.map<Map<String, dynamic>>((item) {
        if (item is Map<String, dynamic>) {
          return item;
        }
        return {};
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // =========================
  // SAVE TOKEN
  // =========================
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // =========================
  // GET TOKEN
  // =========================
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // =========================
  // CLEAR TOKEN
  // =========================
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // =========================
  // CLEAR ALL APP DATA
  // =========================
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

