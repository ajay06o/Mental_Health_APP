import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  // ✅ SINGLE SOURCE OF TRUTH (Render Backend)
  static const String baseUrl =
      "https://mental-health-app-1-rv33.onrender.com";

  static const Duration _timeout = Duration(seconds: 15);

  // =========================
  // GET REQUEST
  // =========================
  static Future<http.Response> get(String endpoint) async {
    try {
      final token = await AuthService.getAccessToken();

      final response = await http
          .get(
            Uri.parse("$baseUrl$endpoint"),
            headers: {
              "Accept": "application/json",
              if (token != null) "Authorization": "Bearer $token",
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 401) {
        await AuthService.logout();
      }

      return response;
    } on SocketException {
      throw Exception("No internet connection");
    } on HttpException {
      throw Exception("HTTP error occurred");
    } on FormatException {
      throw Exception("Invalid response format");
    }
  }

  // =========================
  // POST REQUEST (JSON)
  // =========================
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final token = await AuthService.getAccessToken();

      final response = await http
          .post(
            Uri.parse("$baseUrl$endpoint"),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
              if (token != null) "Authorization": "Bearer $token",
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 401) {
        await AuthService.logout();
      }

      return response;
    } on SocketException {
      throw Exception("No internet connection");
    } on HttpException {
      throw Exception("HTTP error occurred");
    } on FormatException {
      throw Exception("Invalid response format");
    }
  }

  // =========================
  // POST FORM (LOGIN ONLY)
  // =========================
  static Future<http.Response> postForm(
    String endpoint,
    Map<String, String> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl$endpoint"),
            headers: {
              "Content-Type": "application/x-www-form-urlencoded",
            },
            body: body,
          )
          .timeout(_timeout);

      return response;
    } on SocketException {
      throw Exception("No internet connection");
    }
  }
}
