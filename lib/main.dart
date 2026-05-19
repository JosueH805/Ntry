import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/auth/settings_service.dart';
import 'package:ntry_mobile/providers/lock_provider.dart';
import 'package:ntry_mobile/providers/user_provider.dart';
import 'package:ntry_mobile/routing/app_router.dart';
import 'package:ntry_mobile/screens/auth/app_lock_screen.dart';
import 'package:ntry_mobile/services/ble_service.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  authServiceInstance = AuthService();
  userProviderInstance = UserProvider();
  lockProviderInstance = LockProvider();
  themeNotifierInstance = ThemeNotifier();
  bleServiceInstance = BleService();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  bool _splashVisible = true;
  bool _splashRemoved = false;
  bool _biometricLocked = false;
  bool _biometricPromptInProgress = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = buildRouter(authServiceInstance);
    _waitForReady();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // Re-lock if the app was backgrounded for more than 5 seconds and
      // the user is still logged in. The 5-second buffer avoids re-locking
      // when the biometric prompt itself briefly backgrounds the app.
      final pausedAt = _pausedAt;
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt).inSeconds >= 5 &&
          authServiceInstance.isLoggedIn) {
        _pausedAt = null;
        _showBiometricLock();
      }
    }
  }

  Future<void> _waitForReady() async {
    final minDuration = Future.delayed(const Duration(milliseconds: 1500));

    // Wait for auth to initialize (may already be done).
    if (!authServiceInstance.isInitialized) {
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return !authServiceInstance.isInitialized;
      });
    }

    // Ensure the minimum splash duration has elapsed.
    await minDuration;

    if (!mounted) return;

    // If the user is already logged in, show the lock screen.
    // AppLockScreen auto-triggers biometrics on mount.
    if (authServiceInstance.isLoggedIn) {
      final gateEnabled = await SettingsService.isBiometricGateEnabled();
      if (gateEnabled) {
        if (mounted) setState(() => _biometricLocked = true);
      }
    }

    if (!mounted) return;
    setState(() => _splashVisible = false);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _splashRemoved = true);
  }

  Future<void> _showBiometricLock() async {
    if (_biometricPromptInProgress) return;
    _biometricPromptInProgress = true;

    final gateEnabled = await SettingsService.isBiometricGateEnabled();
    _biometricPromptInProgress = false;
    if (!gateEnabled || !mounted) return;

    setState(() => _biometricLocked = true);
    // AppLockScreen auto-triggers biometrics on mount.
  }

  void _onUnlocked() {
    if (mounted) setState(() => _biometricLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifierInstance,
      builder: (context, _) => MaterialApp.router(
        title: 'Ntry',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeNotifierInstance.mode,
        routerConfig: _router,
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              if (_biometricLocked) AppLockScreen(onUnlocked: _onUnlocked),
              if (!_splashRemoved)
                IgnorePointer(
                  ignoring: !_splashVisible,
                  child: AnimatedOpacity(
                    opacity: _splashVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: const SplashScreen(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

