import 'package:flutter/material.dart';
import 'package:ntry_mobile/database/location_helper.dart';
import 'package:ntry_mobile/widgets/location_form_widgets.dart';

class LocationDetailScreen extends StatefulWidget {
  final String locationId;
  final Map<String, dynamic> initialData;

  const LocationDetailScreen({
    super.key,
    required this.locationId,
    required this.initialData,
  });

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _maxDurationController;

  late String _origName;
  late bool _origGuestPassEnabled;
  late int _origMaxDuration;
  late double? _origLat;
late double? _origLng;

  late bool _guestPassEnabled;
  bool _saving = false;
  bool _isDirty = false;

  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _origName = d['name'] as String? ?? '';
    _origGuestPassEnabled = d['guestPassEnabled'] as bool? ?? false;
    _origMaxDuration = d['guestPassMaxDurationHours'] as int? ?? 2;

    _guestPassEnabled = _origGuestPassEnabled;
    _nameController = TextEditingController(text: _origName);
    _maxDurationController =
        TextEditingController(text: _origMaxDuration.toString());

    _nameController.addListener(_updateDirty);
    _maxDurationController.addListener(_updateDirty);

    _latController = TextEditingController(
      text: (d['latitude'] as double?)?.toString() ?? '',
    );
    _lngController = TextEditingController(
      text: (d['longitude'] as double?)?.toString() ?? '',
);
      _latController.addListener(_updateDirty);
      _lngController.addListener(_updateDirty);

      _origLat = d['latitude'] as double?;
      _origLng = d['longitude'] as double?;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _maxDurationController.dispose();
    _latController.dispose();
    _lngController.dispose();

    super.dispose();
  }

 void _updateDirty() {
  final dirty = _nameController.text != _origName ||
      _guestPassEnabled != _origGuestPassEnabled ||
      (int.tryParse(_maxDurationController.text.trim()) ?? _origMaxDuration) != _origMaxDuration ||
      double.tryParse(_latController.text.trim()) != _origLat ||   
      double.tryParse(_lngController.text.trim()) != _origLng;     
  if (dirty != _isDirty) setState(() => _isDirty = dirty);
}

  void _onGuestPassChanged(bool v) {
    setState(() => _guestPassEnabled = v);
    _updateDirty();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      await LocationHelper().update(widget.locationId, {
  'name': _nameController.text.trim(),
  'guestPassEnabled': _guestPassEnabled,
  'guestPassMaxDurationHours':
      int.tryParse(_maxDurationController.text.trim()) ?? 24,
  'latitude': double.tryParse(_latController.text.trim()),   
  'longitude': double.tryParse(_lngController.text.trim()),  
});

      if (mounted) {
        _origName = _nameController.text.trim();
        _origGuestPassEnabled = _guestPassEnabled;
        _origMaxDuration =
            int.tryParse(_maxDurationController.text.trim()) ?? 24;
        _origLat = double.tryParse(_latController.text.trim());
        _origLng = double.tryParse(_lngController.text.trim());  
        setState(() => _isDirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated successfully.')),
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
      appBar: AppBar(title: const Text('Location Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Identity ──────────────────────────────────────────────
              const LocationSectionLabel('Location Identity'),
              const SizedBox(height: 12),
              LocationNameField(controller: _nameController),

              // ── Guest Pass ────────────────────────────────────────────
              const SizedBox(height: 24),
              const LocationSectionLabel('Guest Pass'),
              LocationGuestPassSwitch(
                value: _guestPassEnabled,
                onChanged: _onGuestPassChanged,
              ),
              if (_guestPassEnabled) ...[
                const SizedBox(height: 12),
                LocationDurationField(controller: _maxDurationController),
              ],
              // ── Coordinates ───────────────────────────────────────────────
              const SizedBox(height: 24),
              const LocationSectionLabel('Coordinates (optional)'),
              const SizedBox(height: 12),
              LocationLatitudeField(controller: _latController, lngController: _lngController),
              const SizedBox(height: 12),
              LocationLongitudeField(controller: _lngController, latController: _latController),

              // ── Save ──────────────────────────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: _isDirty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 32),
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
            ],
          ),
        ),
      ),
    );
  }
}
