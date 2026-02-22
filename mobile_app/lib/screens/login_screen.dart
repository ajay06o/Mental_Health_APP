import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _biometricAvailable = false;

  late AnimationController _bgController;
  late AnimationController _entranceController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _loadSavedCredentials();
    _initBiometrics();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entranceController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final data = await AuthService.loadSavedCredentials();
    if (!mounted || data.isEmpty) return;

    _emailController.text = data["email"] ?? "";
    _passwordController.text = data["password"] ?? "";
  }

  Future<void> _initBiometrics() async {
    final canUse = await BiometricService.canAuthenticate();
    if (mounted) setState(() => _biometricAvailable = canUse);
  }

  Future<void> _handleLogin({bool fromBiometric = false}) async {
    if (_isLoading) return;

    if (!fromBiometric) {
      FocusScope.of(context).unfocus();
      if (!_formKey.currentState!.validate()) return;
    }

    setState(() => _isLoading = true);

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    try {
      final success = await AuthService.login(email, password);
      if (!mounted) return;

      if (!success) {
        _showError("Invalid email or password");
        return;
      }

      HapticFeedback.mediumImpact();
      context.go("/home");
    } catch (_) {
      _showError("Login failed. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBiometricLogin() async {
    final authenticated = await BiometricService.authenticate();
    if (authenticated) {
      await _handleLogin(fromBiometric: true);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (_, __) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(
                  -1 + _bgController.value * 2,
                  -1,
                ),
                end: Alignment(
                  1,
                  1 - _bgController.value * 2,
                ),
                colors: const [
                  Color(0xFF7A6FF0),
                  Color(0xFF5C9EFF),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          const AppLogo(size: 60),
                          const SizedBox(height: 20),

                          const Text(
                            "Welcome Back 🌿",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Your digital well-being starts here.",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white70,
                            ),
                          ),

                          const SizedBox(height: 40),

                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 420),
                            child: _glassCard(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _glassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _emailField(),
                const SizedBox(height: 18),
                _passwordField(),
                const SizedBox(height: 12),
                _optionsRow(),
                const SizedBox(height: 24),
                _loginButton(),
                const SizedBox(height: 16),
                const Text(
                  "🔒 Encrypted & private by design",
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go("/register"),
                  child: const Text(
                    "Create a new account",
                    style: TextStyle(
                      color: Color(0xFF6D5DF6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailField() => TextFormField(
        controller: _emailController,
        style: const TextStyle(color: Colors.black),
        decoration: _inputDecoration("Email", Icons.email_outlined),
      );

  Widget _passwordField() => TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(color: Colors.black),
        decoration: _inputDecoration(
          "Password",
          Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off
                  : Icons.visibility,
              color: Colors.black54,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      );

Widget _optionsRow() {
  return Row(
    children: [
      Checkbox(
        value: _rememberMe,
        activeColor: const Color(0xFF6D5DF6),
        onChanged: (v) =>
            setState(() => _rememberMe = v ?? true),
      ),
      const SizedBox(width: 6),
      const Text(
        "Remember me",
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

  Widget _loginButton() => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6D5DF6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: _isLoading ? null : _handleLogin,
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  "Continue",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
      );

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.black54),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}