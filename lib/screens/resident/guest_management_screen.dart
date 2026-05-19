import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ntry_mobile/database/guest_helper.dart';
import 'package:ntry_mobile/screens/resident/create_guest_pass_screen.dart';
import 'package:ntry_mobile/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:ntry_mobile/auth/biometrics.dart';
import 'package:ntry_mobile/auth/settings_service.dart';

class GuestManagementScreen extends StatefulWidget {
  final String lockId;

  const GuestManagementScreen({super.key, required this.lockId});

  @override
  State<GuestManagementScreen> createState() => _GuestManagementScreenState();
}

class _GuestManagementScreenState extends State<GuestManagementScreen> {
  String? _sharingGuestId;
  String? _savingGuestId;

  DateTime? _resolveExpiry(Map<String, dynamic> data) {
    final expiresAt = data['expiresAt'];
    if (expiresAt is Timestamp) return expiresAt.toDate();
    if (expiresAt is String && expiresAt.isNotEmpty) {
      return DateTime.tryParse(expiresAt);
    }

    final initTime = data['initTime'] as String?;
    if (initTime == null || initTime.isEmpty) return null;

    final start = DateTime.tryParse(initTime);
    if (start == null) return null;

    final durationRaw = data['duration'];
    final durationHours = switch (durationRaw) {
      int value => value,
      String value => int.tryParse(value) ?? 2,
      _ => 2,
    };
    return start.add(Duration(hours: durationHours));
  }

  String _formatExpiry(DateTime? expiry) {
    if (expiry == null) return 'Unknown expiry';
    return DateFormat('MMM d, h:mm a').format(expiry.toLocal());
  }

  Future<void> _handleCreateGuestPass() async {
    final bool gateEnabled = await SettingsService.isBiometricGateEnabled();

    if (!mounted) return;

    if (!gateEnabled) {
      await _navigateToCreateGuestPass();
      return;
    }

    final bool authenticated = await Biometrics.authenticate(
      reason: 'Authenticate to create a guest pass',
    );

    if (!mounted) return;

    if (authenticated) {
      await _navigateToCreateGuestPass();
    }
  }

