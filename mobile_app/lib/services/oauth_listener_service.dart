import 'dart:async';
import 'package:uni_links/uni_links.dart';
import 'package:flutter/foundation.dart';

class OAuthListenerService {
  static StreamSubscription? _sub;
  static bool _isListening = false;

  // =====================================================
  // START LISTENING (SAFE)
  // =====================================================
  static Future<void> startListening(
    void Function(String platform) onSuccess,
    void Function(String platform, String? error)? onError,
  ) async {
    if (_isListening) return;

    _isListening = true;

    try {
      // 🔥 Handle cold start (app opened from OAuth redirect)
      final initialUri = await getInitialUri();
      if (initialUri != null) {
        _handleUri(initialUri, onSuccess, onError);
      }

      // 🔥 Listen to incoming links while app running
      _sub = uriLinkStream.listen(
        (Uri? uri) {
          if (uri != null) {
            _handleUri(uri, onSuccess, onError);
          }
        },
        onError: (err) {
          debugPrint("Deep link error: $err");
        },
      );
    } catch (e) {
      debugPrint("Failed to start OAuth listener: $e");
    }
  }

  // =====================================================
  // HANDLE URI
  // =====================================================
  static void _handleUri(
    Uri uri,
    void Function(String platform) onSuccess,
    void Function(String platform, String? error)? onError,
  ) {
    if (uri.scheme != "myapp" ||
        uri.host != "oauth-success") {
      return;
    }

    final platform = uri.queryParameters["platform"];
    final status = uri.queryParameters["status"];
    final error = uri.queryParameters["error"];

    if (platform == null) return;

    if (status == "success") {
      onSuccess(platform);
    } else {
      if (onError != null) {
        onError(platform, error);
      }
    }
  }

  // =====================================================
  // DISPOSE
  // =====================================================
  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _isListening = false;
  }
}
