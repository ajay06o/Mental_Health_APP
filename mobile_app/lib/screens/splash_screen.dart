import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    // ⏳ Let animation play
    await Future.delayed(const Duration(seconds: 2));

    // 🔐 Check login state
    final loggedIn = await AuthService.isLoggedIn();

    if (!mounted) return;

    if (loggedIn) {
      context.go("/home");
    } else {
      context.go("/login");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _controller,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.psychology, size: 80),
              SizedBox(height: 16),
              Text(
                "Mental Health App",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
