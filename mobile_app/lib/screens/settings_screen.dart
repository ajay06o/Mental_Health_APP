import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {

  final LocalAuthentication _auth = LocalAuthentication();

  bool isBiometricEnabled = false;
  bool _isAuthenticating = false;
  bool notificationsEnabled = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ✅ Animated Logo Controller
  late AnimationController _logoController;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _loadPreferences();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    _fadeController.forward();

    // ✅ Logo floating animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _logoAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeInOut,
      ),
    );

    _logoController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      isBiometricEnabled =
          prefs.getBool('biometric_enabled') ?? false;
      notificationsEnabled =
          prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    HapticFeedback.lightImpact();

    if (_isAuthenticating) return;

    try {
      setState(() => _isAuthenticating = true);

      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheck || !isDeviceSupported) {
        _showMessage("Biometric not supported on this device.");
        return;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to enable biometric login',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('biometric_enabled', value);

        setState(() {
          isBiometricEnabled = value;
        });

        _showMessage(
            "Biometric login ${value ? "enabled" : "disabled"}");
      }

    } catch (_) {
      _showMessage("Authentication failed.");
    } finally {
      setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);

    setState(() {
      notificationsEnabled = value;
    });

    _showMessage(
        "Notifications ${value ? "enabled" : "disabled"}");
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ✅ Animated About Sheet
  void _openAboutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // 🔥 Floating Animated Logo
              AnimatedBuilder(
                animation: _logoAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  height: 90,
                  width: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF6D5DF6),
                        Color(0xFF5B4BE0),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.self_improvement,
                    color: Colors.white,
                    size: 45,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Mental Health App",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "Version 1.0.0",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "MindEase is an AI-powered emotional wellness platform "
                "designed to help you understand and track your mental health journey.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Built with ❤️ using Flutter & FastAPI",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go("/home"),
        ),
        title: const Text(
          "Settings",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF6D5DF6),
                Color(0xFF5B4BE0),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                _buildSectionTitle("Security"),
                _buildCard(
                  child: SwitchListTile(
                    title: const Text(
                      "Biometric Login",
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      "Use fingerprint or Face ID",
                      style: TextStyle(color: Colors.white70),
                    ),
                    value: isBiometricEnabled,
                    activeColor: Colors.white,
                    onChanged: _toggleBiometric,
                  ),
                ),

                const SizedBox(height: 24),

                _buildSectionTitle("Preferences"),
                _buildCard(
                  child: SwitchListTile(
                    title: const Text(
                      "Notifications",
                      style: TextStyle(color: Colors.white),
                    ),
                    value: notificationsEnabled,
                    activeColor: Colors.white,
                    onChanged: _toggleNotifications,
                  ),
                ),

                const SizedBox(height: 24),

                _buildSectionTitle("About"),
                _buildCard(
                  child: ListTile(
                    leading: const Icon(
                      Icons.info,
                      color: Colors.blue,
                    ),
                    title: const Text(
                      "About MindEase",
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      "Version 1.0.0",
                      style: TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.white70,
                    ),
                    onTap: _openAboutSheet,
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: child,
    );
  }
}