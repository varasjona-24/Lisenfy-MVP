import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';

import '../../Home/Controller/home_controller.dart';
import '../controller/sources_controller.dart';
import '../domain/source_theme.dart';

import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/ui/widgets/player/continue_video_card.dart';

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
        extraActions: [
          IconButton(
            tooltip: tr('sources.captures'),
            icon: const Icon(Icons.photo_library_rounded),
            onPressed: () async {
              await Get.toNamed(AppRoutes.captureGallery);
              await controller.refreshAll();
            },
          ),
        ],
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
                        const ContinueVideoCard(),
                        _header(theme: theme, scheme: scheme),
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

  Widget _header({required ThemeData theme, required ColorScheme scheme}) {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('sources.title'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              tr('sources.subtitle'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.46),
            ),
            const SizedBox(height: 14),
            _SourcesHeaderStats(
              categories: controller.themes.length,
              sections: controller.topics.length,
              lists: controller.topicPlaylists.length,
              captures: controller.captureCount.value,
            ),
          ],
        ),
      );
    });
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
        currentIndex: 5,
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
              home.goToAtlas();
              break;
            case 4:
              home.goToDownloads();
              break;
            case 5:
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

class _SourcesHeaderStats extends StatelessWidget {
  const _SourcesHeaderStats({
    required this.categories,
    required this.sections,
    required this.lists,
    required this.captures,
  });

  final int categories;
  final int sections;
  final int lists;
  final int captures;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SourceInfoMetric(
              icon: Icons.dashboard_customize_rounded,
              value: categories,
              label: tr('sources.metric_categories'),
            ),
          ),
          Expanded(
            child: _SourceInfoMetric(
              icon: Icons.folder_special_rounded,
              value: sections,
              label: tr('sources.metric_sections'),
            ),
          ),
          Expanded(
            child: _SourceInfoMetric(
              icon: Icons.queue_music_rounded,
              value: lists,
              label: tr('sources.metric_lists'),
            ),
          ),
          Expanded(
            child: _SourceInfoMetric(
              icon: Icons.photo_camera_rounded,
              value: captures,
              label: tr('sources.metric_captures'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceInfoMetric extends StatelessWidget {
  const _SourceInfoMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: scheme.onSurface),
        const SizedBox(height: 6),
        Text(
          NumberFormat.compact(
            locale: context.locale.toLanguageTag(),
          ).format(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
        ? 'Video'
        : theme.forceKind?.name == 'video'
        ? 'Video'
        : theme.forceKind?.name == 'audio'
        ? 'Audio'
        : tr('sources.mixed');

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
