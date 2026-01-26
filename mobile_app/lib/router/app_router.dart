import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: "/splash",

  // ✅ SINGLE SOURCE OF TRUTH FOR AUTH
  redirect: (context, state) async {
    final loggedIn = await AuthService.isLoggedIn();
    final location = state.matchedLocation;

    // Allow splash always
    if (location == "/splash") return null;

    final isAuthRoute =
        location == "/login" || location == "/register";

    // 🔐 Not logged in → force login
    if (!loggedIn && !isAuthRoute) {
      return "/login";
    }

    // 🔓 Logged in → block auth pages
    if (loggedIn && isAuthRoute) {
      return "/home";
    }

    return null;
  },

  routes: [
    // ================= SPLASH =================
    GoRoute(
      path: "/splash",
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const SplashScreen(),
      ),
    ),

    // ================= LOGIN =================
    GoRoute(
      path: "/login",
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const LoginScreen(),
      ),
    ),

    // ================= REGISTER =================
    GoRoute(
      path: "/register",
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const RegisterScreen(),
      ),
    ),

    // ================= HOME =================
    GoRoute(
      path: "/home",
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const MainNavigationScreen(),
      ),
    ),

    // ================= SETTINGS =================
    GoRoute(
      path: "/settings",
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const SettingsScreen(),
      ),
    ),
  ],
);
