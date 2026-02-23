import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/settings_screen.dart';

/// 🔁 Auth Change Notifier (Reactive Routing)
class AuthNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final AuthNotifier authNotifier = AuthNotifier();

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: "/splash",

  debugLogDiagnostics: true, // ✅ Safe improvement

  refreshListenable: authNotifier,

  redirect: (context, state) {
    final location = state.matchedLocation;

    // Always allow splash
    if (location == "/splash") {
      return null;
    }

    final loggedIn = AuthService.cachedLoginState;
    final isAuthRoute =
        location == "/login" || location == "/register";

    // 🔐 Not logged in → redirect to login
    if (!loggedIn && !isAuthRoute) {
      return "/login";
    }

    // 🔓 Logged in → block auth pages
    if (loggedIn && isAuthRoute) {
      return "/home";
    }

    return null;
  },

  errorBuilder: (context, state) => Scaffold(   // ✅ Prevent crash on bad route
    body: Center(
      child: Text(
        "Page not found",
        style: Theme.of(context).textTheme.titleLarge,
      ),
    ),
  ),

  routes: [
    // ================= SPLASH =================
    GoRoute(
      path: "/splash",
      pageBuilder: (context, state) => _buildPage(
        state,
        const SplashScreen(),
      ),
    ),

    // ================= LOGIN =================
    GoRoute(
      path: "/login",
      pageBuilder: (context, state) => _buildPage(
        state,
        const LoginScreen(),
      ),
    ),

    // ================= REGISTER =================
    GoRoute(
      path: "/register",
      pageBuilder: (context, state) => _buildPage(
        state,
        const RegisterScreen(),
      ),
    ),

    // ================= HOME =================
    GoRoute(
      path: "/home",
      pageBuilder: (context, state) => _buildPage(
        state,
        const MainNavigationScreen(),
      ),
    ),

    // ================= SETTINGS =================
    GoRoute(
      path: "/settings",
      pageBuilder: (context, state) => _buildPage(
        state,
        const SettingsScreen(),
      ),
    ),
  ],
);

/// 🔥 Smooth Fade Transition (Improved timing)
CustomTransitionPage _buildPage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 250), // ✅ smoother feel
    reverseTransitionDuration: const Duration(milliseconds: 200),
    child: child,
    transitionsBuilder:
        (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}