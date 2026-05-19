import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ntry_mobile/theme/app_colors.dart';

class GuestQRScreen extends StatefulWidget {
  final String code;
  final DateTime? expiresAt;
  final double? latitude;
  final double? longitude;

  const GuestQRScreen({
    super.key,
    required this.code,
    this.expiresAt,
    this.latitude,
    this.longitude,
  });

  @override
  State<GuestQRScreen> createState() => _GuestQRScreenState();
}

class _GuestQRScreenState extends State<GuestQRScreen> {
  

  int _remainingSeconds = 0;
  bool _isExpired = false;
  Timer? _timer;
  String? _jwtToken;
  StreamSubscription<QuerySnapshot>? _tokenSub;

  @override
  void initState() {
    super.initState();

    // Stream the passkey doc so we pick up the JWT token written by signGuestPass.
    // Passkeys use auto-generated doc IDs; the 6-digit pin is the `passkey` field.
    _tokenSub = FirebaseFirestore.instance
        .collection('passkeys')
        .where('passkey', isEqualTo: widget.code)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty) return;
      final token = snap.docs.first.data()['token'] as String?;
      if (token != null && mounted) {
        setState(() => _jwtToken = token);
      }
    });

    final expiresAt = widget.expiresAt;

    if (expiresAt == null) {
      // No expiry set — treat as non-expiring (timer never starts).
      return;
    }

    final remaining = expiresAt.difference(DateTime.now()).inSeconds;

    if (remaining <= 0) {
      // Already expired before the screen even opened.
      _isExpired = true;
      return;
    }

    _remainingSeconds = remaining;
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
    
  }

  void _onTick(Timer timer) {
    if (!mounted) return;
    setState(() {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
      } else {
        _isExpired = true;
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tokenSub?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openDirections(double lat, double lng) async {
  final encoded = Uri.encodeComponent('Door Location');
  final appleUrl = 'maps://maps.apple.com/?daddr=$lat,$lng&q=$encoded';
  final googleUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  if (await canLaunchUrl(Uri.parse(appleUrl))) {
    await launchUrl(Uri.parse(appleUrl));
  } else {
    await launchUrl(Uri.parse(googleUrl),
        mode: LaunchMode.externalApplication);
  }
}

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final qrSize = (screenHeight * 0.28).clamp(140.0, 240.0);
    final hasExpiry = widget.expiresAt != null;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              if (hasExpiry) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outline),
                    borderRadius: BorderRadius.circular(12),
                    color: colors.surface,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isExpired ? Icons.timer_off : Icons.access_time,
                        color: _isExpired ? colors.error : colors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isExpired ? 'Code Expired' : 'Time Remaining',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isExpired ? '0:00:00' : _formatTime(_remainingSeconds),
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: _isExpired ? colors.error : colors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Expanded(
                child: Center(
                  child: _isExpired
                      ? _buildExpired(colors)
                      : _buildQR(colors, qrSize),
                ),
              ),
              const SizedBox(height: 16),
              if (!_isExpired) ...[
                 if (widget.latitude != null && widget.longitude != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.directions_outlined),
                      label: const Text('Get Directions'),
                      onPressed: () => _openDirections(
                        widget.latitude!,
                        widget.longitude!,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: BorderSide(color: AppColors.accent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Scan to Enter',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hold steady in front of the door scanner',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstructionItem('1', 'Approach the door camera', colors),
                      const SizedBox(height: 8),
                      _buildInstructionItem('2', 'Hold phone screen toward scanner', colors),
                      const SizedBox(height: 8),
                      _buildInstructionItem('3', 'Wait for unlock confirmation', colors),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isExpired ? colors.primary : colors.outline,
                    foregroundColor:
                        _isExpired ? colors.onPrimary : colors.onSurface,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => context.go('/guest-code'),
                  child: Text(
                    _isExpired ? 'Use a New Code' : 'Exit',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQR(ColorScheme colors, double qrSize) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline, width: 2),
      ),
      child: _jwtToken != null
          ? QrImageView(
              data: _jwtToken!,
              size: qrSize,
            )
          : SizedBox(
              width: qrSize,
              height: qrSize,
              child: const Center(child: CircularProgressIndicator()),
            ),
    );
  }

  Widget _buildInstructionItem(String number, String text, ColorScheme colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.primary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colors.onSurface,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpired(ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_clock, size: 64, color: colors.error),
        const SizedBox(height: 16),
        Text(
          'Access Expired',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Request a new code from your host.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: colors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
