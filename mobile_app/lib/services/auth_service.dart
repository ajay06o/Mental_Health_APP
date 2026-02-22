import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

class AuthService {
  // =================================================
  // 🔐 TOKEN KEYS
  // =================================================
  static const String _accessTokenKey = "access_token";
  static const String _refreshTokenKey = "refresh_token";

  // =================================================
  // 💾 REMEMBER ME KEYS
  // =================================================
  static const String _savedEmailKey = "saved_email";
  static const String _savedPasswordKey = "saved_password";
  static const String _rememberMeKey = "remember_me";

  static const FlutterSecureStorage _secureStorage =
      FlutterSecureStorage();

  // 🔥 MEMORY CACHE (Fix Web issues)
  static String? _memoryAccessToken;
  static String? _memoryRefreshToken;

  static bool cachedLoginState = false;
  static bool _initialized = false;

  // =================================================
  // 🚀 INIT
  // =================================================
  static Future<void> init() async {
    if (_initialized) return;

    try {
      final token =
          await _secureStorage.read(key: _accessTokenKey);

      if (token != null &&
          token.isNotEmpty &&
          !JwtDecoder.isExpired(token)) {
        _memoryAccessToken = token;
        cachedLoginState = true;
      } else {
        await _clearTokens();
        cachedLoginState = false;
      }
    } catch (_) {
      cachedLoginState = false;
    }

    _initialized = true;
  }

  // =================================================
  // 📝 REGISTER
  // =================================================
  static Future<bool> register(
      String email, String password) async {
    try {
      await ApiClient.postPublic(
        "/register",
        {
          "email": email.trim(),
          "password": password.trim(),
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // =================================================
  // 🆕 REGISTER + AUTO LOGIN
  // =================================================
  static Future<bool> registerAndAutoLogin(
      String email, String password) async {
    final registered =
        await register(email, password);
    if (!registered) return false;

    return await login(email, password);
  }

  // =================================================
  // 🔑 LOGIN
  // =================================================
  static Future<bool> login(
      String email, String password) async {
    try {
      final data = await ApiClient.postForm(
        "/login",
        {
          "username": email.trim(),
          "password": password.trim(),
        },
      );

      return await _saveTokensFromResponse(data);
    } catch (_) {
      return false;
    }
  }

  // =================================================
  // 🔐 SAVE TOKENS
  // =================================================
  static Future<bool> _saveTokensFromResponse(
      Map<String, dynamic> data) async {
    final accessToken = data["access_token"];
    final refreshToken = data["refresh_token"];

    if (accessToken == null ||
        JwtDecoder.isExpired(accessToken)) {
      return false;
    }

    // Save to memory
    _memoryAccessToken = accessToken;
    _memoryRefreshToken = refreshToken;

    // Save to storage
    await _secureStorage.write(
      key: _accessTokenKey,
      value: accessToken,
    );

    if (refreshToken != null) {
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: refreshToken,
      );
    }

    cachedLoginState = true;
    return true;
  }

  // =================================================
  // 🎫 GET ACCESS TOKEN
  // =================================================
  static Future<String?> getAccessToken() async {
    if (_memoryAccessToken != null &&
        !JwtDecoder.isExpired(_memoryAccessToken!)) {
      return _memoryAccessToken;
    }

    try {
      final token =
          await _secureStorage.read(key: _accessTokenKey);

      if (token != null &&
          token.isNotEmpty &&
          !JwtDecoder.isExpired(token)) {
        _memoryAccessToken = token;
        return token;
      }
    } catch (_) {}

    return null;
  }

  // =================================================
  // 🔄 GET REFRESH TOKEN
  // =================================================
  static Future<String?> getRefreshToken() async {
    if (_memoryRefreshToken != null) {
      return _memoryRefreshToken;
    }

    try {
      final token =
          await _secureStorage.read(key: _refreshTokenKey);
      _memoryRefreshToken = token;
      return token;
    } catch (_) {
      return null;
    }
  }

  // =================================================
  // 🔄 SAVE ACCESS TOKEN (ON REFRESH)
  // =================================================
  static Future<void> saveAccessToken(
      String accessToken) async {
    if (JwtDecoder.isExpired(accessToken)) return;

    _memoryAccessToken = accessToken;

    await _secureStorage.write(
      key: _accessTokenKey,
      value: accessToken,
    );

    cachedLoginState = true;
  }

  // =================================================
  // 💾 SAVE LOGIN CREDENTIALS
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
      value: email.trim(),
    );

    if (rememberMe) {
      await _secureStorage.write(
        key: _savedPasswordKey,
        value: password,
      );
    } else {
      await _secureStorage.delete(
          key: _savedPasswordKey);
    }
  }

  // =================================================
  // 📂 LOAD SAVED CREDENTIALS
  // =================================================
  static Future<Map<String, String>>
      loadSavedCredentials() async {
    final remember =
        await _secureStorage.read(
            key: _rememberMeKey);

    if (remember != "true") return {};

    return {
      "email":
          await _secureStorage.read(
                  key: _savedEmailKey) ??
              "",
      "password":
          await _secureStorage.read(
                  key: _savedPasswordKey) ??
              "",
    };
  }

  // =================================================
  // 🔄 REMEMBER ME STATUS
  // =================================================
  static Future<bool> isRememberMeEnabled() async {
    final remember =
        await _secureStorage.read(
            key: _rememberMeKey);
    return remember == "true";
  }

  // =================================================
  // 🔍 LOGIN STATE
  // =================================================
  static Future<bool> isLoggedIn() async {
    if (!_initialized) {
      await init();
    }
    return cachedLoginState;
  }

  // =================================================
  // 🚪 LOGOUT
  // =================================================
  static Future<void> logout() async {
    await _clearTokens();
    _memoryAccessToken = null;
    _memoryRefreshToken = null;
    cachedLoginState = false;
  }

  // =================================================
  // 🧹 CLEAR TOKENS
  // =================================================
  static Future<void> _clearTokens() async {
    await _secureStorage.delete(
        key: _accessTokenKey);
    await _secureStorage.delete(
        key: _refreshTokenKey);
  }
}
