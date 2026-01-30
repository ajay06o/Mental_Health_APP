import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  // =================================================
  // 🌍 BACKEND
  // =================================================
  static const String baseUrl =
      "https://mental-health-app-1-rv33.onrender.com";

  // =================================================
  // ⏱️ TIMEOUTS
  // =================================================
  static const Duration _defaultTimeout = Duration(seconds: 12);
  static const Duration _predictTimeout = Duration(seconds: 45);

  // =================================================
  // 🔁 HTTP CLIENT
  // =================================================
  static final http.Client _client = http.Client();

  // =================================================
  // 🔒 REFRESH LOCK
  // =================================================
  static Future<String?>? _refreshFuture;

  // =================================================
  // 🧾 HEADERS (SAFE & FLEXIBLE)
  // =================================================
  static Future<Map<String, String>> _headers({
    bool json = true,
    bool withAuth = false,
    bool isForm = false,
  }) async {
    final headers = <String, String>{
      "Accept": "application/json",
    };

    if (json) headers["Content-Type"] = "application/json";
    if (isForm) headers["Content-Type"] = "application/x-www-form-urlencoded";

    if (withAuth) {
      final token = await AuthService.getAccessToken();
      if (token != null) {
        headers["Authorization"] = "Bearer $token";
      }
    }

    return headers;
  }

  // =================================================
  // 🛡️ SAFE REQUEST HANDLER (AUTO REFRESH)
  // =================================================
  static Future<http.Response> _safeRequest(
    Future<http.Response> Function() request, {
    Duration? timeout,
  }) async {
    try {
      final response =
          await request().timeout(timeout ?? _defaultTimeout);

      if (response.statusCode != 401) {
        return response;
      }

      // 🔁 TRY REFRESH ONCE
      final token = await _refreshTokenQueued();
      if (token == null) {
        await AuthService.logout();
        throw Exception("Session expired. Please login again.");
      }

      return await request().timeout(timeout ?? _defaultTimeout);
    } on TimeoutException {
      throw Exception("Request timed out");
    } on SocketException {
      throw Exception("No internet connection");
    } on FormatException {
      throw Exception("Invalid server response");
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
    final refreshToken = await AuthService.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final response = await _client
          .post(
            Uri.parse("$baseUrl/refresh"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"refresh_token": refreshToken}),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final newToken = data["access_token"];

      if (newToken == null) return null;

      await AuthService.saveAccessToken(newToken);
      return newToken;
    } catch (_) {
      return null;
    }
  }

  // =================================================
  // 🌐 PUBLIC GET
  // =================================================
  static Future<http.Response> getPublic(String endpoint) async {
    return _client
        .get(
          Uri.parse("$baseUrl$endpoint"),
          headers: await _headers(),
        )
        .timeout(_defaultTimeout);
  }

  // =================================================
  // 🔐 AUTH GET
  // =================================================
  static Future<http.Response> get(String endpoint) {
    return _safeRequest(() async {
      return _client.get(
        Uri.parse("$baseUrl$endpoint"),
        headers: await _headers(withAuth: true),
      );
    });
  }

  // =================================================
  // 🌐 PUBLIC POST
  // =================================================
  static Future<http.Response> postPublic(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return _client
        .post(
          Uri.parse("$baseUrl$endpoint"),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(_defaultTimeout);
  }

  // =================================================
  // 🔐 AUTH POST
  // =================================================
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) {
    return _safeRequest(() async {
      return _client.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: await _headers(withAuth: true),
        body: jsonEncode(body),
      );
    });
  }

  // =================================================
  // 🔐 AUTH PUT ✅ (FIX ADDED)
  // =================================================
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) {
    return _safeRequest(() async {
      return _client.put(
        Uri.parse("$baseUrl$endpoint"),
        headers: await _headers(withAuth: true),
        body: jsonEncode(body),
      );
    });
  }

  // =================================================
  // 🔑 LOGIN (FORM)
  // =================================================
  static Future<http.Response> postForm(
    String endpoint,
    Map<String, String> body,
  ) async {
    return _client
        .post(
          Uri.parse("$baseUrl$endpoint"),
          headers: await _headers(
            json: false,
            withAuth: false,
            isForm: true,
          ),
          body: body,
        )
        .timeout(_defaultTimeout);
  }

  // =================================================
  // 🧠 PREDICT
  // =================================================
  static Future<http.Response> predict(
    Map<String, dynamic> body,
  ) {
    return _safeRequest(
      () async {
        return _client.post(
          Uri.parse("$baseUrl/predict"),
          headers: await _headers(withAuth: true),
          body: jsonEncode(body),
        );
      },
      timeout: _predictTimeout,
    );
  }

  // =================================================
  // CLEANUP
  // =================================================
  static void dispose() {
    _client.close();
  }
}
