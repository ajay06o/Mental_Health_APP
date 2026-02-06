import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

class AuthService {
  // =========================
  // TOKEN STORAGE
  // =========================
  static const String _accessTokenKey = "access_token";
  static const String _refreshTokenKey = "refresh_token";

  // =========================
  // 🔐 SECURE STORAGE (CREDENTIALS)
  // =========================
  static const FlutterSecureStorage _secureStorage =
      FlutterSecureStorage();

  static const String _savedEmailKey = "saved_email";
  static const String _savedPasswordKey = "saved_password";
  static const String _rememberMeKey = "remember_me";

  static bool cachedLoginState = false;
  static bool _initialized = false;

  // =========================
  // 🔁 INIT (SAFE & IDEMPOTENT)
  // =========================
  static Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);

    cachedLoginState =
        token != null && !JwtDecoder.isExpired(token);

    if (!cachedLoginState) {
      await _clearTokens(prefs);
    }

    _initialized = true;
  }

  // =========================
  // 🆕 REGISTER (PUBLIC)
  // =========================
  static Future<bool> register(
    String email,
    String password,
  ) async {
    final response = await ApiClient.postPublic(
      "/register",
      {
        "email": email.trim(),
        "password": password.trim(),
      },
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      return false;
    }

    return true;
  }

  // =========================
  // 🔐 LOGIN (OAUTH2 FORM)
  // =========================
  static Future<bool> login(
    String email,
    String password,
  ) async {
    final response = await ApiClient.postForm(
      "/login",
      {
        "username": email.trim(),
        "password": password.trim(),
      },
    );

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body);
    return _saveTokensFromResponse(data);
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

    return login(email, password);
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
  /// IMPORTANT:
  /// - Does NOT refresh
  /// - ApiClient handles refresh & retry
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);

    if (token == null) return null;
    if (JwtDecoder.isExpired(token)) return null;

    return token;
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
  static Future<void> saveAccessToken(
    String accessToken,
  ) async {
    if (JwtDecoder.isExpired(accessToken)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    cachedLoginState = true;
  }

  // =========================
  // 💾 SAVE TOKENS FROM LOGIN
  // =========================
  static Future<bool> _saveTokensFromResponse(
    Map<String, dynamic> data,
  ) async {
    final accessToken = data["access_token"];
    final refreshToken = data["refresh_token"];

    if (accessToken == null ||
        JwtDecoder.isExpired(accessToken)) {
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

  // =================================================
  // 🔐 SAVE LOGIN CREDENTIALS (SECURE)
  // =================================================
  static Future<void> saveLoginCredentials({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    await _secureStorage.write(
      key: _rememberMeKey,
      value: rememberMe.toString(),
    );

    await _secureStorage.write(
      key: _savedEmailKey,
      value: email,
    );

    if (rememberMe) {
      await _secureStorage.write(
        key: _savedPasswordKey,
        value: password,
      );
    } else {
      await _secureStorage.delete(key: _savedPasswordKey);
    }
  }

  // =================================================
  // 📥 LOAD SAVED CREDENTIALS
  // =================================================
  static Future<Map<String, String>>
      loadSavedCredentials() async {
    final rememberMe =
        await _secureStorage.read(key: _rememberMeKey);

    if (rememberMe != "true") return {};

    return {
      "email":
          await _secureStorage.read(key: _savedEmailKey) ?? "",
      "password":
          await _secureStorage.read(key: _savedPasswordKey) ?? "",
    };
  }

  // =================================================
  // 🔎 REMEMBER ME STATUS
  // =================================================
  static Future<bool> isRememberMeEnabled() async {
    final rememberMe =
        await _secureStorage.read(key: _rememberMeKey);
    return rememberMe == "true";
  }

  // =========================
  // 🚪 LOGOUT
  // =========================
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearTokens(prefs);

    await _secureStorage.delete(key: _savedPasswordKey);

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
