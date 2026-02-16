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
  // ⏱️ TIMEOUTS (UPDATED FOR RENDER COLD START)
  // =================================================
  static const Duration _defaultTimeout = Duration(seconds: 60);
  static const Duration _predictTimeout = Duration(seconds: 90);

  // =================================================
  // 🔁 HTTP CLIENT
  // =================================================
  static final http.Client _client = http.Client();

  // =================================================
  // 🔒 REFRESH LOCK (SINGLE FLIGHT)
  // =================================================
  static Future<String?>? _refreshFuture;

  // =================================================
  // 🔥 SERVER WARM UP (CALL ON APP START)
  // =================================================
  static Future<void> warmUpServer() async {
    try {
      await _client
          .get(Uri.parse(baseUrl))
          .timeout(_defaultTimeout);
      print("✅ Server Warmed Up");
    } catch (e) {
      print("⚠️ Warm-up failed: $e");
    }
  }

  // =================================================
  // 🧾 HEADERS BUILDER
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
  // 🛡️ SAFE REQUEST HANDLER (AUTO REFRESH + BETTER ERRORS)
  // =================================================
  static Future<http.Response> _safeRequest(
    Future<http.Response> Function() request, {
    Duration? timeout,
    bool retrying = false,
  }) async {
    try {
      final response =
          await request().timeout(timeout ?? _defaultTimeout);

      // ✅ Success
      if (response.statusCode != 401) {
        return response;
      }

      // ❌ If already retried → logout
      if (retrying) {
        await AuthService.logout();
        throw Exception("SESSION_EXPIRED");
      }

      // 🔁 Try refresh
      final newToken = await _refreshTokenQueued();
      if (newToken == null) {
        await AuthService.logout();
        throw Exception("SESSION_EXPIRED");
      }

      // 🔁 Retry once
      return await _safeRequest(
        request,
        timeout: timeout,
        retrying: true,
      );
    } on TimeoutException {
      throw Exception(
          "Server is waking up. Please wait a moment and try again.");
    } on SocketException {
      throw Exception("No internet connection.");
    } on FormatException {
      throw Exception("Invalid server response.");
    } catch (e) {
      rethrow;
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
      final response = await _client
          .post(
            Uri.parse("$baseUrl/refresh"),
            headers: const {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode(
              {"refresh_token": refreshToken},
            ),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body);

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
  // 🌐 PUBLIC GET
  // =================================================
  static Future<http.Response> getPublic(
      String endpoint) async {
    try {
      return await _client
          .get(
            Uri.parse("$baseUrl$endpoint"),
            headers: await _headers(),
          )
          .timeout(_defaultTimeout);
    } on TimeoutException {
      throw Exception(
          "Server is waking up. Please try again.");
    } on SocketException {
      throw Exception("No internet connection.");
    }
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
  // 🌐 PUBLIC POST (JSON)
  // =================================================
  static Future<http.Response> postPublic(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _client
          .post(
            Uri.parse("$baseUrl$endpoint"),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(_defaultTimeout);
    } on TimeoutException {
      throw Exception(
          "Server is waking up. Please try again.");
    } on SocketException {
      throw Exception("No internet connection.");
    }
  }

  // =================================================
  // 🔐 AUTH POST (JSON)
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
  // 🔐 AUTH PUT (JSON)
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
  // 🔑 LOGIN (FORM – OAuth2)
  // =================================================
  static Future<http.Response> postForm(
    String endpoint,
    Map<String, String> body,
  ) async {
    try {
      return await _client
          .post(
            Uri.parse("$baseUrl$endpoint"),
            headers: await _headers(
              json: false,
              isForm: true,
            ),
            body: body,
          )
          .timeout(_defaultTimeout);
    } on TimeoutException {
      throw Exception(
          "Server is waking up. Please try again.");
    } on SocketException {
      throw Exception("No internet connection.");
    }
  }

  // =================================================
  // 🧠 PREDICT (LONG RUNNING)
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
