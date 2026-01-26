import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  static const String _accessTokenKey = "access_token";

  // ✅ Used by GoRouter redirect (sync read)
  static bool cachedLoginState = false;

  // ✅ Prevent repeated disk reads
  static bool _initialized = false;

  // =========================
  // 🔁 INIT (CALL ON APP START)
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
  // REGISTER
  // =========================
  static Future<bool> register(String email, String password) async {
    try {
      final response = await ApiClient.post(
        "/register",
        {
          "email": email,
          "password": password,
        },
      );

      if (response.statusCode != 200) {
        _log("REGISTER FAILED: ${response.statusCode} | ${response.body}");
        return false;
      }

      return true;
    } catch (e) {
      _log("REGISTER EXCEPTION: $e");
      return false;
    }
  }

  // =========================
  // LOGIN
  // =========================
  static Future<bool> login(String email, String password) async {
    try {
      final response = await ApiClient.postForm(
        "/login",
        {
          "username": email,
          "password": password,
        },
      );

      if (response.statusCode != 200) {
        _log("LOGIN FAILED: ${response.statusCode} | ${response.body}");
        return false;
      }

      final data = jsonDecode(response.body);
      final accessToken = data["access_token"];

      if (accessToken == null || JwtDecoder.isExpired(accessToken)) {
        _log("INVALID OR EXPIRED TOKEN");
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, accessToken);

      cachedLoginState = true;
      return true;
    } catch (e) {
      _log("LOGIN EXCEPTION: $e");
      return false;
    }
  }

  // =========================
  // 🚀 REGISTER + AUTO LOGIN
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
  // 🔐 CHECK LOGIN STATE
  // =========================
  static Future<bool> isLoggedIn() async {
    if (!_initialized) {
      await init();
    }
    return cachedLoginState;
  }

  // =========================
  // 🔑 GET VALID TOKEN
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

  // =========================
  // 🐞 DEBUG LOG
  // =========================
  static void _log(String message) {
    assert(() {
      // ignore: avoid_print
      print("[AuthService] $message");
      return true;
    }());
  }
}
