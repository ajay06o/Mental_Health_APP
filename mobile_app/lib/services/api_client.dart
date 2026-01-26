import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  // 🔥 SAME BASE URL (SINGLE SOURCE OF TRUTH)
  static const String baseUrl = AuthService.baseUrl;

  static const Duration _timeout = Duration(seconds: 12);

  // =========================
  // GET REQUEST
  // =========================
  static Future<http.Response> get(String endpoint) async {
    final token = await AuthService.getAccessToken();

    final response = await http
        .get(
          Uri.parse("$baseUrl$endpoint"),
          headers: {
            "Content-Type": "application/json",
            if (token != null) "Authorization": "Bearer $token",
          },
        )
        .timeout(_timeout);

    if (response.statusCode == 401) {
      await AuthService.logout();
    }

    return response;
  }

  // =========================
  // POST REQUEST
  // =========================
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await AuthService.getAccessToken();

    final response = await http
        .post(
          Uri.parse("$baseUrl$endpoint"),
          headers: {
            "Content-Type": "application/json",
            if (token != null) "Authorization": "Bearer $token",
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (response.statusCode == 401) {
      await AuthService.logout();
    }

    return response;
  }
}
