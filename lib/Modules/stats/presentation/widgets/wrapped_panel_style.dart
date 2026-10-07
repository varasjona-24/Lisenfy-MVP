import 'package:flutter/material.dart';

/// Opaque panels keep wallpaper from changing text/chart contrast.
BoxDecoration wrappedPanelDecoration(
  BuildContext context, {
  bool highlighted = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: scheme.surfaceContainer,
    gradient: highlighted
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.12),
                scheme.surfaceContainer,
              ),
              scheme.surfaceContainer,
            ],
          )
        : null,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: highlighted
          ? scheme.primary.withValues(alpha: 0.35)
          : scheme.outlineVariant,
    ),
  );
}
