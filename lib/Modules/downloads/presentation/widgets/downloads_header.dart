import '../../../../app/ui/widgets/layout/app_library_header.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class DownloadsHeader extends StatelessWidget {
  const DownloadsHeader({super.key, required this.total, this.desktop = false});

  final int total;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (desktop) {
      return AppLibraryHeader(
        title: tr('downloads.title'),
        subtitle: tr('downloads.subtitle'),
        metrics: [
          AppLibraryHeaderMetric(
            icon: Icons.file_download_done_rounded,
            label: '$total ${tr('downloads.metric_imported')}',
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('downloads.title'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            tr('downloads.subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.46),
          ),
          const SizedBox(height: 14),
          _ImportHeaderMetric(
            value: total,
            label: tr('downloads.metric_imported'),
          ),
        ],
      ),
    );
  }
}

class _ImportHeaderMetric extends StatelessWidget {
  const _ImportHeaderMetric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.file_download_done_rounded,
            size: 24,
            color: scheme.onSurface,
          ),
          const SizedBox(height: 6),
          Text(
            NumberFormat.compact(
              locale: context.locale.toLanguageTag(),
            ).format(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
