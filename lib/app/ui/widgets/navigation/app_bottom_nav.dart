import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final navBg = scheme.surface.withValues(alpha: isDark ? 0.94 : 0.98);
    final dividerColor = scheme.outline.withValues(alpha: isDark ? 0.24 : 0.14);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.18 : 0.06);

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

          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.queue_music_outlined),
              activeIcon: Icon(Icons.queue_music),
              label: 'Playlists',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Artists',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.download_outlined),
              activeIcon: Icon(Icons.download),
              label: 'Imports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.source_outlined),
              activeIcon: Icon(Icons.source),
              label: 'Sources',
            ),
          ],
        ),
      ),
    );
  }
}
