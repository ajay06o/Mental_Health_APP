import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../widgets/app_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _rememberMe = true;

  late AnimationController _bgController;
  late AnimationController _entranceController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

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
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    try {
      final success =
          await AuthService.registerAndAutoLogin(email, password);

      if (!mounted) return;

      if (!success) {
        _showError("Unable to create account.");
        return;
      }

      HapticFeedback.mediumImpact();
      context.go("/home");
    } catch (_) {
      _showError("Something went wrong.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          const AppLogo(size: 60),
                          const SizedBox(height: 20),

                          const Text(
                            "Create Account 🌿",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Start your wellness journey.",
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
                const SizedBox(height: 18),
                _confirmField(),
                const SizedBox(height: 14),
                _rememberRow(),
                const SizedBox(height: 24),
                _registerButton(),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go("/login"),
                  child: const Text(
                    "Already have an account? Login",
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

  Widget _rememberRow() {
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

  Widget _emailField() => TextFormField(
        controller: _emailController,
        style: const TextStyle(color: Colors.black),
        decoration: _inputDecoration("Email", Icons.email_outlined),
      );

  Widget _passwordField() => TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(color: Colors.black),
        validator: (v) =>
            v != null && v.length >= 6
                ? null
                : "Minimum 6 characters",
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

  Widget _confirmField() => TextFormField(
        controller: _confirmController,
        obscureText: _obscureConfirm,
        style: const TextStyle(color: Colors.black),
        validator: (v) =>
            v == _passwordController.text
                ? null
                : "Passwords do not match",
        decoration: _inputDecoration(
          "Confirm Password",
          Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_off
                  : Icons.visibility,
              color: Colors.black54,
            ),
            onPressed: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
      );

  Widget _registerButton() => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6D5DF6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: _isLoading ? null : _handleRegister,
          child: _isLoading
              ? const CircularProgressIndicator(
                  color: Colors.white,
                )
              : const Text(
                  "Create Account",
                  style:
                      TextStyle(fontWeight: FontWeight.w600),
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