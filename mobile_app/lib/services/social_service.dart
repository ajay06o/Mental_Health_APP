import 'api_client.dart';

class SocialService {
  // =====================================================
  // GET CONNECTION STATUS
  // =====================================================
  static Future<Map<String, bool>> getConnections() async {
    try {
      final response = await ApiClient.get("/social/connected");

      if (response == null) return {};

      final List<dynamic> connected = List<dynamic>.from(response);

      return {
        "instagram": connected.contains("instagram"),
        "twitter": connected.contains("twitter"),
        "facebook": connected.contains("facebook"),
        "linkedin": connected.contains("linkedin"),
      };
    } catch (e) {
      throw Exception("Failed to fetch connections");
    }
  }

  // =====================================================
  // START OAUTH FLOW (Returns Redirect URL)
  // =====================================================
  static Future<String> getOAuthUrl(String platform) async {
    try {
      final response = await ApiClient.get(
        "/social/oauth-url/${platform.toLowerCase()}",
      );

      return response["url"];
    } catch (_) {
      throw Exception("Failed to initiate OAuth for $platform");
    }
  }

  // =====================================================
  // CONNECT PLATFORM (Final Step After OAuth)
  // =====================================================
  static Future<void> connect(String platform) async {
    try {
      await ApiClient.post(
        "/social/connect",
        {"platform": platform.toLowerCase()},
      );
    } catch (_) {
      throw Exception("Failed to connect $platform");
    }
  }

  // =====================================================
  // DISCONNECT PLATFORM
  // =====================================================
  static Future<void> disconnect(String platform) async {
    try {
      await ApiClient.delete(
        "/social/disconnect/${platform.toLowerCase()}",
      );
    } catch (_) {
      throw Exception("Failed to disconnect $platform");
    }
  }

  // =====================================================
  // MANUAL ANALYZE
  // =====================================================
  static Future<Map<String, dynamic>> analyze() async {
    try {
      final response =
          await ApiClient.post("/social/analyze", {});

      if (response == null) return {};

      return Map<String, dynamic>.from(response);
    } catch (_) {
      throw Exception("Failed to analyze social accounts");
    }
  }

  // =====================================================
  // BACKGROUND SYNC (WORKMANAGER CALL)
  // =====================================================
  static Future<void> backgroundSync() async {
    try {
      await ApiClient.post("/social/background-sync", {});
    } catch (_) {
      throw Exception("Background sync failed");
    }
  }

  // =====================================================
  // GET INCREMENTAL SYNC STATUS
  // =====================================================
  static Future<Map<String, dynamic>> getSyncStatus(
      String platform) async {
    try {
      final response = await ApiClient.get(
        "/social/sync-status/${platform.toLowerCase()}",
      );

      if (response == null) return {};

      return Map<String, dynamic>.from(response);
    } catch (_) {
      throw Exception("Failed to fetch sync status");
    }
  }

  // =====================================================
  // GET SYNC LOG HISTORY
  // =====================================================
  static Future<List<Map<String, dynamic>>> getSyncLogs() async {
    try {
      final response = await ApiClient.get("/social/sync-logs");

      if (response == null) return [];

      final List<dynamic> logs = List<dynamic>.from(response);

      return logs
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      throw Exception("Failed to fetch sync logs");
    }
  }

  // =====================================================
  // RETRY FAILED SYNC
  // =====================================================
  static Future<void> retrySync(String platform) async {
    try {
      await ApiClient.post(
        "/social/retry-sync",
        {"platform": platform.toLowerCase()},
      );
    } catch (_) {
      throw Exception("Retry sync failed for $platform");
    }
  }
}
