import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/database/location_helper.dart';
import 'package:ntry_mobile/database/lock_helper.dart';
import 'package:ntry_mobile/widgets/lock_form_widgets.dart';

class AddLockScreen extends StatefulWidget {
  const AddLockScreen({super.key});

  @override
  State<AddLockScreen> createState() => _AddLockScreenState();
}

class _AddLockScreenState extends State<AddLockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();
  final _deviceIdController = TextEditingController();

  TextEditingController? _locationFieldController;

  List<LocationOption> _locations = [];
  bool _loading = true;
  bool _submitting = false;
  String _locationText = '';

  bool get _isNewLocation {
    if (_locationText.isEmpty) return false;
    return !_locations.any(
      (l) => l.name.toLowerCase() == _locationText.toLowerCase(),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    final org = authServiceInstance.organization;
    if (org == null) {
      setState(() => _loading = false);
      return;
    }

    final locSnap = await LocationHelper().getByOrg(org);
    final locs = locSnap.docs.map((d) {
      final data = d.data();
      return LocationOption(id: d.id, name: data['name'] as String? ?? d.id);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    setState(() {
      _locations = locs;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final adminOrg = authServiceInstance.organization;
    if (adminOrg == null) return;

    final locationText = _locationFieldController?.text.trim() ?? '';
    if (locationText.isEmpty) return;

    setState(() => _submitting = true);

    try {
      // Use existing location doc if name matches, otherwise create a new one.
      final existingLoc = _locations.firstWhere(
        (l) => l.name.toLowerCase() == locationText.toLowerCase(),
        orElse: () => const LocationOption(id: '', name: ''),
      );

      final String locationId;
      if (existingLoc.id.isNotEmpty) {
        locationId = existingLoc.id;
      } else {
        final newLocRef = await LocationHelper().create({
          'name': locationText,
          'organization': adminOrg,
          'guestPassEnabled': true,
          'guestPassMaxDurationHours': 2,
          'createdAt': FieldValue.serverTimestamp(),
        });
        locationId = newLocRef.id;
      }

      await LockHelper().create({
        'name': _nameController.text.trim(),
        'room': _roomController.text.trim(),
        'location': locationText,
        'locationId': locationId,
        'deviceId': _deviceIdController.text.trim(),
        'organization': adminOrg,
        'isLockedDown': false,
        'unlocked': false,
        'status': 'locked',
        'timestamp': FieldValue.serverTimestamp(),
        'last_unlocked': null,
      });

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Lock')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Lock Identity ──────────────────────────────────
                    const LockSectionLabel('Lock Identity'),
                    const SizedBox(height: 12),
                    LockTextField(
                      controller: _nameController,
                      label: 'Lock Name',
                      icon: Icons.label_outline,
                      hintText: 'e.g. Colony A1 — Main Entrance',
                    ),
                    const SizedBox(height: 16),
                    LockTextField(
                      controller: _roomController,
                      label: 'Room',
                      icon: Icons.door_front_door_outlined,
                      hintText: 'e.g. Colony A1',
                    ),

                    // ── Location ───────────────────────────────────────
                    const SizedBox(height: 24),
                    const LockSectionLabel('Location'),
                    const SizedBox(height: 4),
                    Text(
                      'The building or area this lock belongs to (e.g. Smith Hall).',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LocationAutocomplete(
                      locations: _locations,
                      onControllerReady: (c) => _locationFieldController = c,
                      onChanged: (text) =>
                          setState(() => _locationText = text),
                    ),
                    if (_isNewLocation) const NewLocationHint(),

                    // ── Hardware ───────────────────────────────────────
                    const SizedBox(height: 24),
                    const LockSectionLabel('Hardware'),
                    const SizedBox(height: 4),
                    Text(
                      'Enter the M5Stack device ID as registered in Cloud IoT Core.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LockTextField(
                      controller: _deviceIdController,
                      label: 'Device ID',
                      icon: Icons.developer_board_outlined,
                      hintText: 'e.g. m5stack-door-01',
                    ),

                    // ── Submit ─────────────────────────────────────────
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('Add Lock'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
