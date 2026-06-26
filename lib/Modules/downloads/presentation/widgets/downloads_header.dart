import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class DownloadsHeader extends StatelessWidget {
  const DownloadsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('downloads.title'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr('downloads.subtitle'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
