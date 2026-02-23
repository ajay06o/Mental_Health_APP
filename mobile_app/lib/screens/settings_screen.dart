import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _loadBiometricPreference();
  }

  Future<void> _loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;
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
        setState(() => _isAuthenticating = false);
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

        _showMessage("Biometric login ${value ? "enabled" : "disabled"}");
      }

    } catch (e) {
      _showMessage("Authentication failed.");
    } finally {
      setState(() => _isAuthenticating = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
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

              // 🔐 Security
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

              // 🔹 Account
              _buildSectionTitle("Account"),
              _buildCard(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.orange),
                      title: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.white70,
                      ),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showLogoutDialog();
                      },
                    ),
                    const Divider(height: 1, color: Colors.white24),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text(
                        "Delete Account",
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.white70,
                      ),
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        _showDeleteDialog();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Center(
                child: Text(
                  "Version 1.0.0",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text("Logout"),
        content: Text("Are you sure you want to logout?"),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text("Delete Account"),
        content: Text("This action is permanent."),
      ),
    );
  }
}