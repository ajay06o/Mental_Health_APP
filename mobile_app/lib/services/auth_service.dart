import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  static const String _accessTokenKey = "access_token";

  /// Cached login state (used by router / splash)
  static bool cachedLoginState = false;

  static bool _initialized = false;

  // =========================
  // 🔁 INIT (USED IN main.dart)
  // =========================
  static Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);

    if (token != null && !JwtDecoder.isExpired(token)) {
      cachedLoginState = true;
    } else {
      cachedLoginState = false;
      await prefs.remove(_accessTokenKey);
    }

    _initialized = true;
  }

  // =========================
  // 🆕 REGISTER
  // =========================
  static Future<bool> register(String email, String password) async {
    final response = await ApiClient.post(
      "/register",
      {
        "email": email.trim(),
        "password": password.trim(),
      },
    );

    print("REGISTER ${response.statusCode}: ${response.body}");

    if (response.statusCode != 200) return false;

    final data = jsonDecode(response.body);
    final token = data["access_token"];

    if (token != null && !JwtDecoder.isExpired(token)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, token);
      cachedLoginState = true;
    }

    return true;
  }

  // =========================
  // 🔐 LOGIN
  // =========================
  static Future<bool> login(String email, String password) async {
    final response = await ApiClient.postForm(
      "/login",
      {
        "username": email.trim(), // OAuth2 expects "username"
        "password": password.trim(),
      },
    );

    print("LOGIN ${response.statusCode}: ${response.body}");

    if (response.statusCode != 200) return false;

    final data = jsonDecode(response.body);
    final token = data["access_token"];

    if (token == null || JwtDecoder.isExpired(token)) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);

    cachedLoginState = true;
    return true;
  }

  // =========================
  // 🚀 REGISTER + AUTO LOGIN
  // (USED IN register_screen.dart)
  // =========================
  static Future<bool> registerAndAutoLogin(
    String email,
    String password,
  ) async {
    final ok = await register(email, password);
    if (!ok) return false;

    return await login(email, password);
  }

  // =========================
  // 🔎 CHECK LOGIN STATE
  // (USED IN splash_screen.dart)
  // =========================
  static Future<bool> isLoggedIn() async {
    if (!_initialized) {
      await init();
    }
    return cachedLoginState;
  }

  // =========================
  // 🎟️ GET VALID TOKEN
  // =========================
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);

    if (token == null || JwtDecoder.isExpired(token)) {
      await logout();
      return null;
    }
    return token;
  }

  // =========================
  // 🚪 LOGOUT
  // =========================
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    cachedLoginState = false;
  }
}
