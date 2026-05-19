import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/database/lock_helper.dart';
import 'package:ntry_mobile/screens/admin/add_lock_screen.dart';
import 'package:ntry_mobile/screens/admin/lock_detail_screen.dart';

class LockManagementScreen extends StatefulWidget {
  const LockManagementScreen({super.key});

  @override
  State<LockManagementScreen> createState() => _LockManagementScreenState();
}

class _LockManagementScreenState extends State<LockManagementScreen> {
  late Future<List<QueryDocumentSnapshot>> _locksFuture;

  @override
  void initState() {
    super.initState();
    _locksFuture = _fetchLocks();
  }

  Future<List<QueryDocumentSnapshot>> _fetchLocks() async {
    final org = authServiceInstance.organization;
    if (org == null) return [];
    final result = await LockHelper().getByOrg(org);
    return result.docs;
  }

  void _refresh() {
    setState(() {
      _locksFuture = _fetchLocks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Lock Management'), elevation: 2),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
        },
        child: FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _locksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final docs = snapshot.data ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Text('No locks found for this organization.'),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) => _LockTile(doc: docs[index]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddLockScreen()),
          );
          _refresh();
        },
        backgroundColor: colors.primary,
        child: Icon(Icons.add, color: colors.onPrimary),
      ),
    );
  }
}

// ── Lock Tile ─────────────────────────────────────────────────────────────────

class _LockTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;

  const _LockTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final data = doc.data() as Map<String, dynamic>;

    final name = data['name'] as String? ?? 'Unnamed Lock';
    final room = data['room'] as String? ?? 'No Room';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colors.primaryContainer,
        child: Icon(Icons.lock, color: colors.primary),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('Room: $room'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Access Log',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/admin-home/access-log?lockId=${doc.id}'),
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LockDetailScreen(
              lockId: doc.id,
              initialData: data,
            ),
          ),
        );
      },
    );
  }
}
