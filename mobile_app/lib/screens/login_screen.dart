import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController =
      TextEditingController();

  bool _isLoading = false;
  bool _showSuccess = false;
  bool _obscurePassword = true;

  bool _rememberMe = true;
  bool _biometricAvailable = false;

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
      duration:
          const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _loadSavedCredentials();
    _initBiometrics();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _successController.dispose();
    super.dispose();
  }

  // =================================================
  // INIT HELPERS
  // =================================================
  Future<void> _loadSavedCredentials() async {
    final data =
        await AuthService.loadSavedCredentials();

    if (!mounted || data.isEmpty) return;

    _emailController.text =
        data["email"] ?? "";
    _passwordController.text =
        data["password"] ?? "";

    setState(() => _rememberMe = true);
  }

  Future<void> _initBiometrics() async {
    final canUse =
        await BiometricService.canAuthenticate();

    if (mounted) {
      setState(
          () => _biometricAvailable = canUse);
    }
  }

  // =================================================
  // LOGIN HANDLER
  // =================================================
  Future<void> _handleLogin(
      {bool fromBiometric = false}) async {
    if (_isLoading) return;

    if (!fromBiometric) {
      FocusScope.of(context).unfocus();
      if (!_formKey.currentState!
          .validate()) return;
    }

    setState(() => _isLoading = true);

    final email =
        _emailController.text.trim().toLowerCase();
    final password =
        _passwordController.text.trim();

    try {
      final success =
          await AuthService.login(
        email,
        password,
      );

      if (!mounted) return;

      if (!success) {
        _showError(
            "Invalid email or password");
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
          const Duration(milliseconds: 1000));

      if (!mounted) return;

      context.go("/home");
    } catch (_) {
      if (mounted) {
        _showError(
            "Login failed. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // =================================================
  // BIOMETRIC LOGIN
  // =================================================
  Future<void> _handleBiometricLogin() async {
    if (_isLoading) return;

    if (!_rememberMe) {
      _showError(
          "Enable Remember Me to use biometric login");
      return;
    }

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showError(
          "No saved credentials found");
      return;
    }

    final authenticated =
        await BiometricService.authenticate();

    if (!authenticated) return;

    await _handleLogin(
        fromBiometric: true);
  }

  // =================================================
  // ERROR
  // =================================================
  void _showError(String message) {
    if (!mounted) return;

    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              Colors.red.shade600,
        ),
      );
  }

  // =================================================
  // UI
  // =================================================
  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

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
                  const Duration(
                      milliseconds: 400),
              child: _showSuccess
                  ? _successView()
                  : _loginForm(),
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
            backgroundColor:
                Colors.white,
            child: Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 70,
            ),
          ),
          SizedBox(height: 22),
          Text(
            "Welcome Back 👋",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Glad to see you again 🌱",
            style: TextStyle(
                color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // =================================================
  // FORM
  // =================================================
  Widget _loginForm() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(24),
      child: Card(
        elevation: 20,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(28),
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Hero(
                  tag: "auth-hero",
                  child:
                      AppLogo(size: 64),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                _emailField(),
                const SizedBox(height: 16),
                _passwordField(),
                const SizedBox(height: 12),
                _optionsRow(),
                const SizedBox(height: 20),
                _loginButton(),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () =>
                      context.go(
                          "/register"),
                  child: const Text(
                      "Don’t have an account? Create one"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionsRow() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (v) =>
              setState(() =>
                  _rememberMe =
                      v ?? true),
        ),
        const Text("Remember me"),
        const Spacer(),
        if (_biometricAvailable)
          IconButton(
            icon: const Icon(
              Icons.fingerprint,
              size: 32,
              color:
                  Colors.indigo,
            ),
            onPressed: _isLoading
                ? null
                : _handleBiometricLogin,
          ),
      ],
    );
  }

  Widget _emailField() =>
      TextFormField(
        controller:
            _emailController,
        keyboardType:
            TextInputType.emailAddress,
        validator: (v) {
          if (v == null ||
              v.isEmpty) {
            return "Email required";
          }
          if (!RegExp(
                  r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
              .hasMatch(v)) {
            return "Enter valid email";
          }
          return null;
        },
        decoration:
            _inputDecoration(
          label: "Email",
          icon:
              Icons.email_outlined,
        ),
      );

  Widget _passwordField() =>
      TextFormField(
        controller:
            _passwordController,
        obscureText:
            _obscurePassword,
        validator: (v) =>
            v != null &&
                    v.length >= 6
                ? null
                : "Minimum 6 characters",
        decoration:
            _inputDecoration(
          label: "Password",
          icon:
              Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(
                _obscurePassword
                    ? Icons
                        .visibility_off
                    : Icons
                        .visibility),
            onPressed: () =>
                setState(() =>
                    _obscurePassword =
                        !_obscurePassword),
          ),
        ),
      );

  Widget _loginButton() =>
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isLoading
              ? null
              : _handleLogin,
          child: const Text(
            "Login",
            style: TextStyle(
                fontWeight:
                    FontWeight.w600),
          ),
        ),
      );

  Widget _loadingOverlay() =>
      Container(
        color: Colors.black
            .withOpacity(0.3),
        child: const Center(
          child:
              CircularProgressIndicator(),
        ),
      );

  InputDecoration
      _inputDecoration({
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
