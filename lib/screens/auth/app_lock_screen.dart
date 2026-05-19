import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/auth/biometrics.dart';
import 'package:ntry_mobile/auth/settings_service.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _initialized = false;
  bool _biometricsAvailable = false;
  bool _showPasswordForm = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final available = await Biometrics.isAvailable();
    if (!mounted) return;

    setState(() {
      _biometricsAvailable = available;
      _initialized = true;
      if (!available && _isEmailUser) _showPasswordForm = true;
    });

    if (available) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  bool get _isEmailUser {
    final user = authServiceInstance.currentUser;
    return user?.providerData.any((p) => p.providerId == 'password') ?? false;
  }

  String get _firstName => authServiceInstance.firstName ?? '';

  String get _maskedEmail {
    final email = authServiceInstance.currentUser?.email ?? '';
    final atIndex = email.indexOf('@');
    if (atIndex <= 1) return email;
    return '${email[0]}${'•' * (atIndex - 1)}${email.substring(atIndex)}';
  }

  Future<void> _tryBiometric() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authenticated = await Biometrics.authenticate(
      reason: 'Authenticate to open Ntry',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (authenticated) {
      widget.onUnlocked();
    }
  }

  Future<void> _submitPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) return;

    final user = authServiceInstance.currentUser;
    if (user == null || user.email == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      if (mounted) widget.onUnlocked();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            (e.code == 'wrong-password' || e.code == 'invalid-credential')
                ? 'Incorrect password. Please try again.'
                : 'Authentication failed. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _signOut() async {
    await SettingsService.setBiometricGate(true);
    await authServiceInstance.signOut();
    if (mounted) widget.onUnlocked();
  }

  void _togglePasswordForm() {
    setState(() {
      _showPasswordForm = !_showPasswordForm;
      _errorMessage = null;
      _passwordController.clear();
    });
    if (_showPasswordForm) {
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _passwordFocusNode.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Branding (pinned top) ─────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                'ntry',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                  letterSpacing: -1.5,
                ),
              ),
            ),

            // ── Scrollable center content ─────────────────────────
            // LayoutBuilder measures the available height so that content
            // stays vertically centered when it fits, and scrolls (without
            // overflow) when the keyboard / password form pushes it taller.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        minWidth: constraints.maxWidth,
                      ),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Lock icon
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.surfaceContainerHighest,
                                border: Border.all(color: colors.outline),
                              ),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                size: 34,
                                color: colors.onSurface.withAlpha(180),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Greeting
                            Text(
                              'Welcome back,',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colors.onSurface.withAlpha(128),
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _firstName.isNotEmpty ? _firstName : 'there',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (_maskedEmail.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                _maskedEmail,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colors.onSurface.withAlpha(90),
                                      letterSpacing: 0.3,
                                    ),
                              ),
                            ],

                            const SizedBox(height: 48),

                            // Biometric button or init spinner
                            if (!_initialized)
                              SizedBox(
                                width: 72,
                                height: 72,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onSurface.withAlpha(60),
                                ),
                              )
                            else if (_biometricsAvailable)
                              _buildBiometricButton(colors),

                            // Account password fallback (email/password users only)
                            if (_initialized && _isEmailUser) ...[
                              const SizedBox(height: 20),
                              if (_biometricsAvailable)
                                TextButton(
                                  onPressed:
                                      _isLoading ? null : _togglePasswordForm,
                                  child: Text(
                                    _showPasswordForm
                                        ? 'Use Face ID or passcode instead'
                                        : 'Use account password instead',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.onSurface.withAlpha(140),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                alignment: Alignment.topCenter,
                                child: _showPasswordForm
                                    ? _buildPasswordForm(colors)
                                    : const SizedBox.shrink(),
                              ),
                            ],

                            // Error message
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: _errorMessage != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Text(
                                        _errorMessage!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.error,
                                          fontSize: 13,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Sign out (pinned bottom) ──────────────────────────
            TextButton(
              onPressed: _isLoading ? null : _signOut,
              child: Text(
                'Sign out',
                style: TextStyle(
                  color: colors.onSurface.withAlpha(80),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricButton(ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _isLoading ? null : _tryBiometric,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isLoading
                  ? colors.surfaceContainerHighest
                  : colors.primary,
            ),
            child: _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(22),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onSurface.withAlpha(100),
                    ),
                  )
                : Icon(
                    Icons.fingerprint_rounded,
                    size: 36,
                    color: colors.onPrimary,
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Use Face ID or passcode',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withAlpha(120),
              ),
        ),
      ],
    );
  }

  Widget _buildPasswordForm(ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitPassword(),
          decoration: InputDecoration(
            hintText: 'Account password',
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitPassword,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Unlock'),
        ),
      ],
    );
  }
}
