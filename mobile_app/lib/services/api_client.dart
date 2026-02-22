import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'auth_service.dart';

class ApiClient {
  // =================================================
  // 🌍 ENV CONFIG
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

  static final http.Client _client = http.Client();

  static Future<String?>? _refreshFuture;

  static Function()? onSessionExpired;

  // =================================================
  // 🔥 SERVER WARMUP
  // =================================================
  static Future<void> warmUpServer() async {
    try {
      await _client
          .get(Uri.parse(baseUrl))
          .timeout(_defaultTimeout);
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

      if (token == null || token.isEmpty) {
        throw ApiException(
            "No access token found. Please login again.");
      }

      headers["Authorization"] = "Bearer $token";
    }

    return headers;
  }

  // =================================================
  // 🛡 SAFE REQUEST (AUTO TOKEN REFRESH)
  // =================================================
  static Future<http.Response> _safeRequest(
    Future<http.Response> Function() request, {
    bool retrying = false,
  }) async {
    try {
      final response =
          await request().timeout(_defaultTimeout);

      if (response.statusCode != 401) {
        return response;
      }

      if (retrying) {
        await _handleSessionExpired();
        throw ApiException(
            "Session expired. Please login again.");
      }

      final newToken = await _refreshTokenQueued();

      if (newToken == null) {
        await _handleSessionExpired();
        throw ApiException(
            "Session expired. Please login again.");
      }

      return await _safeRequest(
        request,
        retrying: true,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException("Network error occurred.");
    }
  }

  // =================================================
  // 🔁 TOKEN REFRESH
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

      if (response.statusCode != 200) {
        return null;
      }

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

  static Future<void> _handleSessionExpired() async {
    await AuthService.logout();
    onSessionExpired?.call();
  }

  // =================================================
  // 🔄 RESPONSE PARSER
  // =================================================
  static dynamic _parseResponse(http.Response response) {
    if (response.body.isEmpty) {
      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        return null;
      }
      throw ApiException("Empty server response.");
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw ApiException("Invalid JSON from server.");
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return decoded;
    }

    final message =
        decoded["detail"] ??
        decoded["message"] ??
        "Request failed (${response.statusCode})";

    throw ApiException(message);
  }

  // =================================================
  // 🌐 PUBLIC (NO AUTH) METHODS
  // =================================================
  static Future<dynamic> getPublic(String endpoint) async {
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
  // 🖼 MULTIPART UPLOAD (WEB + MOBILE SAFE)
  // =================================================
  static Future<dynamic> multipart(
    String endpoint, {
    required dynamic file,
    required String fieldName,
  }) async {
    final token = await AuthService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw ApiException("No access token found.");
    }

    final uri = Uri.parse("$baseUrl$endpoint");
    final request = http.MultipartRequest("POST", uri);

    request.headers["Authorization"] = "Bearer $token";

    if (kIsWeb) {
      final XFile xFile = file;
      final bytes = await xFile.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: xFile.name,
        ),
      );
    } else {
      final File mobileFile = file;

      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          mobileFile.path,
        ),
      );
    }

    final streamedResponse = await request.send();
    final response =
        await http.Response.fromStream(streamedResponse);

    return _parseResponse(response);
  }

  // =================================================
  // 🧹 CLEANUP
  // =================================================
  static void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}