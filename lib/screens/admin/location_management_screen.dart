import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/database/location_helper.dart';
import 'package:ntry_mobile/screens/admin/add_location_screen.dart';
import 'package:ntry_mobile/screens/admin/location_detail_screen.dart';

class LocationManagementScreen extends StatelessWidget {
  const LocationManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final adminOrg = authServiceInstance.organization;

    return Scaffold(
      appBar: AppBar(title: const Text('Location Management'), elevation: 2),
      body: adminOrg == null
          ? const Center(child: Text('Organization not found.'))
          : StreamBuilder<QuerySnapshot>(
              stream: LocationHelper().streamByOrg(adminOrg),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading locations.'));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No locations found.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _LocationCard(docId: doc.id, data: data);
                  },
                );
              },
            ),
      floatingActionButton: adminOrg == null
          ? null
          : FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddLocationScreen(organization: adminOrg),
                  ),
                );
              },
              backgroundColor: colors.primary,
              child: Icon(Icons.add, color: colors.onPrimary),
            ),
    );
  }
}

// ── Location Card ──────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _LocationCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = data['name'] as String? ?? 'Unnamed Location';
    final guestPassEnabled = data['guestPassEnabled'] as bool? ?? false;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colors.primaryContainer,
        child: Icon(Icons.location_on, color: colors.primary),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(guestPassEnabled ? 'Guest pass enabled' : 'No guest pass'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LocationDetailScreen(
              locationId: docId,
              initialData: data,
            ),
          ),
        );
      },
    );
  }
}
