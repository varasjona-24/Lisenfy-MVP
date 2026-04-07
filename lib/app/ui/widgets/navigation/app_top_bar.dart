import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/routes/app_routes.dart';

enum AppMediaMode { audio, video }

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final VoidCallback? onSearch;
  final Widget? leading;
  final VoidCallback? onToggleMode; // ✅ optional
  final VoidCallback? onWorldMode;
  final bool showWorldModeAction;
  final VoidCallback? onLocalConnect;
  final bool showLocalConnectAction;
  final AppMediaMode mode;

  const AppTopBar({
    super.key,
    required this.title,
    this.onSearch,
    this.leading,
    this.onToggleMode, // ✅ no required
    this.onWorldMode,
    this.showWorldModeAction = true,
    this.onLocalConnect,
    this.showLocalConnectAction = true,
    this.mode = AppMediaMode.audio, // ✅ default
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final barColor = theme.appBarTheme.backgroundColor ?? scheme.surface;

    return AppBar(
      backgroundColor: barColor,
      surfaceTintColor: barColor,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: leading,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: const SizedBox.shrink(),
      ),
      title: title,
      actions: [
        if (onSearch != null)
          IconButton(icon: const Icon(Icons.search), onPressed: onSearch),

        if (onToggleMode != null)
          IconButton(
            icon: Icon(
              mode == AppMediaMode.audio
                  ? Icons.music_note_rounded
                  : Icons.play_circle_rounded,
              color: scheme.primary,
            ),
            tooltip: mode == AppMediaMode.audio
                ? 'Modo Audio (tocar para Video)'
                : 'Modo Video (tocar para Audio)',
            onPressed: onToggleMode,
          ),

        if (showWorldModeAction)
          IconButton(
            icon: const Icon(Icons.public_rounded),
            tooltip: 'Listenfy Atlas',
            onPressed: onWorldMode ?? () => Get.toNamed(AppRoutes.worldMode),
          ),

        if (showLocalConnectAction)
          IconButton(
            icon: const Icon(Icons.cast_connected_rounded),
            tooltip: 'Listenfy Local Connect',
            onPressed:
                onLocalConnect ?? () => Get.toNamed(AppRoutes.localConnect),
          ),

        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => Get.toNamed(AppRoutes.settings),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
