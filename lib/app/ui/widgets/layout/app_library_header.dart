import 'package:flutter/material.dart';

/// Shared compact desktop header for library entry pages.
class AppLibraryHeader extends StatelessWidget {
  const AppLibraryHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.metrics,
    this.action,
  });
  final String title, subtitle;
  final List<Widget> metrics;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            ...metrics,
          ],
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final content = action == null
        ? heading
        : LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= 800
                ? Row(
                    children: [
                      Expanded(child: heading),
                      const SizedBox(width: 24),
                      action!,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [heading, const SizedBox(height: 16), action!],
                  ),
          );
    final dark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(
          alpha: dark ? .78 : .84,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: .35),
        ),
      ),
      child: content,
    );
  }
}

class AppLibraryHeaderMetric extends StatelessWidget {
  const AppLibraryHeaderMetric({
    super.key,
    required this.icon,
    required this.label,
  });
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: theme.textTheme.labelLarge)),
        ],
      ),
    );
  }
}
