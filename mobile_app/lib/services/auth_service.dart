import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthService {
  // 🔥 REAL PHONE FIX — PC IP
  static const String baseUrl = "http://10.21.175.226:8000";

  static const String _accessTokenKey = "access_token";

  static const Duration _timeout = Duration(seconds: 12);

  // =========================
  // REGISTER
  // =========================
  static Future<bool> register(String email, String password) async {
    try {
      final res = await http
          .post(
            Uri.parse("$baseUrl/register"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": email,
              "password": password,
            }),
          )
          .timeout(_timeout);

      if (res.statusCode != 200) {
        _log("REGISTER FAILED: ${res.statusCode} | ${res.body}");
      }

      return res.statusCode == 200;
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
      final res = await http
          .post(
            Uri.parse("$baseUrl/login"),
            headers: {
              "Content-Type": "application/x-www-form-urlencoded",
            },
            body: {
              "username": email, // OAuth2PasswordRequestForm
              "password": password,
            },
          )
          .timeout(_timeout);

      if (res.statusCode != 200) {
        _log("LOGIN FAILED: ${res.statusCode} | ${res.body}");
        return false;
      }

      final data = jsonDecode(res.body);
      final accessToken = data["access_token"];

      if (accessToken == null || JwtDecoder.isExpired(accessToken)) {
        _log("INVALID OR EXPIRED TOKEN");
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, accessToken);

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
    final registered = await register(email, password);
    if (!registered) return false;

    return await login(email, password);
  }

  // =========================
  // 🔐 CHECK LOGIN STATE
  // =========================
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  // =========================
  // 🔑 GET VALID TOKEN
  // =========================
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);

    if (token == null) return null;

    if (JwtDecoder.isExpired(token)) {
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
