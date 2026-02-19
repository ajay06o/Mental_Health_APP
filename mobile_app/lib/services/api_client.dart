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
      "https://mental-health-app-zpng.onrender.com/health";

  static const Duration _defaultTimeout = Duration(seconds: 60);
  static const Duration _predictTimeout = Duration(seconds: 90);

  static final http.Client _client = http.Client();

  static Future<String?>? _refreshFuture;

  // =================================================
  // 🔥 SERVER WARM UP
  // =================================================
  static Future<void> warmUpServer() async {
    try {
      await _client.get(Uri.parse(baseUrl)).timeout(_defaultTimeout);
    } catch (_) {}
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
  // 🛡 SAFE REQUEST
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
        await AuthService.logout();
        throw Exception("Session expired. Please login again.");
      }

      final newToken = await _refreshTokenQueued();
      if (newToken == null) {
        await AuthService.logout();
        throw Exception("Session expired. Please login again.");
      }

      return await _safeRequest(
        request,
        timeout: timeout,
        retrying: true,
      );
    } on TimeoutException {
      throw Exception(
          "Server is waking up. Please wait a moment.");
    } on SocketException {
      throw Exception("No internet connection.");
    } on FormatException {
      throw Exception("Invalid server response.");
    }
  }

  // =================================================
  // 🔁 REFRESH TOKEN
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
        body: jsonEncode(
          {"refresh_token": refreshToken},
        ),
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
  // 🔄 RESPONSE PARSER
  // =================================================
  static dynamic _parseResponse(http.Response response) {
    if (response.body.isEmpty) return null;

    final decoded = jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return decoded;
    }

    throw Exception(
      decoded["detail"] ?? "Something went wrong",
    );
  }

  // =================================================
  // 🌐 PUBLIC GET
  // =================================================
  static Future<dynamic> getPublic(String endpoint) async {
    final response = await _client.get(
      Uri.parse("$baseUrl$endpoint"),
      headers: await _headers(),
    );

    return _parseResponse(response);
  }

  // =================================================
  // 🌐 PUBLIC POST
  // =================================================
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
  // 🔐 AUTH GET
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

  // =================================================
  // 🔐 AUTH POST
  // =================================================
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

  // =================================================
  // 🔐 AUTH PUT
  // =================================================
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

  // =================================================
  // 🔐 AUTH DELETE (NEW)
  // =================================================
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
  // 🔑 LOGIN FORM
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
  // CLEANUP
  // =================================================
  static void dispose() {
    _client.close();
  }
}
