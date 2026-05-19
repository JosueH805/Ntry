import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/database/lock_helper.dart';
import 'package:ntry_mobile/database/user_helper.dart';
import 'package:ntry_mobile/widgets/search_picker_sheet.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminOrg = authServiceInstance.organization;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'All Users'),
          ],
        ),
      ),
      body: adminOrg == null
          ? const Center(child: Text('Unable to load organization.'))
          : TabBarView(
              controller: _tabController,
              children: [
                _PendingTab(adminOrg: adminOrg),
                _AllUsersTab(adminOrg: adminOrg),
              ],
            ),
    );
  }
}

// ── Pending Tab ───────────────────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  final String adminOrg;
  const _PendingTab({required this.adminOrg});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: UserHelper().streamUsersByOrg(adminOrg, approvalStatus: 'pending'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No pending requests.',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _UserCard(
              uid: docs[index].id,
              data: data,
              isPending: true,
              org: adminOrg,
            );
          },
        );
      },
    );
  }
}

// ── All Users Tab ─────────────────────────────────────────────────────────────

class _AllUsersTab extends StatelessWidget {
  final String adminOrg;
  const _AllUsersTab({required this.adminOrg});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: UserHelper().streamUsersByOrg(adminOrg, approvalStatus: 'approved'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No approved users.',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _UserCard(
              uid: docs[index].id,
              data: data,
              isPending: false,
              org: adminOrg,
            );
          },
        );
      },
    );
  }
}

// ── User Card ─────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  final bool isPending;
  final String org;

  const _UserCard({
    required this.uid,
    required this.data,
    required this.isPending,
    required this.org,
  });

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.month}/${dt.day}/${dt.year}';
    }
    return '—';
  }

  Future<List<PickerOption>> _fetchLocks() async {
    final snap = await LockHelper().getByOrg(org);
    return snap.docs.map((doc) {
      final d = doc.data();
      final name = d['name'] as String? ?? doc.id;
      final room = d['room'] as String?;
      return PickerOption(
        id: doc.id,
        label: room != null ? '$name · $room' : name,
      );
    }).toList();
  }

  Future<void> _handleApprove(BuildContext context) async {
    final role = data['role'] as String? ?? 'resident';
    if (role == 'resident') {
      final selected = await showModalBottomSheet<PickerOption>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SearchPickerSheet(
          title: 'Assign Lock',
          subtitle: 'Search by room name or lock ID.',
          searchHint: 'Search by room or name...',
          itemIcon: Icons.lock_outline,
          optionsFuture: _fetchLocks(),
        ),
      );
      if (selected != null && context.mounted) {
        await UserHelper().updateApproval(uid, 'approved', lockId: selected.id);
      }
    } else {
      await UserHelper().updateApproval(uid, 'approved');
    }
  }

  Future<void> _handleDeny(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deny Request'),
        content: const Text('Are you sure you want to deny this request?'),
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
            child: const Text('Deny'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await UserHelper().updateApproval(uid, 'denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final firstName = data['first_name'] as String? ?? '';
    final lastName = data['last_name'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final role = data['role'] as String? ?? 'resident';
    final lockId = data['lock_id'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$firstName $lastName',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!isPending && role == 'resident')
                            IconButton(
                              icon: const Icon(Icons.edit_square, size: 16),
                              color: colors.primary,
                              onPressed: () async {
                                final selected =
                                    await showModalBottomSheet<PickerOption>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (ctx) => SearchPickerSheet(
                                    title: 'Assign Lock',
                                    subtitle: 'Search by room name or lock ID.',
                                    searchHint: 'Search by room or name...',
                                    itemIcon: Icons.lock_outline,
                                    optionsFuture: _fetchLocks(),
                                  ),
                                );
                                if (selected != null && context.mounted) {
                                  await UserHelper()
                                      .assignLock(uid, selected.id);
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoleChip(role: role),
              ],
            ),
            const SizedBox(height: 8),
            if (isPending)
              Text(
                'Joined: ${_formatDate(data['createdAt'])}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              )
            else if (role == 'resident' && lockId != null)
              Text(
                'Lock ID: $lockId',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleDeny(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                        side: BorderSide(color: colors.error),
                      ),
                      child: const Text('Deny'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleApprove(context),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Role Chip ─────────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin ? colors.primaryContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'Resident',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isAdmin
              ? colors.onPrimaryContainer
              : colors.onSecondaryContainer,
        ),
      ),
    );
  }
}
