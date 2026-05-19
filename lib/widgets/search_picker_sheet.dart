import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PickerOption {
  final String id;
  final String label;
  const PickerOption({required this.id, required this.label});
}

/// A bottom sheet with a searchable autocomplete list.
///
/// Call via [showModalBottomSheet] and await a [PickerOption] return value:
/// ```dart
/// final selected = await showModalBottomSheet<PickerOption>(
///   context: context,
///   isScrollControlled: true,
///   builder: (ctx) => SearchPickerSheet(
///     title: 'Assign Lock',
///     optionsFuture: _fetchLocks(),
///     itemIcon: Icons.lock_outline,
///   ),
/// );
/// ```
class SearchPickerSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String searchHint;
  final IconData itemIcon;

  /// Future that resolves to the list of options to show.
  /// Pass [Future.value(...)] for static lists.
  final Future<List<PickerOption>> optionsFuture;

  final String confirmLabel;

  const SearchPickerSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.searchHint = 'Search...',
    this.itemIcon = Icons.circle_outlined,
    required this.optionsFuture,
    this.confirmLabel = 'Confirm',
  });

  @override
  State<SearchPickerSheet> createState() => _SearchPickerSheetState();
}

class _SearchPickerSheetState extends State<SearchPickerSheet> {
  List<PickerOption> _options = [];
  bool _loading = true;
  PickerOption? _selected;

  @override
  void initState() {
    super.initState();
    widget.optionsFuture.then((options) {
      if (!mounted) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Autocomplete<PickerOption>(
              optionsViewOpenDirection: OptionsViewOpenDirection.up,
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return _options;
                final q = textEditingValue.text.toLowerCase();
                return _options.where(
                  (o) =>
                      o.label.toLowerCase().contains(q) ||
                      o.id.toLowerCase().contains(q),
                );
              },
              displayStringForOption: (o) => o.label,
              onSelected: (option) => setState(() => _selected = option),
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: const Icon(Icons.search_outlined, size: 20),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.bottomLeft,
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    widget.itemIcon,
                                    size: 16,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: GoogleFonts.inter(fontSize: 14),
                                    ),
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
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
              child: Text(widget.confirmLabel),
            ),
          ),
        ],
      ),
    );
  }
}
