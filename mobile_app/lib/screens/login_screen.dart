import 'package:flutter/material.dart';
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
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _showSuccess = false;
  bool _obscurePassword = true;

  bool _rememberMe = true;
  bool _biometricAvailable = false;

  late final AnimationController _successController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation =
        CurvedAnimation(parent: _successController, curve: Curves.elasticOut);

    _loadSavedCredentials();
    _initBiometrics();
  }

  // =================================================
  // INIT HELPERS
  // =================================================
  Future<void> _loadSavedCredentials() async {
    final data = await AuthService.loadSavedCredentials();
    if (!mounted || data.isEmpty) return;

    _emailController.text = data["email"] ?? "";
    _passwordController.text = data["password"] ?? "";
    setState(() => _rememberMe = true);
  }

  Future<void> _initBiometrics() async {
    final canUse = await BiometricService.canAuthenticate();
    if (mounted) {
      setState(() => _biometricAvailable = canUse);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _successController.dispose();
    super.dispose();
  }

  // =================================================
  // LOGIN HANDLER
  // =================================================
  Future<void> _handleLogin({bool fromBiometric = false}) async {
    if (_isLoading) return;

    if (!fromBiometric) {
      FocusScope.of(context).unfocus();
      if (!_formKey.currentState!.validate()) return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (!success) {
        _showError("Invalid email or password");
        return;
      }

      await AuthService.saveLoginCredentials(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        rememberMe: _rememberMe,
      );

      setState(() => _showSuccess = true);
      _successController.forward();

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      context.go("/home");
    } catch (_) {
      _showError("Login failed. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =================================================
  // BIOMETRIC LOGIN
  // =================================================
  Future<void> _handleBiometricLogin() async {
    if (_isLoading) return;

    if (!_rememberMe) {
      _showError("Enable Remember Me to use biometric login");
      return;
    }

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showError("No saved credentials found");
      return;
    }

    final authenticated = await BiometricService.authenticate();
    if (!authenticated) return;

    await _handleLogin(fromBiometric: true);
  }

  // =================================================
  // ERROR HANDLER
  // =================================================
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
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
            child: _showSuccess ? _successView() : _loginForm(),
          ),
        ),
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
            "Welcome Back 👋",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Glad to see you again 🌱",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // =================================================
  // LOGIN FORM
  // =================================================
  Widget _loginForm() {
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
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Continue your wellness journey",
                  style: TextStyle(color: Colors.grey.shade600),
                ),

                const SizedBox(height: 32),

                _emailField(),
                const SizedBox(height: 18),
                _passwordField(),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? true),
                    ),
                    const Text("Remember me"),
                    const Spacer(),
                    if (_biometricAvailable)
                      IconButton(
                        icon: const Icon(
                          Icons.fingerprint,
                          size: 32,
                          color: Colors.indigo,
                        ),
                        onPressed:
                            _isLoading ? null : _handleBiometricLogin,
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                _loginButton(),

                const SizedBox(height: 18),

                TextButton(
                  onPressed: () => context.go("/register"),
                  child: const Text("Don’t have an account? Create one"),
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
        textInputAction: TextInputAction.next,
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
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _handleLogin(),
        validator: (v) =>
            v != null && v.length >= 6 ? null : "Minimum 6 characters",
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

  Widget _loginButton() => SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
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
                  "Login",
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
