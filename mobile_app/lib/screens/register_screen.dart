import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../widgets/app_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _showSuccess = false;
  bool _rememberMe = true;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late final AnimationController _successController;
  late final Animation<double> _scaleAnimation;

  // =================================================
  // INIT
  // =================================================
  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _successController.dispose();
    super.dispose();
  }

  // =================================================
  // REGISTER FLOW
  // =================================================
  Future<void> _handleRegister() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email =
        _emailController.text.trim().toLowerCase();
    final password =
        _passwordController.text.trim();

    try {
      final success =
          await AuthService.registerAndAutoLogin(
        email,
        password,
      );

      if (!mounted) return;

      if (!success) {
        _showError(
            "Unable to create account. Please try again.");
        return;
      }

      await AuthService.saveLoginCredentials(
        email: email,
        password: password,
        rememberMe: _rememberMe,
      );

      HapticFeedback.mediumImpact();

      setState(() => _showSuccess = true);
      _successController.forward();

      await Future.delayed(
          const Duration(milliseconds: 1200));

      if (!mounted) return;

      context.go("/home");
    } catch (e) {
      if (mounted) {
        _showError(
            "Something went wrong. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  // =================================================
  // UI
  // =================================================
  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF1E1E2C),
                        Color(0xFF2A2A40),
                      ],
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFF6366F1),
                        Color(0xFF8B5CF6),
                      ],
                    ),
            ),
          ),
          Center(
            child: AnimatedSwitcher(
              duration:
                  const Duration(milliseconds: 400),
              child: _showSuccess
                  ? _successView()
                  : _formCard(),
            ),
          ),
          if (_isLoading) _loadingOverlay(),
        ],
      ),
    );
  }

  // =================================================
  // SUCCESS VIEW
  // =================================================
  Widget _successView() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircleAvatar(
            radius: 55,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 70,
            ),
          ),
          SizedBox(height: 22),
          Text(
            "Account Created 🎉",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Welcome to your wellness journey 🌱",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // =================================================
  // FORM CARD
  // =================================================
  Widget _formCard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 20,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Hero(
                  tag: "auth-hero",
                  child: AppLogo(size: 64),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                _emailField(),
                const SizedBox(height: 16),
                _passwordField(),
                const SizedBox(height: 16),
                _confirmField(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() =>
                              _rememberMe = v ?? true),
                    ),
                    const Text("Remember me"),
                  ],
                ),
                const SizedBox(height: 20),
                _registerButton(),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () =>
                      context.go("/login"),
                  child: const Text(
                      "Already have an account? Login"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =================================================
  // FIELDS
  // =================================================
  Widget _emailField() => TextFormField(
        controller: _emailController,
        keyboardType:
            TextInputType.emailAddress,
        validator: (v) {
          if (v == null || v.isEmpty) {
            return "Email required";
          }
          if (!RegExp(
                  r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
              .hasMatch(v)) {
            return "Enter valid email";
          }
          return null;
        },
        decoration: _inputDecoration(
          label: "Email",
          icon: Icons.email_outlined,
        ),
      );

  Widget _passwordField() => TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        validator: (v) {
          if (v == null || v.length < 6) {
            return "Minimum 6 characters";
          }
          return null;
        },
        decoration: _inputDecoration(
          label: "Password",
          icon: Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(_obscurePassword
                ? Icons.visibility_off
                : Icons.visibility),
            onPressed: () => setState(
                () => _obscurePassword =
                    !_obscurePassword),
          ),
        ),
      );

  Widget _confirmField() => TextFormField(
        controller: _confirmController,
        obscureText: _obscureConfirm,
        validator: (v) =>
            v == _passwordController.text
                ? null
                : "Passwords do not match",
        decoration: _inputDecoration(
          label: "Confirm Password",
          icon: Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(_obscureConfirm
                ? Icons.visibility_off
                : Icons.visibility),
            onPressed: () => setState(
                () => _obscureConfirm =
                    !_obscureConfirm),
          ),
        ),
      );

  Widget _registerButton() => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed:
              _isLoading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            "Create Account",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
        ),
      );

  Widget _loadingOverlay() => Container(
        color: Colors.black.withOpacity(0.3),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
      ),
    );
  }
}

