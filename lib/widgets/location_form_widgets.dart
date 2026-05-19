/// Shared form widgets used by AddLocationScreen and LocationDetailScreen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/widgets/lock_form_widgets.dart';

// ── Section Label ─────────────────────────────────────────────────────────────

class LocationSectionLabel extends StatelessWidget {
  final String text;
  const LocationSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => LockSectionLabel(text);
}

// ── Name Field ────────────────────────────────────────────────────────────────

class LocationNameField extends StatelessWidget {
  final TextEditingController controller;
  const LocationNameField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return LockTextField(
      controller: controller,
      label: 'Location Name',
      icon: Icons.location_on_outlined,
      hintText: 'e.g. Smith Hall, Colony Living Area',
    );
  }
}

// ── Guest Pass Switch ─────────────────────────────────────────────────────────

class LocationGuestPassSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const LocationGuestPassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text(
        'Guest Pass',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        'Allow temporary guest access to locks at this location.',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: colors.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

// ── Duration Field ────────────────────────────────────────────────────────────

class LocationDurationField extends StatelessWidget {
  final TextEditingController controller;
  const LocationDurationField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Max Guest Pass Duration (hours)',
        prefixIcon: Icon(Icons.schedule_outlined),
        hintText: 'e.g. 2',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Required';
        final n = int.tryParse(v.trim());
        if (n == null || n < 1) return 'Must be at least 1';
        return null;
      },
    );
  }
}

//Latitude Field ───────────────────────────────────────────────────────────────
class LocationLatitudeField extends StatelessWidget{
  final TextEditingController controller;
  final TextEditingController lngController;
  const LocationLatitudeField({super.key, required this.controller, required this.lngController});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Latitude',
        prefixIcon: Icon(Icons.my_location_outlined),
        hintText: 'e.g. 37.7749',
      ),
      keyboardType: TextInputType.numberWithOptions(signed: true),
     
      validator: (v) {
        final latFilled = v != null && v.trim().isNotEmpty;
        final lngFilled = lngController.text.trim().isNotEmpty;
        if(!latFilled && lngFilled) return 'Enter latitude or clear longitude';
        if(!latFilled) return null; // Not required if longitude also not filled
        final n = double.tryParse(v.trim());
       if (n == null) return 'Enter a valid number';
        if (n < -90 || n > 90) return 'Must be between -90 and 90';
        return null;
      },  
    );

  }
}

class LocationLongitudeField extends StatelessWidget{
  final TextEditingController controller;
  final TextEditingController latController;
  const LocationLongitudeField({super.key, required this.controller, required this.latController});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Longitude',
        prefixIcon: Icon(Icons.my_location_outlined),
        hintText: 'e.g. -122.4194',
      ),
      keyboardType: TextInputType.numberWithOptions(signed: true),
      
      validator: (v) {
        final lngFilled = v != null && v.trim().isNotEmpty;
        final latFilled = latController.text.trim().isNotEmpty; // ← ADD
        if (!lngFilled && latFilled) return 'Enter longitude or clear latitude'; // ← ADD
        if (!lngFilled) return null;
        final n = double.tryParse(v.trim());
        if (n == null) return 'Enter a valid number';
        if (n < -180 || n > 180) return 'Must be between -180 and 180';
        return null;
      },
    );

  }
}

