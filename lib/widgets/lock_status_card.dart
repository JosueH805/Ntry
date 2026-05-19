import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/theme/app_colors.dart';

class LockStatusCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const LockStatusCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final status = data['status'] as String? ?? 'locked';
    final isLockedDown = data['isLockedDown'] as bool? ?? false;
    final lastUnlocked = data['last_unlocked'] as Timestamp?;
    final isUnlocked = status == 'unlocked';

    final statusColor = isLockedDown
        ? colors.error
        : isUnlocked
            ? AppColors.accent
            : colors.onSurfaceVariant;

    final statusLabel = isLockedDown
        ? 'Locked Down'
        : isUnlocked
            ? 'Unlocked'
            : 'Locked';

    final statusIcon = isLockedDown
        ? Icons.lock_clock_outlined
        : isUnlocked
            ? Icons.lock_open_outlined
            : Icons.lock_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withAlpha(80), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusPill(label: statusLabel, color: statusColor),
                const SizedBox(height: 8),
                _LastOpenedRow(
                  lastUnlocked: lastUnlocked,
                  subtleColor: colors.onSurfaceVariant,
                ),
                if (isLockedDown) ...[
                  const SizedBox(height: 6),
                  _LockdownWarning(errorColor: colors.error),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _LastOpenedRow extends StatelessWidget {
  final Timestamp? lastUnlocked;
  final Color subtleColor;
  const _LastOpenedRow(
      {required this.lastUnlocked, required this.subtleColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.history_outlined, size: 13, color: subtleColor),
        const SizedBox(width: 5),
        Text(
          lastUnlocked != null
              ? 'Last opened ${_formatRelative(lastUnlocked!.toDate())}'
              : 'Never opened',
          style: GoogleFonts.inter(fontSize: 12, color: subtleColor),
        ),
      ],
    );
  }
}

class _LockdownWarning extends StatelessWidget {
  final Color errorColor;
  const _LockdownWarning({required this.errorColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 13, color: errorColor),
        const SizedBox(width: 5),
        Text(
          'Lockdown is active',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: errorColor,
          ),
        ),
      ],
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

String _formatRelative(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt.toLocal());

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = dt.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${months[local.month - 1]} ${local.day} at $hour:$minute $period';
}
