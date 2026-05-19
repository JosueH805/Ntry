import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/Database/location_helper.dart';
import 'package:ntry_mobile/Database/lock_helper.dart';
import 'package:ntry_mobile/Database/user_helper.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _approvedStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _pendingStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _locksStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _locationsStream;

  @override
  void initState() {
    super.initState();
    final org = authServiceInstance.organization ?? '';
    _approvedStream =
        UserHelper().streamUsersByOrg(org, approvalStatus: 'approved');
    _pendingStream =
        UserHelper().streamUsersByOrg(org, approvalStatus: 'pending');
    _locksStream = LockHelper().streamByOrg(org);
    _locationsStream = LocationHelper().streamByOrg(org);
  }

  void _navigate(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final firstName = authServiceInstance.firstName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(firstName.isEmpty ? 'Hello...' : 'Hello, $firstName'),
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Manage Users'),
                onTap: () => _navigate(context, '/admin-home/manage-users'),
              ),
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Profile'),
                onTap: () => _navigate(context, '/profile'),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Lock Management'),
                onTap: () => _navigate(context, '/admin-home/lock-management'),
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Location Management'),
                onTap: () =>
                    _navigate(context, '/admin-home/location-management'),
              ),
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('Access Log'),
                onTap: () => _navigate(context, '/admin-home/access-log'),
              ),
              const Spacer(),
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                title: Text(
                  'Logout',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
                onTap: () => authServiceInstance.signOut(),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              'Admin Dashboard',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),

            _buildLiveStatsCard(context),
            const SizedBox(height: 24),

            // Dynamic alert — only renders when there are pending users
            StreamBuilder(
              stream: _pendingStream,
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Column(
                  children: [
                    _buildAlertCard(
                      context,
                      title: 'Pending Approval',
                      subtitle:
                          '$count user${count == 1 ? '' : 's'} awaiting approval',
                      actionLabel: 'Review',
                      actionColor: Theme.of(context).colorScheme.primary,
                      onTap: () => context.push('/admin-home/manage-users'),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 16) / 2;
                const cardHeight = 110.0;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: StreamBuilder(
                        stream: _pendingStream,
                        builder: (context, badgeSnapshot) {
                          final pendingCount =
                              badgeSnapshot.data?.docs.length ?? 0;
                          return _dashboardCard(
                            context,
                            title: 'Manage Users',
                            icon: Icons.group_outlined,
                            route: '/admin-home/manage-users',
                            badgeCount: pendingCount > 0 ? pendingCount : null,
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _dashboardCard(
                        context,
                        title: 'Profile',
                        icon: Icons.account_circle_outlined,
                        route: '/profile',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _dashboardCard(
                        context,
                        title: 'Lock Management',
                        icon: Icons.lock_outline,
                        route: '/admin-home/lock-management',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _dashboardCard(
                        context,
                        title: 'Location Management',
                        icon: Icons.location_on_outlined,
                        route: '/admin-home/location-management',
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      height: cardHeight,
                      child: _dashboardCard(
                        context,
                        title: 'Access Log',
                        icon: Icons.history_outlined,
                        route: '/admin-home/access-log',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatsCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _streamMetric('Users', _approvedStream, colors),
              _streamMetric('Pending', _pendingStream, colors),
              _streamMetric('Locks', _locksStream, colors),
              _streamMetric('Locations', _locationsStream, colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _streamMetric(
    String label,
    Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    ColorScheme colors,
  ) {
    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.data?.docs.length.toString() ?? '—';
        return _buildStatusMetric(label, value, colors);
      },
    );
  }

  Widget _buildStatusMetric(String label, String value, ColorScheme colors) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _dashboardCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
    int? badgeCount,
  }) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(route),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: colors.primary),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.onError,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String actionLabel,
    required Color actionColor,
    VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: actionColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: actionColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
