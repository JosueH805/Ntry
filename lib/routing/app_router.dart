import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/screens/admin/access_log_screen.dart';
import 'package:ntry_mobile/screens/admin/admin_home_screen.dart';
import 'package:ntry_mobile/screens/admin/location_management_screen.dart';
import 'package:ntry_mobile/screens/admin/lock_management_screen.dart';
import 'package:ntry_mobile/screens/admin/manage_users_screen.dart';
import 'package:ntry_mobile/screens/auth/login_screen.dart';
import 'package:ntry_mobile/screens/auth/onboarding_screen.dart';
import 'package:ntry_mobile/screens/guest/guest_code_screen.dart';
import 'package:ntry_mobile/screens/guest/guest_qr_screen.dart';
import 'package:ntry_mobile/screens/resident/activity_screen.dart';
import 'package:ntry_mobile/screens/resident/device_settings_screen.dart';
import 'package:ntry_mobile/screens/resident/guest_management_screen.dart';
import 'package:ntry_mobile/screens/auth/pending_approval_screen.dart';
import 'package:ntry_mobile/screens/resident/resident_home_screen.dart';
import 'package:ntry_mobile/screens/resident/profile_screen.dart';

GoRouter buildRouter(AuthService authService) {
  return GoRouter(
    refreshListenable: authService,
    initialLocation: '/login',
    redirect: (BuildContext context, GoRouterState state) {
      // Wait for the auth service to finish its first check.
      if (!authService.isInitialized) return null;

      final loggedIn = authService.isLoggedIn;
      final hasProfile = authService.hasProfile;
      final location = state.matchedLocation;
      final isAdmin = authService.isAdmin;
      final isPendingApproval = authService.isPendingApproval;

      // Not authenticated → allow login and guest routes only.
      if (!loggedIn) {
        if (location == '/login' || location.startsWith('/guest')) return null;
        return '/login';
      }

      // Authenticated but no profile → force onboarding.
      if (!hasProfile) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      // Has profile but pending/denied → force /pending screen.
      if (isPendingApproval) {
        return location == '/pending' ? null : '/pending';
      }

      // Approved user — redirect away from auth/pending screens.
      if (location == '/login' ||
          location == '/onboarding' ||
          location == '/pending' ||
          location == '/'
          ) {
        return isAdmin ? '/admin-home' : '/home';
      }

      // Enforce role-based route boundaries.
      if (isAdmin) {
        if (location.startsWith('/home')) return '/admin-home';
      } else {
        if (location.startsWith('/admin-home')) return '/home';
      }

      return null;
    },
    routes: [
      // ── Auth ────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/pending',
        builder: (context, state) => const PendingApprovalScreen(),
      ),

      // ── Guest ────────────────────────────────────────────────────────
      GoRoute(
        path: '/guest-code',
        builder: (context, state) => const GuestCodeScreen(),
      ),
      GoRoute(
        path: '/guest-qr',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return GuestQRScreen(
            code: extra['code'] as String,
            expiresAt: extra['expiresAt'] as DateTime?,
            latitude: extra['latitude'] as double?,
            longitude: extra['longitude'] as double?,
          );
        },
      ),

      // ── Shared ───────────────────────────────────────────────────────
      // Profile is accessible to both residents (/home) and admins.
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // ── Resident ─────────────────────────────────────────────────────
      GoRoute(
        path: '/home',
        builder: (context, state) => const ResidentHomeScreen(),
        routes: [
          GoRoute(
            path: 'activity',
            builder: (context, state) => const ActivityScreen(),
          ),
          GoRoute(
            path: 'guests',
            builder: (context, state) => GuestManagementScreen(lockId: authService.lockID ?? 'noLockFound',),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const DeviceSettingsScreen(),
          ),
        ],
      ),

      // ── Admin ────────────────────────────────────────────────────────
      GoRoute(
        path: '/admin-home',
        builder: (context, state) => const AdminHomeScreen(),
        routes: [
          GoRoute(
            path: 'manage-users',
            builder: (context, state) => const ManageUsersScreen(),
          ),
          GoRoute(
            path: 'access-log',
            builder: (context, state) =>
                AccessLogScreen(lockId: state.uri.queryParameters['lockId']),
          ),
          GoRoute(
            path: 'lock-management',
            builder: (context, state) => const LockManagementScreen(),
          ),
          GoRoute(path: 'location-management',
          builder: (context, state) => const LocationManagementScreen(),)
        ],
      ),
    ],
  );
}
