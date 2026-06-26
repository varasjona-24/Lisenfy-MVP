import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

// ============================
// 🎨 UI: COLOR PICKER
// ============================
class SourceColorPickerField extends StatelessWidget {
  const SourceColorPickerField({
    super.key,
    required this.color,
    required this.onChanged,
    this.showLabel = true,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(tr('sources.color'), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
        ],
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _colorSlider(
          context,
          label: 'R',
          value: r.toDouble(),
          color: const Color(0xFFE53935),
          onChanged: (v) => onChanged(Color.fromARGB(255, v.round(), g, b)),
        ),
        _colorSlider(
          context,
          label: 'G',
          value: g.toDouble(),
          color: const Color(0xFF43A047),
          onChanged: (v) => onChanged(Color.fromARGB(255, r, v.round(), b)),
        ),
        _colorSlider(
          context,
          label: 'B',
          value: b.toDouble(),
          color: const Color(0xFF1E88E5),
          onChanged: (v) => onChanged(Color.fromARGB(255, r, g, v.round())),
        ),
        const SizedBox(height: 8),
        Text(
          '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
          style: theme.textTheme.labelMedium?.copyWith(color: textColor),
        ),
      ],
    );
  }

  Widget _colorSlider(
    BuildContext context, {
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
            ),
            child: Slider(
              min: 0,
              max: 255,
              divisions: 255,
              value: value,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
