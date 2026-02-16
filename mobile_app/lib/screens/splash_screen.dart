import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _bootstrap();
  }

  // =================================================
  // 🚀 APP STARTUP FLOW (SAFE & PRODUCTION READY)
  // =================================================
  Future<void> _bootstrap() async {
    // Allow animation to complete smoothly
    await Future.delayed(const Duration(milliseconds: 1800));

    // Initialize auth state
    await AuthService.init();

    if (!mounted || _navigated) return;

    final loggedIn = await AuthService.isLoggedIn();

    // 🔐 Not logged in → Login
    if (!loggedIn) {
      _navigate("/login");
      return;
    }

    // 🔁 Logged in → check Remember Me
    final rememberMeEnabled =
        await AuthService.isRememberMeEnabled();

    if (rememberMeEnabled) {
      final canBiometric =
          await BiometricService.canAuthenticate();

      if (canBiometric) {
        final authenticated =
            await BiometricService.authenticate();

        if (!authenticated) {
          _navigate("/login");
          return;
        }
      }
    }

    // ✅ All checks passed → Home
    _navigate("/home");
  }

  void _navigate(String route) {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(route);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // =================================================
  // 🎨 UI
  // =================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6366F1), // Indigo
              Color(0xFF8B5CF6), // Soft Purple
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  // ✅ CENTRALIZED BRAND LOGO
                  AppLogo(size: 96),

                  SizedBox(height: 24),

                  Text(
                    "Mental Health",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),

                  SizedBox(height: 10),

                  Text(
                    "Your mental wellness companion 🌱",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

