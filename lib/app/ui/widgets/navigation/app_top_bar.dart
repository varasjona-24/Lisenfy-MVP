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

class _TopBarMenuEntryData {
  const _TopBarMenuEntryData({
    required this.action,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.tint,
  });

  final _TopBarMenuAction action;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color tint;
}

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final items = <_TopBarMenuEntryData>[
      if (showWorldModeAction)
        _TopBarMenuEntryData(
          action: _TopBarMenuAction.worldMode,
          icon: Icons.public_rounded,
          label: 'Listenfy Atlas',
          subtitle: 'Explorar música por regiones',
          tint: scheme.tertiary,
        ),
      if (showLocalConnectAction)
        _TopBarMenuEntryData(
          action: _TopBarMenuAction.localConnect,
          icon: Icons.cast_connected_rounded,
          label: 'Listenfy Connect',
          subtitle: 'Control remoto y sesión local',
          tint: scheme.primary,
        ),
      if (showSettingsAction)
        _TopBarMenuEntryData(
          action: _TopBarMenuAction.settings,
          icon: Icons.settings_rounded,
          label: 'Ajustes',
          subtitle: 'Preferencias y herramientas',
          tint: scheme.secondary,
        ),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<_TopBarMenuAction>(
      tooltip: 'Más opciones',
      padding: const EdgeInsets.only(right: 6),
      offset: const Offset(0, 10),
      elevation: 10,
      color: scheme.surfaceContainerHigh,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      surfaceTintColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
      icon: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
        ),
        child: Icon(Icons.more_horiz_rounded, color: scheme.onSurface),
      ),
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
      itemBuilder: (context) => [
        PopupMenuItem<_TopBarMenuAction>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          height: 0,
          child: Text(
            'Accesos rápidos',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        ...items.map(
          (item) => PopupMenuItem<_TopBarMenuAction>(
            value: item.action,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: _TopBarMenuItemRow(item: item),
          ),
        ),
      ],
    );
  }
}

class _TopBarMenuItemRow extends StatelessWidget {
  const _TopBarMenuItemRow({required this.item});

  final _TopBarMenuEntryData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item.icon, size: 20, color: item.tint),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
        ),
      ],
    );
  }
}
