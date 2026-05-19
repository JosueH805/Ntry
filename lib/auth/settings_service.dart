import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _biometricGateKey = 'biometric_gate_enabled';

  static Future<bool> isBiometricGateEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricGateKey) ?? true;
  }

  static Future<void> setBiometricGate(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricGateKey, value);
  }
}