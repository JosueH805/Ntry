import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/auth/biometrics.dart';
import 'package:ntry_mobile/auth/settings_service.dart';
import 'package:ntry_mobile/database/lock_helper.dart';
import 'package:ntry_mobile/providers/lock_provider.dart';
import 'package:ntry_mobile/providers/user_provider.dart';
import 'package:ntry_mobile/services/ble_service.dart';
import 'package:ntry_mobile/theme/app_colors.dart';

const _kUnlockBlue = Color(0xFF4A50E4);
const _kUnlockGreen = Color(0xFF22C55E);
const _kUnlockOrange = Color(0xFFF97316);

class ResidentHomeScreen extends StatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  State<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends State<ResidentHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isUnlocked = false;
  bool _isLoading = false;
  StreamSubscription<dynamic>? _logSub;
  Timer? _unlockTimer;

  void _navigate(String route) {
    Navigator.of(context).pop();
    context.push(route);
  }

  void _cancelUnlockWatcher() {
    _logSub?.cancel();
    _logSub = null;
    _unlockTimer?.cancel();
    _unlockTimer = null;
  }

  Future<void> _handleUnlock(String lockId) async {
    final bool gateEnabled = await SettingsService.isBiometricGateEnabled();

    if (!gateEnabled) {
      await _unlockDoor(lockId);
      return;
    }

    final bool authenticated = await Biometrics.authenticate(
      reason: 'Authenticate to unlock the door',
    );

    if (authenticated) {
      await _unlockDoor(lockId);
    }
  }

  Future<void> _unlockDoor(String lockId) async {
    final userId = authServiceInstance.currentUser?.uid;
    if (userId == null || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final logId = await LockHelper().addUnlockToPending(
        lockId,
        userId,
        lockProviderInstance.name ?? lockId,
        userProviderInstance.displayName,
      );

      // RTDB write succeeded — optimistically go green after 1s.
      // The M5Stack will fire as long as the write reached the server.
      _unlockTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        _cancelUnlockWatcher();
        setState(() {
          _isLoading = false;
          _isUnlocked = true;
        });
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _isUnlocked = false);
        });
      });

      // Watch for an explicit failure from the log before the timer fires.
      _logSub = LockHelper().streamLog(logId).listen((snap) {
        final status = snap.data()?['status'] as String?;
        if (status == 'failed' && mounted) {
          _cancelUnlockWatcher();
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unlock failed. Please try again.')),
          );
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send unlock. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _cancelUnlockWatcher();
    super.dispose();
  }

  Widget _buildScaffold({
    required String firstName,
    required String lastName,
    required String room,
    required String? lockId,
    required bool isAdvertising,
  }) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.black,
      endDrawer: _Drawer(onNavigate: _navigate),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              firstName: firstName,
              lastName: lastName,
              room: room,
              onMenuTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
            const Spacer(),
            lockId == null
                ? const SizedBox.shrink()
                : _ProximityBadge(isActive: isAdvertising),
            const SizedBox(height: 28),
            _UnlockButton(
              isUnlocked: _isUnlocked,
              isLoading: _isLoading,
              onTap: lockId != null ? () => _handleUnlock(lockId) : null,
            ),
            const SizedBox(height: 36),
            _UnlockHint(isUnlocked: _isUnlocked),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        userProviderInstance,
        lockProviderInstance,
        bleServiceInstance,
      ]),
      builder: (context, _) {
        return _buildScaffold(
          firstName: userProviderInstance.firstName ?? '',
          lastName: userProviderInstance.lastName ?? '',
          room: lockProviderInstance.room ?? '',
          lockId: userProviderInstance.lockId,
          isAdvertising: bleServiceInstance.isAdvertising,
        );
      },
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.firstName,
    required this.lastName,
    required this.room,
    required this.onMenuTap,
  });

  final String firstName;
  final String lastName;
  final String room;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName.isEmpty ? '—' : fullName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (room.isNotEmpty)
                Text(
                  room,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.subtle),
                ),
            ],
          ),
          _MenuButton(onTap: onMenuTap),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.menu_rounded, color: AppColors.white, size: 22),
      ),
    );
  }
}

// ── Proximity Badge ─────────────────────────────────────────────────────────

class _ProximityBadge extends StatelessWidget {
  const _ProximityBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.accent : AppColors.subtle;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.bluetooth : Icons.bluetooth_disabled,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              isActive ? 'Proximity Active' : 'BLE Off',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Unlock Button ───────────────────────────────────────────────────────────

class _UnlockButton extends StatelessWidget {
  const _UnlockButton({
    required this.isUnlocked,
    required this.onTap,
    required this.isLoading,
  });
  final bool isUnlocked;
  final bool isLoading;
  final VoidCallback? onTap;

  bool get _enabled => onTap != null;

  @override
  Widget build(BuildContext context) {
    final glowColor = isLoading
        ? _kUnlockOrange
        : (isUnlocked ? _kUnlockGreen : _kUnlockBlue);

    return Center(
      child: Opacity(
        opacity: _enabled ? 1.0 : 0.4,
        child: GestureDetector(
          onTap: isUnlocked ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLoading
                  ? _kUnlockOrange
                  : (isUnlocked ? _kUnlockGreen : _kUnlockBlue),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.55),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.25),
                  blurRadius: 1000,
                  spreadRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isLoading
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          (isUnlocked
                              ? Icons.check_circle_rounded
                              : Icons.lock_open_rounded),
                          key: ValueKey(isUnlocked),
                          size: 72,
                          color: Colors.white,
                        ),
                      ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    isLoading
                        ? 'Unlocking'
                        : (isUnlocked ? 'Unlocked' : 'Unlock'),
                    key: ValueKey(isUnlocked),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hint Text ───────────────────────────────────────────────────────────────

class _UnlockHint extends StatelessWidget {
  const _UnlockHint({required this.isUnlocked});
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        isUnlocked ? 'Door is unlocked' : 'Walk up to unlock automatically',
        key: ValueKey(isUnlocked),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isUnlocked ? _kUnlockGreen : AppColors.subtle,
        ),
      ),
    );
  }
}

// ── Drawer ──────────────────────────────────────────────────────────────────

class _Drawer extends StatelessWidget {
  const _Drawer({required this.onNavigate});
  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('Guest Management'),
              onTap: () => onNavigate('/home/guests'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Activity'),
              onTap: () => onNavigate('/home/activity'),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Device Settings'),
              onTap: () => onNavigate('/home/settings'),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Profile'),
              onTap: () => onNavigate('/profile'),
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
    );
  }
}
