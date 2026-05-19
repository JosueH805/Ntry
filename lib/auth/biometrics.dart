import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class Biometrics {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Returns true if the device supports biometric or device-PIN authentication.
  static Future<bool> isAvailable() async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      final bool canCheck = await _auth.canCheckBiometrics;
      return isSupported || canCheck;
    } on PlatformException {
      return false;
    }
  }

  /// Prompts biometric authentication with PIN fallback.
  static Future<bool> authenticate({
    String reason = 'Please authenticate to continue',
  }) async {
    try {
      if (!await isAvailable()) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}