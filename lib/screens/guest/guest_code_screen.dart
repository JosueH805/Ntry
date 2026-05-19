import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/Database/passkey_helper.dart';

class GuestCodeScreen extends StatefulWidget {
  const GuestCodeScreen({super.key});

  @override
  State<GuestCodeScreen> createState() => _GuestCodeScreenState();
}

class _GuestCodeScreenState extends State<GuestCodeScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      final index = i;
      _focusNodes[index].onKeyEvent = (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace) {
          _onBackspace(index);
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitEntered(int index, String value) {
    if (value.isEmpty) return;
    if (index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    // Clear error once the user starts re-entering digits.
    if (_isError) setState(() => _isError = false);
    _checkComplete();
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _checkComplete() {
    final code = _controllers.map((c) => c.text).join();
    if (code.length == 6) _submit(code);
  }

  Future<void> _submit(String code) async {
  final result = await PasskeyHelper().getLockIdExpiryAndCoordinates(code);

  if (result != null) {
    context.push('/guest-qr', extra: {
      'code': code,
      'expiresAt': result.expiresAt,
      'latitude': result.latitude,
      'longitude': result.longitude,
    });
  } else {
    setState(() => _isError = true);
    HapticFeedback.mediumImpact();
    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
  }
}

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            Text(
              'Guest Access',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit code from your host',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: colors.onSurface.withAlpha(120),
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) => _buildBox(i, colors)),
            ),
            AnimatedOpacity(
              opacity: _isError ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Invalid code. Please try again.',
                  style: GoogleFonts.inter(fontSize: 13, color: colors.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBox(int index, ColorScheme colors) {
    final radius = BorderRadius.circular(12);
    final defaultBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: _isError ? colors.error : colors.outline,
        width: _isError ? 2 : 1,
      ),
    );

    return SizedBox(
      width: 48,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        autofocus: index == 0,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        obscureText: true,
        cursorColor: _isError ? colors.error : colors.primary,
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: _isError ? colors.error : colors.primary,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          filled: true,
          fillColor: colors.surfaceContainerHighest,
          border: defaultBorder,
          enabledBorder: defaultBorder,
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(
              color: _isError ? colors.error : colors.primary,
              width: 2,
            ),
          ),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (val) => _onDigitEntered(index, val),
      ),
    );
  }
}
