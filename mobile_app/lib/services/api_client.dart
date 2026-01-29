import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  // ✅ Single source of truth (Render backend)
  static const String baseUrl =
      "https://mental-health-app-1-rv33.onrender.com";

  static const Duration _timeout = Duration(seconds: 10);

  // ✅ Reusable HTTP client (performance boost)
  static final http.Client _client = http.Client();

  // =========================
  // COMMON HEADERS
  // =========================
  static Future<Map<String, String>> _headers({
    bool json = true,
    bool withAuth = true,
    bool isForm = false,
  }) async {
    final headers = <String, String>{
      "Accept": "application/json",
    };

    if (json) {
      headers["Content-Type"] = "application/json";
    }

    if (isForm) {
      headers["Content-Type"] = "application/x-www-form-urlencoded";
    }

    if (withAuth) {
      final token = await AuthService.getAccessToken();
      if (token != null) {
        headers["Authorization"] = "Bearer $token";
      }
    }

    return headers;
  }

  // =========================
  // SAFE REQUEST HANDLER
  // =========================
  static Future<http.Response> _safeRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(_timeout);

      // 🔁 Auto refresh token on 401
      if (response.statusCode == 401) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          return await request().timeout(_timeout);
        } else {
          await AuthService.logout();
        }
      }

      return response;
    } on SocketException {
      throw Exception("No internet connection");
    } on HttpException {
      throw Exception("Server error");
    } on FormatException {
      throw Exception("Invalid response format");
    }
  }

  // =========================
  // REFRESH TOKEN
  // =========================
  static Future<bool> _refreshToken() async {
    final refreshToken = await AuthService.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _client.post(
        Uri.parse("$baseUrl/refresh"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "refresh_token": refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await AuthService.saveAccessToken(data["access_token"]);
        return true;
      }
    } catch (_) {}

    return false;
  }

  // =========================
  // GET
  // =========================
  static Future<http.Response> get(String endpoint) {
    return _safeRequest(() async {
      return _client.get(
        Uri.parse("$baseUrl$endpoint"),
        headers: await _headers(),
      );
    });
  }

  // =========================
  // POST JSON
  // =========================
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) {
    return _safeRequest(() async {
      return _client.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: await _headers(),
        body: jsonEncode(body),
      );
    });
  }

  // =========================
  // POST FORM (LOGIN)
  // =========================
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
              withAuth: false,
              isForm: true,
            ),
            body: body,
          )
          .timeout(_timeout);
    } on SocketException {
      throw Exception("No internet connection");
    }
  }

  // =========================
  // PUT JSON (PROFILE UPDATE)
  // =========================
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) {
    return _safeRequest(() async {
      return _client.put(
        Uri.parse("$baseUrl$endpoint"),
        headers: await _headers(),
        body: jsonEncode(body),
      );
    });
  }

  // =========================
  // CLEANUP (OPTIONAL)
  // =========================
  static void dispose() {
    _client.close();
  }
}
