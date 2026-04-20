import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // ✅ Added
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';

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

    // ✅ FIX: Disable vibration on Web
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }

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

    // 🔥 STEP 1: Ensure backend is REALLY ready
    bool serverReady = false;

    for (int i = 0; i < 5; i++) {
      try {
        await ApiClient.warmUpServer();
        serverReady = true;
        break;
      } catch (e) {
        print("Retry ${i + 1}: Server not ready");
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!serverReady) {
      print("⚠️ Server still not ready, continuing...");
    }

    // 🔐 STEP 2: Initialize auth
    await AuthService.init();

    if (!mounted || _navigated) return;

    final loggedIn = await AuthService.isLoggedIn();

    // 🔐 Not logged in → Login
    if (!loggedIn) {
      _navigate("/login");
      return;
    }

    // 🔁 Logged in → biometric
    final rememberMeEnabled =
        await AuthService.isRememberMeEnabled();

    if (rememberMeEnabled && !kIsWeb) {
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

    // ✅ Success → Home
    _navigate("/home");

  } catch (e) {
    print("❌ Splash error: $e");
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
