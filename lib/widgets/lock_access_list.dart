import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/theme/app_colors.dart';
import 'package:ntry_mobile/widgets/lock_form_widgets.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class LockAccessUser {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String role;

  const LockAccessUser({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });
}

// ── User Tile ─────────────────────────────────────────────────────────────────

class LockAccessUserTile extends StatelessWidget {
  final LockAccessUser user;
  final VoidCallback onRemove;

  const LockAccessUserTile({
    super.key,
    required this.user,
    required this.onRemove,
  });

  Future<void> _removeAccess(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Access'),
        content: Text(
          'Remove access for ${user.firstName} ${user.lastName}?\n'
          'They will no longer be able to open this lock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'lock_id': FieldValue.delete()});
      onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = lockInitials(user.firstName, user.lastName);
    final isAdmin = user.role == 'admin';

    return Container(
      padding:
          const EdgeInsets.only(left: 14, top: 10, bottom: 10, right: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.primaryContainer.withAlpha(60),
            child: Text(
              initials,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.firstName} ${user.lastName}'.trim(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _RoleChip(isAdmin: isAdmin),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'remove') _removeAccess(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.remove_circle_outline,
                        size: 18, color: colors.error),
                    const SizedBox(width: 10),
                    Text(
                      'Remove Access',
                      style: GoogleFonts.inter(
                          color: colors.error, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            icon: Icon(Icons.more_vert,
                size: 20, color: colors.onSurfaceVariant),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final bool isAdmin;
  const _RoleChip({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? colors.primaryContainer.withAlpha(50)
            : AppColors.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAdmin ? colors.primary.withAlpha(60) : AppColors.border,
        ),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'Resident',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isAdmin ? colors.primary : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class LockEmptyAccess extends StatelessWidget {
  const LockEmptyAccess({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.group_off_outlined,
              size: 32, color: colors.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            'No users assigned to this lock.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
