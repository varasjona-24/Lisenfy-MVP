import 'package:flutter/material.dart';
import '../dialogs/sort_options_sheet.dart';

/// A single, full-width selection field shared by app preferences.
class AppOptionSelector<T> extends StatelessWidget {
  const AppOptionSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.icon,
    required this.title,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final IconData icon;
  final String title;

  Future<void> _openOptions(BuildContext context) async {
    final theme = Theme.of(context);
    final selected = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              for (final option in options.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SortOptionTile(
                    icon: icon,
                    label: option.value,
                    selected: option.key == value,
                    onTap: () => Navigator.of(sheetContext).pop(option.key),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (context.mounted && selected != null && selected != value) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openOptions(context),
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 22),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    options[value] ?? '',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
