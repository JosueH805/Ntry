import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/database/access_log_helper.dart';

const _bleBlue    = Color(0xFF4A9EFF);
const _guestAmber = Color(0xFFFFAB40);

/// Shared access-log list widget. Pass a [lockId] to stream and display logs
/// for that lock. Used by both the admin AccessLogScreen (with a lock picker
/// above it) and the resident ActivityScreen (lockId fixed from auth).
class AccessLogView extends StatelessWidget {
  final String lockId;

  const AccessLogView({super.key, required this.lockId});

  // ── Formatting helpers ──────────────────────────────────────────────────

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(dt.year, dt.month, dt.day);

    const months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:${dt.minute.toString().padLeft(2, '0')} $period';

    if (day == today) return 'Today, $time';
    if (day == yesterday) return 'Yesterday, $time';
    return '${months[dt.month]} ${dt.day}, $time';
  }

  bool _isBle(String method) => method == 'ble' || method == 'BLE';
  bool _isGuest(String method) => method == 'guest';

  Color _methodColor(String method, String status, ColorScheme colors) {
    if (status == 'failed' || status == 'denied') return colors.error;
    if (_isBle(method)) return _bleBlue;
    if (_isGuest(method)) return _guestAmber;
    return switch (method) {
      'manual' => colors.primary,
      'QR' => colors.tertiary,
      'admin_override' => colors.secondary,
      _ => colors.onSurfaceVariant,
    };
  }

  String _methodLabel(String method) => switch (method.toLowerCase()) {
        'manual' => 'Manual',
        'ble' => 'Bluetooth',
        'guest' => 'Guest QR',
        'qr' => 'QR',
        'admin_override' => 'Admin Override',
        _ => method.replaceAll('_', ' '),
      };

  IconData _methodIcon(String method, String status) {
    if (status == 'failed' || status == 'denied') return Icons.lock_outline;
    if (_isBle(method)) return Icons.bluetooth;
    if (_isGuest(method)) return Icons.qr_code_scanner;
    return switch (method) {
      'manual' => Icons.lock_open,
      'QR' => Icons.qr_code,
      'admin_override' => Icons.admin_panel_settings,
      _ => Icons.info,
    };
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AccessLogHelper().streamByLock(lockId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading logs: ${snapshot.error}'));
        }

        var docs = snapshot.data?.docs ?? [];
        docs = List.from(docs)
          ..sort((a, b) {
            final tA = (a['timestamp'] as Timestamp?)?.toDate() ??
                DateTime.fromMicrosecondsSinceEpoch(0);
            final tB = (b['timestamp'] as Timestamp?)?.toDate() ??
                DateTime.fromMicrosecondsSinceEpoch(0);
            return tB.compareTo(tA);
          });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_outlined, size: 64, color: colors.outline),
                const SizedBox(height: 16),
                Text(
                  'No access logs yet',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) =>
              _buildLogTile(AccessLog.fromFirestore(docs[index]), colors),
        );
      },
    );
  }

  Widget _buildLogTile(AccessLog log, ColorScheme colors) {
    final color = _methodColor(log.method, log.status, colors);
    final label = _methodLabel(log.method);
    final icon = _methodIcon(log.method, log.status);
    final formattedTime = _formatDateTime(log.timestamp);

    final statusLabel = switch (log.status) {
      'executed' => 'Granted',
      'failed' || 'denied' => 'Denied',
      'pending' => 'Pending',
      _ => log.status,
    };
    final statusColor = switch (log.status) {
      'executed' => colors.primary,
      'failed' || 'denied' => colors.error,
      _ => colors.outline,
    };

    final isBle = _isBle(log.method);
    final isGuest = _isGuest(log.method);

    Color tileColor;
    Color tileBorder;
    if (isBle) {
      tileColor = _bleBlue.withValues(alpha: 0.06);
      tileBorder = _bleBlue.withValues(alpha: 0.4);
    } else if (isGuest) {
      tileColor = _guestAmber.withValues(alpha: 0.06);
      tileBorder = _guestAmber.withValues(alpha: 0.4);
    } else {
      tileColor = colors.surfaceContainer;
      tileBorder = colors.outline;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tileBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          log.visitorName ?? 'Resident',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedTime,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    if (log.details != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        log.details!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
