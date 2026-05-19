import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/providers/user_provider.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen>
    with SingleTickerProviderStateMixin {
  bool _redirected = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: ListenableBuilder(
        listenable: userProviderInstance,
        builder: (context, _) {
          final org = userProviderInstance.organization ?? '—';
          final role = userProviderInstance.role ?? '—';
          final status = userProviderInstance.approvalStatus ?? 'pending';
          final isDenied = status == 'denied';

          // Redirect when approved
          if (status == 'approved' && !_redirected) {
            _redirected = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              authServiceInstance.refreshProfile();
            });
          }

          if (isDenied) {
            _pulseController.stop();
          } else if (!_pulseController.isAnimating) {
            _pulseController.repeat(reverse: true);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // ── Branding ──────────────────────────────────────
                  Text(
                    'ntry',
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                      letterSpacing: -2,
                    ),
                  ),

                  const Spacer(),

                  // ── Status Icon ───────────────────────────────────
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: isDenied ? 1.0 : _pulseAnimation.value,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDenied
                            ? colors.errorContainer
                            : colors.primaryContainer,
                      ),
                      child: Icon(
                        isDenied
                            ? Icons.block_rounded
                            : Icons.hourglass_top_rounded,
                        size: 44,
                        color: isDenied
                            ? colors.onErrorContainer
                            : colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Title ─────────────────────────────────────────
                  Text(
                    isDenied ? 'Request Denied' : 'Pending Approval',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Subtitle ──────────────────────────────────────
                  Text(
                    isDenied
                        ? 'Your access request was not approved. Contact your organization\'s administrator for assistance.'
                        : 'Your account is awaiting approval from an administrator at your organization.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Info Card ─────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        _infoTile(
                          Icons.business_rounded,
                          'Organization',
                          org,
                          colors,
                        ),
                        Divider(
                          height: 20,
                          color: colors.outlineVariant,
                        ),
                        _infoTile(
                          Icons.badge_outlined,
                          'Role',
                          role.isNotEmpty
                              ? role[0].toUpperCase() + role.substring(1)
                              : '—',
                          colors,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ── Sign Out ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => authServiceInstance.signOut(),
                      child: const Text('Sign Out'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile(
    IconData icon,
    String label,
    String value,
    ColorScheme colors,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
