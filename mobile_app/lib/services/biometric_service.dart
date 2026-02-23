import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _biometricKey = "biometric_enabled";

  // =========================
  // CHECK BIOMETRIC SUPPORT
  // =========================
  static Future<bool> canAuthenticate() async {
    if (kIsWeb) return false;

    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  // =========================
  // AUTHENTICATE
  // =========================
  static Future<bool> authenticate() async {
    if (kIsWeb) return false;

    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to access MindEase',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // =========================
  // ENABLE / DISABLE BIOMETRIC
  // =========================
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, value);
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricKey) ?? false;
  }

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_biometricKey);
  }
}