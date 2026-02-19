import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // 🔥 Light vibration on app start
    HapticFeedback.lightImpact();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _bootstrap();
  }

  // =================================================
  // 🚀 SAFE APP STARTUP FLOW
  // =================================================
  Future<void> _bootstrap() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1700));

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
            // ❌ Failed biometric → fallback login
            _navigate("/login");
            return;
          }
        }
      }

      // ✅ All checks passed → Home
      _navigate("/home");
    } catch (e) {
      // 🛡 If anything unexpected happens → Safe fallback
      _navigate("/login");
    }
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
  // 🎨 PREMIUM UI
  // =================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
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

                  SizedBox(height: 30),

                  // 🔥 Premium Loader
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
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
