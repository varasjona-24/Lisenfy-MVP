import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

class CaptureEmptyState extends StatelessWidget {
  const CaptureEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 72,
              color: scheme.onSurfaceVariant.withValues(alpha: .55),
            ),
            const SizedBox(height: 16),
            Text(
              tr('captures.gallery.empty_state'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('captures.gallery.empty_body'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
