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
  final bool showSettingsAction;
  final VoidCallback? onSettings;
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
    this.showSettingsAction = true,
    this.onSettings,
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
          IconButton(
            icon: const Icon(Icons.library_music_rounded),
            onPressed: onSearch,
          ),

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

        _TopBarOverflowMenu(
          showWorldModeAction: showWorldModeAction,
          onWorldMode: onWorldMode,
          showLocalConnectAction: showLocalConnectAction,
          onLocalConnect: onLocalConnect,
          showSettingsAction: showSettingsAction,
          onSettings: onSettings,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

enum _TopBarMenuAction { worldMode, localConnect, settings }

class _TopBarOverflowMenu extends StatelessWidget {
  const _TopBarOverflowMenu({
    required this.showWorldModeAction,
    required this.onWorldMode,
    required this.showLocalConnectAction,
    required this.onLocalConnect,
    required this.showSettingsAction,
    required this.onSettings,
  });

  final bool showWorldModeAction;
  final VoidCallback? onWorldMode;
  final bool showLocalConnectAction;
  final VoidCallback? onLocalConnect;
  final bool showSettingsAction;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final entries = <PopupMenuEntry<_TopBarMenuAction>>[
      if (showWorldModeAction)
        const PopupMenuItem<_TopBarMenuAction>(
          value: _TopBarMenuAction.worldMode,
          child: _TopBarMenuItemRow(
            icon: Icons.public_rounded,
            label: 'Listenfy Atlas',
          ),
        ),
      if (showLocalConnectAction)
        const PopupMenuItem<_TopBarMenuAction>(
          value: _TopBarMenuAction.localConnect,
          child: _TopBarMenuItemRow(
            icon: Icons.cast_connected_rounded,
            label: 'Listenfy Local Connect',
          ),
        ),
      if (showSettingsAction && (showWorldModeAction || showLocalConnectAction))
        const PopupMenuDivider(height: 8),
      if (showSettingsAction)
        const PopupMenuItem<_TopBarMenuAction>(
          value: _TopBarMenuAction.settings,
          child: _TopBarMenuItemRow(icon: Icons.settings, label: 'Ajustes'),
        ),
    ];

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<_TopBarMenuAction>(
      tooltip: 'Más opciones',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        switch (value) {
          case _TopBarMenuAction.worldMode:
            (onWorldMode ?? () => Get.toNamed(AppRoutes.worldMode)).call();
            break;
          case _TopBarMenuAction.localConnect:
            (onLocalConnect ?? () => Get.toNamed(AppRoutes.localConnect))
                .call();
            break;
          case _TopBarMenuAction.settings:
            (onSettings ?? () => Get.toNamed(AppRoutes.settings)).call();
            break;
        }
      },
      itemBuilder: (context) => entries,
    );
  }
}

class _TopBarMenuItemRow extends StatelessWidget {
  const _TopBarMenuItemRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
    );
  }
}
