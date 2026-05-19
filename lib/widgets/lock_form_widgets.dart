/// Shared form widgets used by both AddLockScreen and LockDetailScreen.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Data Model ────────────────────────────────────────────────────────────────

class LocationOption {
  final String id;
  final String name;
  const LocationOption({required this.id, required this.name});
}

// ── Section Label ─────────────────────────────────────────────────────────────

class LockSectionLabel extends StatelessWidget {
  final String text;
  const LockSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.0,
      ),
    );
  }
}

// ── Lock Text Field ───────────────────────────────────────────────────────────

/// A standard required TextFormField pre-wired with the app's decoration style.
class LockTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hintText;

  const LockTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
      ),
      textCapitalization: TextCapitalization.words,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}

// ── Location Autocomplete ─────────────────────────────────────────────────────

/// Autocomplete field for selecting or creating a building/area location.
///
/// [onControllerReady] fires inside `fieldViewBuilder` so the parent can
/// capture the inner controller for reading the value on submit/save.
///
/// [onChanged] is called whenever the text changes (typed or selected).
class LocationAutocomplete extends StatelessWidget {
  final List<LocationOption> locations;
  final String? initialValue;
  final void Function(TextEditingController controller) onControllerReady;
  final ValueChanged<String> onChanged;

  const LocationAutocomplete({
    super.key,
    required this.locations,
    required this.onControllerReady,
    required this.onChanged,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Autocomplete<LocationOption>(
      initialValue:
          initialValue != null ? TextEditingValue(text: initialValue!) : null,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return locations;
        final q = textEditingValue.text.toLowerCase();
        return locations.where((l) => l.name.toLowerCase().contains(q));
      },
      displayStringForOption: (o) => o.name,
      onSelected: (option) => onChanged(option.name),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        onControllerReady(controller);
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Building / Area',
            hintText: 'e.g. Colony Living Area, Smith Hall',
            prefixIcon: Icon(Icons.apartment_outlined),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => onChanged(v.trim()),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            color: colors.surfaceContainerHighest,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.apartment_outlined,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            option.name,
                            style: GoogleFonts.inter(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Initials Helper ───────────────────────────────────────────────────────────

/// Returns up to two uppercase initials from [first] and [last].
String lockInitials(String first, String last) {
  final f = first.isNotEmpty ? first[0].toUpperCase() : '';
  final l = last.isNotEmpty ? last[0].toUpperCase() : '';
  final combined = '$f$l'.trim();
  return combined.isNotEmpty ? combined : '?';
}

// ── New Location Hint ─────────────────────────────────────────────────────────

/// Small info row shown when the typed location doesn't match any existing one.
class NewLocationHint extends StatelessWidget {
  const NewLocationHint({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'This will be created as a new location with default settings.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
