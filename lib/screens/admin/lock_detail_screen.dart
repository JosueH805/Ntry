import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ntry_mobile/database/location_helper.dart';
import 'package:ntry_mobile/database/lock_helper.dart';
import 'package:ntry_mobile/database/user_helper.dart';
import 'package:ntry_mobile/widgets/lock_access_list.dart';
import 'package:ntry_mobile/widgets/lock_add_user_sheet.dart';
import 'package:ntry_mobile/widgets/lock_form_widgets.dart';
import 'package:ntry_mobile/widgets/lock_status_card.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/theme/app_colors.dart';

class LockDetailScreen extends StatefulWidget {
  final String lockId;
  final Map<String, dynamic> initialData;

  const LockDetailScreen({
    super.key,
    required this.lockId,
    required this.initialData,
  });

  @override
  State<LockDetailScreen> createState() => _LockDetailScreenState();
}

class _LockDetailScreenState extends State<LockDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _roomController;
  late final TextEditingController _deviceIdController;
  TextEditingController? _locationFieldController;

  late String _origName;
  late String _origRoom;
  late String _origLocation;
  late String _origDeviceId;

  String _locationText = '';
  bool get _isNewLocation {
    if (_locationText.isEmpty) return false;
    return !_locations.any(
      (l) => l.name.toLowerCase() == _locationText.toLowerCase(),
    );
  }

  List<LocationOption> _locations = [];
  bool _loadingLocations = true;
  String? _org;

  bool _saving = false;
  bool _isDirty = false;

  late final Stream<List<LockAccessUser>> _usersStream;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _origName = d['name'] as String? ?? '';
    _origRoom = d['room'] as String? ?? '';
    _origLocation = d['location'] as String? ?? '';
    _origDeviceId = d['deviceId'] as String? ?? '';
    _org = d['organization'] as String?;
    _locationText = _origLocation;

    _nameController = TextEditingController(text: _origName);
    _roomController = TextEditingController(text: _origRoom);
    _deviceIdController = TextEditingController(text: _origDeviceId);

    for (final c in [_nameController, _roomController, _deviceIdController]) {
      c.addListener(_updateDirty);
    }

    _loadLocations();
    _usersStream = _buildUsersStream();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    if (_org == null) {
      setState(() => _loadingLocations = false);
      return;
    }
    final snap = await LocationHelper().getByOrg(_org!);
    final locs = snap.docs.map((d) {
      final data = d.data();
      return LocationOption(id: d.id, name: data['name'] as String? ?? d.id);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (mounted) {
      setState(() {
        _locations = locs;
        _loadingLocations = false;
      });
    }
  }

  void _updateDirty() {
    final dirty = _nameController.text != _origName ||
        _roomController.text != _origRoom ||
        _locationText != _origLocation ||
        _deviceIdController.text != _origDeviceId;
    if (dirty != _isDirty) setState(() => _isDirty = dirty);
  }

  Stream<List<LockAccessUser>> _buildUsersStream() {
    return UserHelper()
        .streamUsersByLock(widget.lockId)
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              return LockAccessUser(
                uid: doc.id,
                firstName: data['first_name'] as String? ?? '',
                lastName: data['last_name'] as String? ?? '',
                email: data['email'] as String? ?? '',
                role: data['role'] as String? ?? 'resident',
              );
            }).toList());
  }

  Future<void> _showAddUserSheet() async {
    if (_org == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => LockAddUserSheet(
        lockId: widget.lockId,
        org: _org!,
        onUserAdded: () {},
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final locationText =
        (_locationFieldController?.text.trim() ?? '').isNotEmpty
            ? _locationFieldController!.text.trim()
            : _locationText;
    if (locationText.isEmpty) return;

    setState(() => _saving = true);

    try {
      final existingLoc = _locations.firstWhere(
        (l) => l.name.toLowerCase() == locationText.toLowerCase(),
        orElse: () => const LocationOption(id: '', name: ''),
      );

      final String locationId;
      if (existingLoc.id.isNotEmpty) {
        locationId = existingLoc.id;
      } else {
        final ref = await LocationHelper().create({
          'name': locationText,
          'organization': _org,
          'guestPassEnabled': true,
          'guestPassMaxDurationHours': 24,
          'autoRelockSeconds': 5,
          'createdAt': FieldValue.serverTimestamp(),
        });
        locationId = ref.id;
        _locations.add(LocationOption(id: locationId, name: locationText));
      }

      await LockHelper().update(widget.lockId, {
        'name': _nameController.text.trim(),
        'room': _roomController.text.trim(),
        'location': locationText,
        'locationId': locationId,
        'deviceId': _deviceIdController.text.trim(),
      });

      if (mounted) {
        _origName = _nameController.text.trim();
        _origRoom = _roomController.text.trim();
        _origLocation = locationText;
        _origDeviceId = _deviceIdController.text.trim();
        _locationText = locationText;
        setState(() => _isDirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lock updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lock Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: LockHelper().stream(widget.lockId),
        builder: (context, snapshot) {
          final liveData =
              snapshot.data?.data() as Map<String, dynamic>?;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LockStatusCard(data: liveData ?? widget.initialData),
                      const SizedBox(height: 24),
                      const LockSectionLabel('Lock Details'),
                      const SizedBox(height: 12),
                      _EditForm(
                        formKey: _formKey,
                        nameController: _nameController,
                        roomController: _roomController,
                        deviceIdController: _deviceIdController,
                        locations: _locations,
                        loadingLocations: _loadingLocations,
                        origLocation: _origLocation,
                        isNewLocation: _isNewLocation,
                        onControllerReady: (c) =>
                            _locationFieldController = c,
                        onLocationChanged: (text) {
                          setState(() => _locationText = text);
                          _updateDirty();
                        },
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: _isDirty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _save,
                                    child: _saving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Text('Save Changes'),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 28),
                      const LockSectionLabel('Admin Controls'),
                      const SizedBox(height: 12),
                      _AdminControls(
                        lockId: widget.lockId,
                        isLockedDown: (liveData ??  widget.initialData)['isLockedDown'] as bool? ?? false,
                        ),

                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const LockSectionLabel('Has Access'),
                          TextButton.icon(
                            onPressed: _showAddUserSheet,
                            icon: const Icon(
                                Icons.person_add_outlined, size: 15),
                            label: const Text('Add'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: StreamBuilder<List<LockAccessUser>>(
                  stream: _usersStream,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final users = snap.data ?? [];
                    if (users.isEmpty) {
                      return const SliverToBoxAdapter(
                          child: LockEmptyAccess());
                    }
                    return SliverList.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          LockAccessUserTile(
                        user: users[index],
                        onRemove: () {},
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Edit Form ─────────────────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController roomController;
  final TextEditingController deviceIdController;
  final List<LocationOption> locations;
  final bool loadingLocations;
  final String origLocation;
  final bool isNewLocation;
  final void Function(TextEditingController) onControllerReady;
  final ValueChanged<String> onLocationChanged;

  const _EditForm({
    required this.formKey,
    required this.nameController,
    required this.roomController,
    required this.deviceIdController,
    required this.locations,
    required this.loadingLocations,
    required this.origLocation,
    required this.isNewLocation,
    required this.onControllerReady,
    required this.onLocationChanged,
  });
 

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LockTextField(
            controller: nameController,
            label: 'Lock Name',
            icon: Icons.label_outline,
          ),
          const SizedBox(height: 12),
          LockTextField(
            controller: roomController,
            label: 'Room',
            icon: Icons.door_front_door_outlined,
          ),
          const SizedBox(height: 12),
          if (loadingLocations)
            const Center(child: CircularProgressIndicator())
          else
            LocationAutocomplete(
              locations: locations,
              initialValue: origLocation,
              onControllerReady: onControllerReady,
              onChanged: onLocationChanged,
            ),
          if (isNewLocation) const NewLocationHint(),
          const SizedBox(height: 12),
          LockTextField(
            controller: deviceIdController,
            label: 'Device ID',
            icon: Icons.developer_board_outlined,
          ),
        ],
      ),
    );
  }
}


  // ── Admin Controls ────────────────────────────────────────────────────────────

class _AdminControls extends StatefulWidget {
  final String lockId;
  final bool isLockedDown;

  const _AdminControls({
    required this.lockId,
    required this.isLockedDown,
  });

  @override
  State<_AdminControls> createState() => _AdminControlsState();
}

class _AdminControlsState extends State<_AdminControls> {
  bool _forceUnlocking = false;
  bool _lockdownLoading = false;

  Future<void> _forceUnlock() async {
    final adminUid = authServiceInstance.currentUser?.uid;
    if (adminUid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force Unlock'),
        content: const Text(
          'This will immediately unlock the door, bypassing all resident credentials. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Force Unlock',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _forceUnlocking = true);
    try {
      await LockHelper().forceUnlock(widget.lockId, adminUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Force unlock command sent.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _forceUnlocking = false);
    }
  }

  Future<void> _toggleLockdown() async {
    final adminUid = authServiceInstance.currentUser?.uid;
    if (adminUid == null) return;

    final activating = !widget.isLockedDown;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(activating ? 'Activate Lockdown' : 'Lift Lockdown'),
        content: Text(
          activating
              ? 'This will block ALL entry methods (BLE, QR, manual) until lifted. Continue?'
              : 'This will lift the lockdown and restore normal access. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              activating ? 'Activate' : 'Lift',
              style: TextStyle(
                color: activating ? AppColors.error : AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _lockdownLoading = true);
    try {
      await LockHelper().setLockdown(widget.lockId, adminUid, activating);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activating ? 'Lockdown activated.' : 'Lockdown lifted.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _lockdownLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Force Unlock
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _forceUnlocking ? null : _forceUnlock,
            icon: _forceUnlocking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('Force Unlock'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Lockdown toggle
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _lockdownLoading ? null : _toggleLockdown,
            icon: _lockdownLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    widget.isLockedDown
                        ? Icons.lock_rounded
                        : Icons.shield_outlined,
                    size: 18,
                  ),
            label: Text(
              widget.isLockedDown ? 'Lift Lockdown' : 'Activate Lockdown',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  widget.isLockedDown ? AppColors.elevated : AppColors.error,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
