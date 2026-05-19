import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/database/lock_helper.dart';
import 'package:ntry_mobile/widgets/access_log_view.dart';

class AccessLogScreen extends StatefulWidget {
  /// Pass a [lockId] to skip the lock picker and show logs for a specific lock.
  final String? lockId;

  const AccessLogScreen({super.key, this.lockId});

  @override
  State<AccessLogScreen> createState() => _AccessLogScreenState();
}

class _AccessLogScreenState extends State<AccessLogScreen> {
  late final LockHelper _lockHelper;
  late final Future<QuerySnapshot<Map<String, dynamic>>> _locksFuture;
  String? _selectedLockId;

  @override
  void initState() {
    super.initState();
    _lockHelper = LockHelper();
    _selectedLockId = widget.lockId;
    _locksFuture = widget.lockId != null
        ? _lockHelper.getByIds([widget.lockId!])
        : _lockHelper.getByOrg(authServiceInstance.organization ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Access Log')),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: _locksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading locks: ${snapshot.error}'),
            );
          }

          final locks = snapshot.data?.docs ?? [];
          if (locks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: colors.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No locks found',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (_selectedLockId == null && locks.isNotEmpty) {
            _selectedLockId = locks.first.id;
          }

          return Column(
            children: [
              if (widget.lockId == null) ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedLockId,
                    onChanged: (value) => setState(() => _selectedLockId = value),
                    items: locks
                        .map(
                          (lock) => DropdownMenuItem<String>(
                            value: lock.id,
                            child: Text(lock['name'] ?? 'Unknown Lock'),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const Divider(height: 1),
              ],
              Expanded(
                child: _selectedLockId != null
                    ? AccessLogView(lockId: _selectedLockId!)
                    : const Center(child: Text('Select a lock to view logs')),
              ),
            ],
          );
        },
      ),
    );
  }
}
