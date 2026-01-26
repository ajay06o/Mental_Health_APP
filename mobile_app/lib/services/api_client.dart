import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  // ✅ Render backend (single source of truth)
  static const String baseUrl =
      "https://mental-health-app-1-rv33.onrender.com";

  static const Duration _timeout = Duration(seconds: 15);

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
  // GET
  // =========================
  static Future<http.Response> get(String endpoint) async {
    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl$endpoint"),
            headers: await _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode == 401) {
        await AuthService.logout();
      }

      return response;
    } on SocketException {
      throw Exception("No internet connection");
    }
  }

  // =========================
  // POST JSON
  // =========================
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl$endpoint"),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 401) {
        await AuthService.logout();
      }

      return response;
    } on SocketException {
      throw Exception("No internet connection");
    }
  }

  // =========================
  // POST FORM (LOGIN)
  // =========================
  static Future<http.Response> postForm(
    String endpoint,
    Map<String, String> body,
  ) async {
    try {
      final response = await http
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

      return response;
    } on SocketException {
      throw Exception("No internet connection");
    }
  }

  // =========================
  // PUT JSON ✅ (PROFILE UPDATE FIX)
  // =========================
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .put(
            Uri.parse("$baseUrl$endpoint"),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 401) {
        await AuthService.logout();
      }

      return response;
    } on SocketException {
      throw Exception("No internet connection");
    }
  }
}
