import 'api_client.dart';

class SocialService {
  // ==============================
  // GET CONNECTED ACCOUNTS
  // ==============================
  Future<List<dynamic>> getConnected() async {
    try {
      final response = await ApiClient.get("/social/connected");

      if (response == null) return [];

      return List<dynamic>.from(response);
    } catch (_) {
      throw Exception("Failed to fetch connected accounts");
    }
  }

  // ==============================
  // CONNECT PLATFORM
  // ==============================
  Future<void> connect(
    String platform,
    String accessToken,
  ) async {
    if (accessToken.trim().isEmpty) {
      throw Exception("Access token cannot be empty");
    }

    try {
      await ApiClient.post(
        "/social/connect",
        {
          "platform": platform.toLowerCase(),
          "access_token": accessToken.trim(),
        },
      );
    } catch (_) {
      throw Exception("Failed to connect platform");
    }
  }

  // ==============================
  // DISCONNECT PLATFORM
  // ==============================
  Future<void> disconnect(String platform) async {
    try {
      await ApiClient.delete(
        "/social/disconnect/${platform.toLowerCase()}",
      );
    } catch (_) {
      throw Exception("Failed to disconnect platform");
    }
  }

  // ==============================
  // ANALYZE CONNECTED ACCOUNTS
  // ==============================
  Future<Map<String, dynamic>> analyze() async {
    try {
      final response = await ApiClient.post(
        "/social/analyze",
        {}, // required empty body
      );

      if (response == null) {
        return {};
      }

      return Map<String, dynamic>.from(response);
    } catch (_) {
      throw Exception("Failed to analyze social accounts");
    }
  }
}
