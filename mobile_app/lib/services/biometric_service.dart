import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // =========================
  // CHECK BIOMETRIC SUPPORT
  // =========================
  static Future<bool> canAuthenticate() async {
    // ❌ Web does NOT support biometrics
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
}
