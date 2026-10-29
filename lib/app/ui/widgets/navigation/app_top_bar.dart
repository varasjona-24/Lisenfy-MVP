import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../app/routes/app_routes.dart';
import '../../../../Modules/stats/presentation/views/weekly_collage_page.dart';

enum AppMediaMode { audio, video }

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final VoidCallback? onSearch;
  final Widget? leading;
  final VoidCallback? onToggleMode; // ✅ optional
  final VoidCallback? onLocalConnect;
  final bool showLocalConnectAction;
  final bool showSettingsAction;
  final VoidCallback? onSettings;
  final AppMediaMode mode;
  final List<Widget> extraActions;

  const AppTopBar({
    super.key,
    required this.title,
    this.onSearch,
    this.leading,
    this.onToggleMode, // ✅ no required
    this.onLocalConnect,
    this.showLocalConnectAction = true,
    this.showSettingsAction = true,
    this.onSettings,
    this.mode = AppMediaMode.audio, // ✅ default
    this.extraActions = const <Widget>[],
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
                ? tr('nav.audio_mode_tooltip')
                : tr('nav.video_mode_tooltip'),
            onPressed: onToggleMode,
          ),

        ...extraActions,

        _TopBarOverflowMenu(
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

  /// Same callbacks as the mobile toolbar, presented inside the desktop rail.
  Widget buildSidebarActions(BuildContext context, {bool compact = false}) {
    Widget action(Widget icon, String label, VoidCallback? onTap) => Tooltip(
      message: label,
      child: compact
          ? IconButton(icon: icon, onPressed: onTap)
          : ListTile(
              leading: SizedBox.square(dimension: 24, child: icon),
              title: Text(label),
              onTap: onTap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
    );
    final destinations = <(IconData, String, String)>[
      (
        Icons.photo_library_outlined,
        tr('sources.captures'),
        AppRoutes.captureGallery,
      ),
      (Icons.history_rounded, tr('history.title'), AppRoutes.downloadsHistory),
      (
        Icons.auto_graph_rounded,
        tr('downloads.wrapped'),
        AppRoutes.listeningStats,
      ),
      (
        Icons.calendar_view_week_rounded,
        tr('weekly_collage.open'),
        '/WeeklyCollagePage',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onSearch != null)
          action(
            const Icon(Icons.library_music_rounded),
            tr(
              mode == AppMediaMode.audio
                  ? 'nav.audio_library'
                  : 'nav.video_library',
            ),
            onSearch,
          ),
        if (onToggleMode != null)
          action(
            Icon(
              mode == AppMediaMode.audio
                  ? Icons.music_note_rounded
                  : Icons.play_circle_rounded,
            ),
            tr(
              mode == AppMediaMode.audio
                  ? 'nav.switch_video'
                  : 'nav.switch_audio',
            ),
            onToggleMode,
          ),
        for (final extra in extraActions)
          if (extra is IconButton &&
              extra.tooltip != tr('downloads.history') &&
              !destinations.any((entry) => entry.$2 == extra.tooltip))
            action(
              extra.icon,
              extra.tooltip ?? tr('nav.quick_access'),
              extra.onPressed,
            )
          else if (extra is! IconButton)
            extra,
        for (final destination in destinations)
          action(Icon(destination.$1), destination.$2, () {
            if (Get.currentRoute == destination.$3) return;
            if (destination.$3 == '/WeeklyCollagePage') {
              Get.to(() => const WeeklyCollagePage());
            } else {
              Get.toNamed(destination.$3);
            }
          }),
        const SizedBox(height: 12),
        _TopBarOverflowMenu(
          showLocalConnectAction: showLocalConnectAction,
          onLocalConnect: onLocalConnect,
          showSettingsAction: showSettingsAction,
          onSettings: onSettings,
          asSidebar: true,
          compact: compact,
        ),
      ],
    );
  }
}

enum _TopBarMenuAction { localConnect, settings }

class _TopBarMenuEntryData {
  const _TopBarMenuEntryData({
    required this.action,
    this.icon,
    this.svgAsset,
    required this.label,
    required this.subtitle,
    required this.tint,
  });

  final _TopBarMenuAction action;
  final IconData? icon;
  final String? svgAsset;
  final String label;
  final String subtitle;
  final Color tint;
}

class _TopBarOverflowMenu extends StatelessWidget {
  const _TopBarOverflowMenu({
    required this.showLocalConnectAction,
    required this.onLocalConnect,
    required this.showSettingsAction,
    required this.onSettings,
    this.asSidebar = false,
    this.compact = false,
  });

  final bool showLocalConnectAction;
  final VoidCallback? onLocalConnect;
  final bool showSettingsAction;
  final VoidCallback? onSettings;
  final bool asSidebar, compact;

  void _select(_TopBarMenuAction value) {
    switch (value) {
      case _TopBarMenuAction.localConnect:
        (onLocalConnect ?? () => Get.toNamed(AppRoutes.localConnect)).call();
      case _TopBarMenuAction.settings:
        (onSettings ?? () => Get.toNamed(AppRoutes.settings)).call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final items = <_TopBarMenuEntryData>[
      if (showLocalConnectAction)
        _TopBarMenuEntryData(
          action: _TopBarMenuAction.localConnect,
          svgAsset: 'assets/logo/listenfy_connect.svg',
          label: tr('nav.listenfy_connect'),
          subtitle: tr('nav.listenfy_connect_subtitle'),
          tint: scheme.primary,
        ),
      if (showSettingsAction)
        _TopBarMenuEntryData(
          action: _TopBarMenuAction.settings,
          icon: Icons.settings_rounded,
          label: tr('nav.settings'),
          subtitle: tr('nav.settings_subtitle'),
          tint: scheme.secondary,
        ),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    if (asSidebar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Tooltip(
                message: item.label,
                child: compact
                    ? IconButton(
                        onPressed: () => _select(item.action),
                        icon: item.svgAsset == null
                            ? Icon(item.icon)
                            : SizedBox.square(
                                dimension: 24,
                                child: SvgPicture.asset(
                                  item.svgAsset!,
                                  colorFilter: ColorFilter.mode(
                                    scheme.onSurfaceVariant,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                      )
                    : ListTile(
                        onTap: () => _select(item.action),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: SizedBox.square(
                          dimension: 24,
                          child: item.svgAsset == null
                              ? Icon(item.icon)
                              : SvgPicture.asset(
                                  item.svgAsset!,
                                  colorFilter: ColorFilter.mode(
                                    scheme.onSurfaceVariant,
                                    BlendMode.srcIn,
                                  ),
                                ),
                        ),
                        title: Text(item.label),
                      ),
              ),
            ),
        ],
      );
    }

    return PopupMenuButton<_TopBarMenuAction>(
      tooltip: tr('nav.more_options'),
      padding: const EdgeInsets.only(right: 6),
      offset: const Offset(0, 10),
      elevation: 10,
      color: scheme.surfaceContainerHigh,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      surfaceTintColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
      icon: Icon(Icons.more_horiz_rounded, color: scheme.onSurface),
      onSelected: _select,
      itemBuilder: (context) => [
        PopupMenuItem<_TopBarMenuAction>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          height: 0,
          child: Text(
            tr('nav.quick_access'),
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
          child: item.svgAsset == null
              ? Icon(item.icon, size: 22, color: item.tint)
              : Center(
                  child: SizedBox.square(
                    dimension: 22,
                    child: SvgPicture.asset(
                      item.svgAsset!,
                      fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(item.tint, BlendMode.srcIn),
                    ),
                  ),
                ),
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
