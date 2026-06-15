import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../Modules/settings/controller/settings_controller.dart';

class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SettingsController>()) {
      return _buildBackground(context, '');
    }

    final settings = Get.find<SettingsController>();
    return Obx(
      () => _buildBackground(context, settings.appBackgroundImagePath.value),
    );
  }

  Widget _buildBackground(BuildContext context, String imagePath) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final topTint = scheme.primary.withValues(alpha: isDark ? 0.14 : 0.06);
    final midTint = scheme.primary.withValues(alpha: isDark ? 0.24 : 0.16);
    final base = isDark
        ? Color.alphaBlend(
            const Color(0xFF000000).withValues(alpha: 0.60),
            scheme.surface,
          )
        : scheme.surface;

    final hasCustomImage =
        imagePath.trim().isNotEmpty && File(imagePath).existsSync();

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                base,
                Color.alphaBlend(topTint, base),
                Color.alphaBlend(midTint, base),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        if (hasCustomImage)
          Opacity(
            opacity: 0.78,
            child: Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        if (hasCustomImage)
          ColoredBox(
            color: Colors.black.withValues(alpha: isDark ? 0.46 : 0.30),
          ),
        child,
      ],
    );
  }
}
