import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../widgets/app_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _showSuccess = false;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // 🔐 REMEMBER ME
  bool _rememberMe = true;

  late final AnimationController _successController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scaleAnimation =
        CurvedAnimation(parent: _successController, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _successController.dispose();
    super.dispose();
  }

  // =================================================
  // 🆕 REGISTER + AUTO LOGIN
  // =================================================
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
        _showError("Unable to create account. Please try again.");
        return;
      }

      // 🔐 Save credentials securely (ONLY after success)
      await AuthService.saveLoginCredentials(
        email: email,
        password: password,
        rememberMe: _rememberMe,
      );

      setState(() => _showSuccess = true);

      if (mounted) {
        _successController.forward();
      }

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      context.go("/home");
    } catch (_) {
      if (mounted) {
        _showError("Something went wrong. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
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
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: _showSuccess ? _successView() : _registerForm(),
          ),
        ),
      ),
    );
  }

  // =================================================
  // 🎉 SUCCESS VIEW
  // =================================================
  Widget _successView() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
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
  // 📝 REGISTER FORM
  // =================================================
  Widget _registerForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 20,
        color: Colors.white.withOpacity(0.96),
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Hero(
                  tag: "auth-hero",
                  child: AppLogo(size: 64),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Start your mental wellness journey",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                _emailField(),
                const SizedBox(height: 18),
                _passwordField(),
                const SizedBox(height: 18),
                _confirmPasswordField(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? true),
                    ),
                    const Text("Remember me"),
                  ],
                ),
                const SizedBox(height: 24),
                _registerButton(),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => context.go("/login"),
                  child: const Text("Already have an account? Login"),
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
        keyboardType: TextInputType.emailAddress,
        validator: (v) =>
            v != null && v.contains("@") ? null : "Enter a valid email",
        decoration: _inputDecoration(
          label: "Email",
          icon: Icons.email_outlined,
        ),
      );

  Widget _passwordField() => TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        validator: (v) =>
            v != null && v.trim().length >= 6
                ? null
                : "Use at least 6 characters",
        decoration: _inputDecoration(
          label: "Password",
          icon: Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off
                  : Icons.visibility,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      );

  Widget _confirmPasswordField() => TextFormField(
        controller: _confirmPasswordController,
        obscureText: _obscureConfirm,
        validator: (v) =>
            v != null &&
                    v.trim() == _passwordController.text.trim()
                ? null
                : "Passwords should match",
        decoration: _inputDecoration(
          label: "Confirm Password",
          icon: Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_off
                  : Icons.visibility,
            ),
            onPressed: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
      );

  Widget _registerButton() => SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.indigo,
          width: 1.8,
        ),
      ),
    );
  }
}
