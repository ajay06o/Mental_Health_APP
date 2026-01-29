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

  /// Cached login state (used by router / splash)
  static bool cachedLoginState = false;

  static bool _initialized = false;

  // =========================
  // 🔁 INIT (USED IN main.dart / splash)
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

    if (response.statusCode != 200) return false;

    final data = jsonDecode(response.body);
    return await _saveTokensFromResponse(data);
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

    if (response.statusCode != 200) return false;

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
    final ok = await register(email, password);
    if (!ok) return false;

    return await login(email, password);
  }

  // =========================
  // 🔎 CHECK LOGIN STATE
  // =========================
  static Future<bool> isLoggedIn() async {
    if (!_initialized) {
      await init();
    }
    return cachedLoginState;
  }

  // =========================
  // 🎟️ GET ACCESS TOKEN
  // (USED BY ApiClient)
  // =========================
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);

    if (token == null) return null;

    if (JwtDecoder.isExpired(token)) {
      // ❌ Do NOT logout here
      // ApiClient will refresh token automatically
      return null;
    }

    return token;
  }

  // =========================
  // 🔁 GET REFRESH TOKEN
  // (USED BY ApiClient)
  // =========================
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // =========================
  // 💾 SAVE ACCESS TOKEN ONLY
  // ✅ REQUIRED BY ApiClient REFRESH FLOW
  // =========================
  static Future<void> saveAccessToken(String accessToken) async {
    if (JwtDecoder.isExpired(accessToken)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);

    cachedLoginState = true;
  }

  // =========================
  // 💾 SAVE TOKENS (LOGIN / REGISTER)
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

