import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../home/controller/home_controller.dart';
import '../controller/sources_controller.dart';
import '../domain/source_theme.dart';

import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/routes/app_routes.dart';

// ============================
// 🧭 PAGE: SOURCES
// ============================
class SourcesPage extends GetView<SourcesController> {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final HomeController home = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      appBar: AppTopBar(
        title: ListenfyLogo(size: 28, color: scheme.primary),
        showLocalConnectAction: false,
      ),
      body: AppGradientBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                onRefresh: controller.refreshAll,
                child: ScrollConfiguration(
                  behavior: const _NoGlowScrollBehavior(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: kBottomNavigationBarHeight + 18,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(theme: theme, scheme: scheme, home: home),
                        const SizedBox(height: AppSpacing.lg),

                        ..._themeSections(
                          theme: theme,
                          themes: controller.themes,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            _bottomNav(home: home),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // UI SECTIONS
  // ===========================================================================

  Widget _header({
    required ThemeData theme,
    required ColorScheme scheme,
    required HomeController home,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Fuentes',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Explora tu contenido organizado por temáticas.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  List<Widget> _themeSections({
    required ThemeData theme,
    required List<SourceTheme> themes,
  }) {
    return [
      for (final t in themes) ...[
        _ThemeCard(theme: t, onOpen: () => _openTheme(t)),
        const SizedBox(height: AppSpacing.lg),
      ],
    ];
  }

  Widget _bottomNav({required HomeController home}) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AppBottomNav(
        currentIndex: 4,
        onTap: (index) {
          switch (index) {
            case 0:
              home.enterHome();
              break;
            case 1:
              home.goToPlaylists();
              break;
            case 2:
              home.goToArtists();
              break;
            case 3:
              home.goToDownloads();
              break;
            case 4:
              home.goToSources();
              break;
          }
        },
      ),
    );
  }

  // ===========================================================================
  // ACTIONS
  // ===========================================================================

  void _openTheme(SourceTheme theme) {
    final origins = theme.defaultOrigins;
    Get.toNamed(
      AppRoutes.sourceLibrary,
      arguments: {
        'title': theme.title,
        'onlyOffline': theme.onlyOffline,
        'origins': origins.isNotEmpty ? origins : null,
        'forceKind': theme.forceKind,
        'themeId': theme.id,
      },
    );
  }
}

class _ThemeCard extends StatefulWidget {
  const _ThemeCard({required this.theme, required this.onOpen});

  final SourceTheme theme;
  final VoidCallback onOpen;

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final theme = widget.theme;
    final textColor = Colors.white;
    final subtitleColor = Colors.white.withValues(alpha: 0.84);
    final cardScale = _isPressed ? 0.985 : (_isHovered ? 1.01 : 1.0);
    final mediaTag = theme.onlyOffline
        ? 'Audio y video'
        : theme.forceKind?.name == 'video'
        ? 'Video'
        : theme.forceKind?.name == 'audio'
        ? 'Audio'
        : 'Mixto';

    return AnimatedScale(
      scale: cardScale,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onOpen();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: theme.colors,
                    stops: const [0.1, 0.9],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colors.last.withValues(
                        alpha: _isHovered ? 0.42 : 0.30,
                      ),
                      blurRadius: _isHovered ? 22 : 16,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.14),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -36,
                      top: -24,
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Icon(
                                  theme.icon,
                                  color: textColor,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  theme.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: themeData.textTheme.titleLarge
                                      ?.copyWith(
                                        color: textColor,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            theme.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: themeData.textTheme.bodyMedium?.copyWith(
                              color: subtitleColor,
                              height: 1.24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ThemeMetaPill(
                                icon: theme.onlyOffline
                                    ? Icons.download_done_rounded
                                    : Icons.play_circle_rounded,
                                label: mediaTag,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeMetaPill extends StatelessWidget {
  const _ThemeMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.92)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
