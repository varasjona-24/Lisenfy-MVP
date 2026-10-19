import 'package:flutter/material.dart';

/// A single, full-width selection field shared by app preferences.
class AppOptionSelector<T> extends StatelessWidget {
  const AppOptionSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.icon,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InputDecorator(
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: theme.colorScheme.surfaceContainerHigh,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final option in options.entries)
              DropdownMenuItem(value: option.key, child: Text(option.value)),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}
