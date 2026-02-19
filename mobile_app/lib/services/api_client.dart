import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  // =================================================
  // 🌍 ENV CONFIG (DEV / PROD READY)
  // =================================================
  static const bool isProduction = true;

  static const String _prodUrl =
      "https://mental-health-app-zpng.onrender.com";

  static const String _devUrl =
      "http://10.0.2.2:8000";

  static String get baseUrl =>
      isProduction ? _prodUrl : _devUrl;

  static const Duration _defaultTimeout =
      Duration(seconds: 60);

  static const Duration _predictTimeout =
      Duration(seconds: 120);

  static final http.Client _client = http.Client();

  static Future<String?>? _refreshFuture;

  /// Global session expired callback (UI handles redirect)
  static Function()? onSessionExpired;

  // =================================================
  // 🔥 SERVER WARMUP
  // =================================================
  static Future<void> warmUpServer() async {
    try {
      await _client
          .get(Uri.parse(baseUrl))
          .timeout(_defaultTimeout);
    } catch (_) {
      // Ignore warmup failure
    }
  }

  // =================================================
  // 🧾 HEADERS
  // =================================================
  static Future<Map<String, String>> _headers({
    bool json = true,
    bool withAuth = false,
    bool isForm = false,
  }) async {
    final headers = <String, String>{
      "Accept": "application/json",
    };

    if (json) {
      headers["Content-Type"] = "application/json";
    }

    if (isForm) {
      headers["Content-Type"] =
          "application/x-www-form-urlencoded";
    }

    if (withAuth) {
      final token = await AuthService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers["Authorization"] = "Bearer $token";
      }
    }

    return headers;
  }

  // =================================================
  // 🛡 SAFE REQUEST (AUTO REFRESH)
  // =================================================
  static Future<http.Response> _safeRequest(
    Future<http.Response> Function() request, {
    Duration? timeout,
    bool retrying = false,
  }) async {
    try {
      final response =
          await request().timeout(timeout ?? _defaultTimeout);

      if (response.statusCode != 401) {
        return response;
      }

      if (retrying) {
        await _handleSessionExpired();
        throw ApiException("Session expired. Please login again.");
      }

      final newToken = await _refreshTokenQueued();

      if (newToken == null) {
        await _handleSessionExpired();
        throw ApiException("Session expired. Please login again.");
      }

      return await _safeRequest(
        request,
        timeout: timeout,
        retrying: true,
      );
    } on TimeoutException {
      throw ApiException("Server is waking up. Please wait...");
    } on SocketException {
      throw ApiException("No internet connection.");
    } on FormatException {
      throw ApiException("Invalid server response.");
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException("Unexpected error occurred.");
    }
  }

  // =================================================
  // 🔁 REFRESH TOKEN (QUEUED)
  // =================================================
  static Future<String?> _refreshTokenQueued() {
    _refreshFuture ??= _refreshToken();
    return _refreshFuture!.whenComplete(() {
      _refreshFuture = null;
    });
  }

  static Future<String?> _refreshToken() async {
    final refreshToken =
        await AuthService.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await _client.post(
        Uri.parse("$baseUrl/refresh"),
        headers: const {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "refresh_token": refreshToken,
        }),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final newToken = data["access_token"];

      if (newToken == null || newToken.isEmpty) {
        return null;
      }

      await AuthService.saveAccessToken(newToken);
      return newToken;
    } catch (_) {
      return null;
    }
  }

  // =================================================
  // 🔄 HANDLE SESSION EXPIRED
  // =================================================
  static Future<void> _handleSessionExpired() async {
    await AuthService.logout();
    onSessionExpired?.call();
  }

  // =================================================
  // 🔄 RESPONSE PARSER
  // =================================================
  static dynamic _parseResponse(
      http.Response response) {
    if (response.body.isEmpty) return null;

    try {
      final decoded = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        return decoded;
      }

      throw ApiException(
        decoded["detail"] ??
            decoded["message"] ??
            "Something went wrong",
      );
    } catch (_) {
      throw ApiException("Invalid server response.");
    }
  }

  // =================================================
  // 🌐 PUBLIC METHODS
  // =================================================
  static Future<dynamic> getPublic(
      String endpoint) async {
    final response = await _client.get(
      Uri.parse("$baseUrl$endpoint"),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  static Future<dynamic> postPublic(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse("$baseUrl$endpoint"),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    return _parseResponse(response);
  }

  // =================================================
  // 🔑 FORM POST (FOR LOGIN)
  // =================================================
  static Future<dynamic> postForm(
    String endpoint,
    Map<String, String> body,
  ) async {
    final response = await _client.post(
      Uri.parse("$baseUrl$endpoint"),
      headers: await _headers(
        json: false,
        isForm: true,
      ),
      body: body,
    );

    return _parseResponse(response);
  }

  // =================================================
  // 🔐 AUTH METHODS
  // =================================================
  static Future<dynamic> get(String endpoint) async {
    final response = await _safeRequest(() async {
      return _client.get(
        Uri.parse("$baseUrl$endpoint"),
        headers: await _headers(withAuth: true),
      );
    });

    return _parseResponse(response);
  }

  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await _safeRequest(() async {
      return _client.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: await _headers(withAuth: true),
        body: jsonEncode(body),
      );
    });

    return _parseResponse(response);
  }

  static Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await _safeRequest(() async {
      return _client.put(
        Uri.parse("$baseUrl$endpoint"),
        headers: await _headers(withAuth: true),
        body: jsonEncode(body),
      );
    });

    return _parseResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final response = await _safeRequest(() async {
      return _client.delete(
        Uri.parse("$baseUrl$endpoint"),
        headers: await _headers(withAuth: true),
      );
    });

    return _parseResponse(response);
  }

  // =================================================
  // 🧠 PREDICT (LONG RUNNING)
  // =================================================
  static Future<dynamic> predict(
    Map<String, dynamic> body,
  ) async {
    final response = await _safeRequest(
      () async {
        return _client.post(
          Uri.parse("$baseUrl/predict"),
          headers: await _headers(withAuth: true),
          body: jsonEncode(body),
        );
      },
      timeout: _predictTimeout,
    );

    return _parseResponse(response);
  }

  // =================================================
  // 🧹 CLEANUP
  // =================================================
  static void dispose() {
    _client.close();
  }
}

// =================================================
// 🚨 CUSTOM API EXCEPTION
// =================================================
class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}
