import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _key = "trend_points";

  static Future<void> saveTrends(List<Map<String, dynamic>> trends) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(trends));
  }

  static Future<List<Map<String, dynamic>>> loadTrends() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null) return [];

    final List decoded = jsonDecode(raw);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

