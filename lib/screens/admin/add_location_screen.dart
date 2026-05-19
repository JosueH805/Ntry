import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ntry_mobile/database/location_helper.dart';
import 'package:ntry_mobile/widgets/location_form_widgets.dart';

class AddLocationScreen extends StatefulWidget {
  final String organization;
  const AddLocationScreen({super.key, required this.organization});

  @override
  State<AddLocationScreen> createState() => _AddLocationScreenState();
}

class _AddLocationScreenState extends State<AddLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _maxDurationController = TextEditingController(text: '2');
  final _latController = TextEditingController();
final _lngController = TextEditingController();

  bool _guestPassEnabled = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _maxDurationController.dispose();
    _latController.dispose();
_lngController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    try {
      await LocationHelper().create({
        'name': _nameController.text.trim(),
        'organization': widget.organization,
        'guestPassEnabled': _guestPassEnabled,
        'guestPassMaxDurationHours':
            int.tryParse(_maxDurationController.text.trim()) ?? 2,
        'createdAt': FieldValue.serverTimestamp(),
        'latitude': double.tryParse(_latController.text.trim()),
        'longitude': double.tryParse(_lngController.text.trim()),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Add Location')),
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
                onChanged: (v) => setState(() => _guestPassEnabled = v),
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
              // ── Submit ────────────────────────────────────────────────
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Location'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
