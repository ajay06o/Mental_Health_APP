import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';
import '../router/app_router.dart';

class AuthService {
  // =================================================
  // 🔐 TOKEN KEYS
  // =================================================
  static const String _accessTokenKey = "access_token";
  static const String _refreshTokenKey = "refresh_token";

  // =================================================
  // 🔐 SECURE STORAGE
  // =================================================
  static const FlutterSecureStorage _secureStorage =
      FlutterSecureStorage();

  // =================================================
  // 💾 REMEMBER ME KEYS
  // =================================================
  static const String _savedEmailKey = "saved_email";
  static const String _savedPasswordKey = "saved_password";
  static const String _rememberMeKey = "remember_me";

  static bool cachedLoginState = false;
  static bool _initialized = false;

  // =================================================
  // 🚀 INIT
  // =================================================
  static Future<void> init() async {
    if (_initialized) return;

    final token =
        await _secureStorage.read(key: _accessTokenKey);

    if (token != null &&
        token.isNotEmpty &&
        !JwtDecoder.isExpired(token)) {
      cachedLoginState = true;
    } else {
      cachedLoginState = false;
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
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

      final success =
          await _saveTokensFromResponse(data);

      if (success) {
        authNotifier.notify();
      }

      return success;
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
  // 🔍 LOGIN STATE
  // =================================================
  static Future<bool> isLoggedIn() async {
    if (!_initialized) {
      await init();
    }
    return cachedLoginState;
  }

  // =================================================
  // 🎫 GET ACCESS TOKEN
  // =================================================
  static Future<String?> getAccessToken() async {
    final token =
        await _secureStorage.read(key: _accessTokenKey);

    if (token == null ||
        token.isEmpty ||
        JwtDecoder.isExpired(token)) {
      return null;
    }

    return token;
  }

  // =================================================
  // 🔄 GET REFRESH TOKEN
  // =================================================
  static Future<String?> getRefreshToken() async {
    return await _secureStorage.read(
        key: _refreshTokenKey);
  }

  // =================================================
  // 🔐 SAVE ACCESS TOKEN (ON REFRESH)
  // =================================================
  static Future<void> saveAccessToken(
      String accessToken) async {
    if (JwtDecoder.isExpired(accessToken)) return;

    await _secureStorage.write(
      key: _accessTokenKey,
      value: accessToken,
    );

    cachedLoginState = true;
    authNotifier.notify();
  }

  // =================================================
  // 👤 GET USER INFO
  // =================================================
  static Future<Map<String, dynamic>?>
      getUserFromToken() async {
    final token = await getAccessToken();
    if (token == null) return null;

    return JwtDecoder.decode(token);
  }

  // =================================================
  // ⏳ TOKEN EXPIRY CHECK
  // =================================================
  static Future<bool> isTokenExpiringSoon(
      {int minutes = 2}) async {
    final token = await getAccessToken();
    if (token == null) return true;

    final expiryDate =
        JwtDecoder.getExpirationDate(token);

    final remaining =
        expiryDate.difference(DateTime.now());

    return remaining.inMinutes <= minutes;
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
    final rememberMe =
        await _secureStorage.read(
            key: _rememberMeKey);

    if (rememberMe != "true") return {};

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
    final rememberMe =
        await _secureStorage.read(
            key: _rememberMeKey);
    return rememberMe == "true";
  }

  // =================================================
  // 🚪 LOGOUT
  // =================================================
  static Future<void> logout() async {
    await _secureStorage.delete(
        key: _accessTokenKey);
    await _secureStorage.delete(
        key: _refreshTokenKey);
    await _secureStorage.delete(
        key: _savedPasswordKey);

    cachedLoginState = false;

    authNotifier.notify();
  }
}
