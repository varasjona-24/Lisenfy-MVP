import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_localization/easy_localization.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool vertical, compact;
  final Widget? header, tools;
  static bool get desktopSidebarEnabled =>
      !kIsWeb &&
      [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ].contains(defaultTargetPlatform);
  static double sidebarWidth(double width) => width >= 1100 ? 264 : 76;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.vertical = false,
    this.compact = false,
    this.header,
    this.tools,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final navBg = scheme.surface.withValues(alpha: isDark ? 0.94 : 0.98);
    final dividerColor = scheme.outline.withValues(alpha: isDark ? 0.24 : 0.14);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.18 : 0.06);

    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home),
        label: tr('nav.home'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.queue_music_outlined),
        activeIcon: const Icon(Icons.queue_music),
        label: tr('nav.playlists'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person),
        label: tr('nav.artists'),
      ),
      BottomNavigationBarItem(
        icon: _AtlasNavigationIcon(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.70 : 0.62),
        ),
        activeIcon: _AtlasNavigationIcon(color: scheme.primary),
        label: tr('nav.atlas'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.download_outlined),
        activeIcon: const Icon(Icons.download),
        label: tr('nav.imports'),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.source_outlined),
        activeIcon: const Icon(Icons.source),
        label: tr('nav.collections'),
      ),
    ];
    if (vertical) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            right: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: .3),
            ),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Theme(
            data: theme.copyWith(
              iconTheme: theme.iconTheme.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              listTileTheme: theme.listTileTheme.copyWith(
                iconColor: scheme.onSurfaceVariant,
                textColor: scheme.onSurfaceVariant,
              ),
              dividerTheme: theme.dividerTheme.copyWith(
                color: scheme.outlineVariant.withValues(alpha: .3),
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 12,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (header != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Center(child: header),
                        ),
                      for (var index = 0; index < items.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Tooltip(
                            message: items[index].label ?? '',
                            child: Material(
                              color: index == currentIndex
                                  ? scheme.primary.withValues(
                                      alpha: isDark ? .14 : .09,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: compact
                                  ? IconButton(
                                      onPressed: () => onTap(index),
                                      icon: SizedBox.square(
                                        dimension: 24,
                                        child: index == currentIndex
                                            ? items[index].activeIcon
                                            : items[index].icon,
                                      ),
                                      color: index == currentIndex
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    )
                                  : ListTile(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      selected: index == currentIndex,
                                      selectedColor: scheme.primary,
                                      leading: SizedBox.square(
                                        dimension: 24,
                                        child: index == currentIndex
                                            ? items[index].activeIcon
                                            : items[index].icon,
                                      ),
                                      title: Text(
                                        items[index].label ?? '',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: index == currentIndex
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                      ),
                                      onTap: () => onTap(index),
                                    ),
                            ),
                          ),
                        ),
                      if (tools != null) ...[const Divider(height: 32), tools!],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(top: BorderSide(color: dividerColor)),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 14,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,

          selectedItemColor: scheme.primary,
          unselectedItemColor: scheme.onSurface.withValues(
            alpha: isDark ? 0.70 : 0.62,
          ),

          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),

          iconSize: 24,

          items: items,
        ),
      ),
    );
  }
}

class _AtlasNavigationIcon extends StatelessWidget {
  const _AtlasNavigationIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: 24,
        child: SvgPicture.asset(
          'assets/logo/listenfy_atlas.svg',
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}
