import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ IMPORTANT
import 'package:workmanager/workmanager.dart';

import 'router/app_router.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'services/social_service.dart';
import 'services/oauth_listener_service.dart';

/// ==========================================
/// 🔄 BACKGROUND SYNC CALLBACK (MOBILE ONLY)
/// ==========================================
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await SocialService.backgroundSync();
      return Future.value(true);
    } catch (e) {
      debugPrint("Background sync error: $e");
      return Future.value(false);
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 🔐 Initialize authentication
    await AuthService.init();

    // 🌐 Warm backend
    await ApiClient.warmUpServer();

    // 🔄 Initialize WorkManager (ONLY mobile)
    if (!kIsWeb) {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );
    }
  } catch (e) {
    debugPrint("Startup error: $e");
  }

  // 🔁 Global Session Expiry Handler
  ApiClient.onSessionExpired = () {
    appRouter.go("/login");
  };

  // 🔗 OAuth Listener (ONLY mobile)
  if (!kIsWeb) {
    OAuthListenerService.startListening(
      (platform) {
        debugPrint("OAuth success from $platform");
      },
      (platform, error) {
        debugPrint("OAuth failed for $platform: $error");
      },
    );
  }

  runApp(const MentalHealthApp());
}

class MentalHealthApp extends StatelessWidget {
  const MentalHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "Mental Health AI",
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,

      // ======================================
      // 🎨 LIGHT THEME
      // ======================================
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FF),
        cardTheme: CardTheme(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),

      // ======================================
      // 🌙 DARK THEME
      // ======================================
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardTheme(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),

      themeMode: ThemeMode.system,
    );
  }
}
