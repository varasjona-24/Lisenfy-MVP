import 'package:flutter/material.dart';

class ChoiceOption {
  const ChoiceOption({required this.value, required this.label});
  final String value;
  final String label;
}

class ChoiceChipRow extends StatelessWidget {
  const ChoiceChipRow({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<ChoiceOption> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.start,
      runAlignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: options.map((o) {
        final selected = selectedValue == o.value;

        return ChoiceChip(
          label: Text(o.label),
          selected: selected,
          onSelected: (s) {
            if (s) onSelected(o.value);
          },
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: .55)
                  : theme.dividerColor.withValues(alpha: .18),
            ),
          ),
          showCheckmark: false,
          avatar: selected
              ? Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                )
              : null,
        );
      }).toList(),
    );
  }
}