  Future<void> _navigateToCreateGuestPass() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGuestPassScreen(lockId: widget.lockId),
      ),
    );
  }

  // Fetches the signed JWT token for the given guest doc. Falls back to the
  // plain passId if the Cloud Function hasn't written the token yet.
  Future<String> _getQrData(String guestId, String fallbackPassId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('passkeys')
          .doc(guestId)
          .get();
      final token = snap.data()?['token'] as String?;
      return token ?? fallbackPassId;
    } catch (_) {
      return fallbackPassId;
    }
  }

  Future<Uint8List?> _renderShareImage({
    required String qrData,
    required String guestName,
    required String expiryText,
  }) async {
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);

    final completer = Completer<Uint8List?>();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        ignoring: true,
        child: Stack(
          children: [
            Positioned(
              left: -10000,
              top: -10000,
              child: Material(
                color: Colors.transparent,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: _GuestShareQrImage(
                    qrData: qrData,
                    guestName: guestName,
                    expiryText: expiryText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(entry);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        Uint8List? bytes;
        for (var i = 0; i < 4; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 16));
          final boundary =
              boundaryKey.currentContext?.findRenderObject()
                  as RenderRepaintBoundary?;
          if (boundary == null || boundary.debugNeedsPaint) {
            continue;
          }
          final image = await boundary.toImage(pixelRatio: 3);
          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          bytes = byteData?.buffer.asUint8List();
          if (bytes != null) break;
        }
        completer.complete(bytes);
      } catch (_) {
        completer.complete(null);
      } finally {
        entry.remove();
      }
    });

    return completer.future;
  }

  Future<void> _shareGuestPass({
    required String guestId,
    required String passId,
    required String guestName,
    required DateTime? expiry,
  }) async {
    if (_sharingGuestId != null) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _sharingGuestId = guestId);

    try {
      final expiryText = _formatExpiry(expiry);
      final qrData = await _getQrData(guestId, passId);
      final pngBytes = await _renderShareImage(
        qrData: qrData,
        guestName: guestName,
        expiryText: expiryText,
      );

      if (pngBytes == null || !mounted) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Could not generate QR image.')),
          );
        }
        return;
      }

      final text = 'Guest pass for $guestName\nExpires: $expiryText';

      await Share.shareXFiles(
        [
          XFile.fromData(
            pngBytes,
            mimeType: 'image/png',
            name: 'guest-pass-$passId.png',
          ),
        ],
        text: text,
        subject: 'Ntry Guest Pass',
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to open share sheet.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingGuestId = null);
    }
  }

  Future<void> _saveGuestPassToCameraRoll({
    required String guestId,
    required String passId,
    required String guestName,
    required DateTime? expiry,
  }) async {
    if (_savingGuestId != null) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _savingGuestId = guestId);

    try {
      final expiryText = _formatExpiry(expiry);
      final qrData = await _getQrData(guestId, passId);
      final pngBytes = await _renderShareImage(
        qrData: qrData,
        guestName: guestName,
        expiryText: expiryText,
      );

      if (!mounted) return;
      if (pngBytes == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not generate QR image.')),
        );
        return;
      }

      final result = await SaverGallery.saveImage(
        pngBytes,
        quality: 100,
        fileName: 'ntry-guest-pass-$passId',
        skipIfExists: false,
      );

      final isSuccess = result.isSuccess;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isSuccess
                ? 'Guest QR saved to camera roll.'
                : 'Could not save to camera roll.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to save QR image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingGuestId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: _handleCreateGuestPass,
        child: const Icon(Icons.add),
      ),
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Guests'),
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: GuestHelper().streamGuests(widget.lockId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No guests found',
                style: TextStyle(color: AppColors.subtle, fontSize: 16),
              ),
            );
          }

          final guests = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: guests.length,
            itemBuilder: (context, index) {
              final data = guests[index].data();
              final guestId = guests[index].id;

              final name =
                  (data['visitorName'] as String?) ??
                  (data['name'] as String?) ??
                  'Guest';

              final passId = data['passkey'] as String? ?? guestId;

              final endTime = _resolveExpiry(data);
              final isSharingThisCard = _sharingGuestId == guestId;
              final isSavingThisCard = _savingGuestId == guestId;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isSavingThisCard
                              ? null
                              : () => _saveGuestPassToCameraRoll(
                                  guestId: guestId,
                                  passId: passId,
                                  guestName: name,
                                  expiry: endTime,
                                ),
                          tooltip: 'Save QR to camera roll',
                          icon: isSavingThisCard
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_outlined),
                          color: AppColors.white,
                        ),
                        IconButton(
                          onPressed: isSharingThisCard
                              ? null
                              : () => _shareGuestPass(
                                  guestId: guestId,
                                  passId: passId,
                                  guestName: name,
                                  expiry: endTime,
                                ),
                          tooltip: 'Share QR pass',
                          icon: isSharingThisCard
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.share_outlined),
                          color: AppColors.white,
                        ),
                        IconButton(
                          onPressed: isSharingThisCard
                              ? null
                              : () async {
                                  await GuestHelper().revokeGuestPass(
                                    guests[index].id,
                                  );
                                },
                          tooltip: 'revoke pass',
                          icon: isSharingThisCard
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.block),
                          color: AppColors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pass Pin: $passId',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      endTime != null
                          ? 'Pass Ends: ${DateFormat('MMM d, h:mm a').format(endTime.toLocal())}'
                          : 'Invalid time',
                      style: const TextStyle(
                        color: AppColors.subtle,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _GuestShareQrImage extends StatelessWidget {
  final String qrData;
  final String guestName;
  final String expiryText;

  const _GuestShareQrImage({
    required this.qrData,
    required this.guestName,
    required this.expiryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ntry Guest Pass',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: qrData,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            guestName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Expires: $expiryText',
            style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
