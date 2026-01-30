import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  // =========================
  // STORAGE KEYS
  // =========================
  static const String _accessTokenKey = "access_token";
  static const String _refreshTokenKey = "refresh_token";

  static bool cachedLoginState = false;
  static bool _initialized = false;

  // =========================
  // 🔁 INIT
  // =========================
  static Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);

    if (accessToken != null && !JwtDecoder.isExpired(accessToken)) {
      cachedLoginState = true;
    } else {
      cachedLoginState = false;
      await _clearTokens(prefs);
    }

    _initialized = true;
  }

  // =========================
  // 🆕 REGISTER (PUBLIC)
  // =========================
  static Future<bool> register(String email, String password) async {
    final response = await ApiClient.postPublic(
      "/register",
      {
        "email": email.trim(),
        "password": password.trim(),
      },
    );

    // ✅ ACCEPT 200 & 201 AS SUCCESS
    if (response.statusCode != 200 && response.statusCode != 201) {
      print("REGISTER FAILED ${response.statusCode}: ${response.body}");
      return false;
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
        "username": email.trim(),
        "password": password.trim(),
      },
    );

    if (response.statusCode != 200) {
      print("LOGIN FAILED ${response.statusCode}: ${response.body}");
      return false;
    }

    final data = jsonDecode(response.body);
    return await _saveTokensFromResponse(data);
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
  // 🔎 LOGIN STATE
  // =========================
  static Future<bool> isLoggedIn() async {
    if (!_initialized) {
      await init();
    }
    return cachedLoginState;
  }

  // =========================
  // 🎟️ GET ACCESS TOKEN
  // =========================
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);

    if (accessToken == null) return null;

    if (!JwtDecoder.isExpired(accessToken)) {
      return accessToken;
    }

    return await _refreshAccessToken();
  }

  // =========================
  // 🔁 GET REFRESH TOKEN
  // =========================
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // =========================
  // 💾 SAVE ACCESS TOKEN
  // =========================
  static Future<void> saveAccessToken(String accessToken) async {
    if (JwtDecoder.isExpired(accessToken)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    cachedLoginState = true;
  }

  // =========================
  // 🔁 REFRESH ACCESS TOKEN (PUBLIC)
  // =========================
  static Future<String?> _refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      await logout();
      return null;
    }

    try {
      final response = await ApiClient.postPublic(
        "/refresh",
        {"refresh_token": refreshToken},
      );

      if (response.statusCode != 200) {
        await logout();
        return null;
      }

      final data = jsonDecode(response.body);
      final newAccessToken = data["access_token"];

      if (newAccessToken == null ||
          JwtDecoder.isExpired(newAccessToken)) {
        await logout();
        return null;
      }

      await saveAccessToken(newAccessToken);
      return newAccessToken;
    } catch (_) {
      await logout();
      return null;
    }
  }

  // =========================
  // 💾 SAVE TOKENS FROM LOGIN
  // =========================
  static Future<bool> _saveTokensFromResponse(
    Map<String, dynamic> data,
  ) async {
    final accessToken = data["access_token"];
    final refreshToken = data["refresh_token"];

    if (accessToken == null || JwtDecoder.isExpired(accessToken)) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);

    if (refreshToken != null) {
      await prefs.setString(_refreshTokenKey, refreshToken);
    }

    cachedLoginState = true;
    return true;
  }

  // =========================
  // 🚪 LOGOUT
  // =========================
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearTokens(prefs);
    cachedLoginState = false;
  }

  // =========================
  // 🧹 CLEAR TOKENS
  // =========================
  static Future<void> _clearTokens(
    SharedPreferences prefs,
  ) async {
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}
