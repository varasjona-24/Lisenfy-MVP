import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:listenfy/Modules/Home/Controller/home_controller.dart';
import 'package:listenfy/Modules/recommendations/domain/recommendation_collection.dart';
import '../../../app/models/media_item.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/list/media_horizontal_list.dart';
import '../../../app/ui/widgets/media/media_history_item_tile.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/utils/artist_credit_parser.dart';

import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import 'section_list_page.dart';

part 'widgets/home_editor_widgets.dart';

/// ===============================================================
/// HOME PAGE (corregida)
/// - BottomNav ahora pinta su propio fondo/divider/safeArea
/// - El Scroll deja espacio real (incluye safeArea inferior)
/// - Eliminado DecoratedBox + border gigante (width 56)
/// ===============================================================
class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // ===========================================================
      // 1) Estado del controlador
      // ===========================================================
      final mode = controller.mode.value;
      final actions = Get.find<MediaActionsController>();

      // ===========================================================
      // 2) Theme + safe area (para padding inferior correcto)
      // ===========================================================
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;

      // 👇 Importante en iPhone (notch): esto evita que el contenido
      // quede tapado por el nav + safe area inferior.
      final safeBottom = MediaQuery.of(context).padding.bottom;

      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true, // permite que el fondo pinte debajo del nav
        // ===========================================================
        // 3) AppBar superior (top bar)
        // ===========================================================
        appBar: AppTopBar(
          title: ListenfyLogo(size: 28, color: scheme.primary),
          mode: mode == HomeMode.audio
              ? AppMediaMode.audio
              : AppMediaMode.video,
          onSearch: controller.onSearch,
          onToggleMode: controller.toggleMode,
          extraActions: [
            IconButton(
              tooltip: 'Editar inicio',
              icon: const Icon(Icons.dashboard_customize_rounded),
              onPressed: () => _openHomeEditorSheet(
                context,
                controller: controller,
                mode: mode,
              ),
            ),
          ],
        ),

        // ===========================================================
        // 4) Body con Stack (contenido + bottom nav fijo)
        // ===========================================================
        body: AppGradientBackground(
          child: Stack(
            children: [
              // -------------------------------------------------------
              // A) CONTENIDO (scroll)
              // -------------------------------------------------------
              Positioned.fill(
                child: controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: controller.loadHome,
                        child: ScrollConfiguration(
                          behavior: const _NoGlowScrollBehavior(),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.only(
                                  top: AppSpacing.md,

                                  // ✅ espacio real para que nada quede debajo del nav
                                  // - BottomNavigationBarHeight: altura base
                                  // - safeBottom: notch iOS
                                  // - 18: aire extra visual
                                  bottom:
                                      kBottomNavigationBarHeight +
                                      safeBottom +
                                      18,
                                ),
                                sliver: SliverList.list(
                                  children: [
                                    if (!controller
                                        .usesDefaultHomeWidgetOrder) ...[
                                      _HomeOrderedSections(
                                        controller: controller,
                                        actions: actions,
                                        mode: mode,
                                      ),
                                    ],
                                    // ---- Favoritos ----
                                    if (controller.usesDefaultHomeWidgetOrder &&
                                        controller.enabledHomeWidgets.contains(
                                          HomeWidgetId.favorites,
                                        ) &&
                                        controller.favorites.isNotEmpty) ...[
                                      MediaHorizontalList(
                                        title: 'Mis favoritos',
                                        items: controller.favorites,
                                        onHeaderTap: () => Get.toNamed(
                                          AppRoutes.homeSectionList,
                                          arguments: {
                                            'title': 'Mis favoritos',
                                            'items': controller.fullFavorites,
                                            'onItemTap': (item, index) =>
                                                controller.openMedia(
                                                  item,
                                                  index,
                                                  controller.fullFavorites,
                                                ),
                                            'onItemLongPress':
                                                (
                                                  item,
                                                  _, {
                                                  onStartMultiSelect,
                                                }) => actions.showItemActions(
                                                  context,
                                                  item,
                                                  onChanged:
                                                      controller.loadHome,
                                                  onStartMultiSelect:
                                                      onStartMultiSelect,
                                                ),
                                            'onShuffle': (queue) =>
                                                controller.openMedia(
                                                  queue.first,
                                                  0,
                                                  queue,
                                                ),
                                          },
                                        ),
                                        onItemTap: (item, index) =>
                                            controller.openMedia(
                                              item,
                                              index,
                                              controller.fullFavorites,
                                            ),
                                        onItemLongPress: (item, _, {onStartMultiSelect}) {
                                          actions.showItemActions(
                                            context,
                                            item,
                                            onChanged: controller.loadHome,
                                            onStartMultiSelect: () => Get.toNamed(
                                              AppRoutes.homeSectionList,
                                              arguments: {
                                                'title': 'Mis favoritos',
                                                'items':
                                                    controller.fullFavorites,
                                                'onItemTap': (item, index) =>
                                                    controller.openMedia(
                                                      item,
                                                      index,
                                                      controller.fullFavorites,
                                                    ),
                                                'onItemLongPress':
                                                    (
                                                      item,
                                                      _, {
                                                      onStartMultiSelect,
                                                    }) =>
                                                        actions.showItemActions(
                                                          context,
                                                          item,
                                                          onChanged: controller
                                                              .loadHome,
                                                          onStartMultiSelect:
                                                              onStartMultiSelect,
                                                        ),
                                                'onShuffle': (queue) =>
                                                    controller.openMedia(
                                                      queue.first,
                                                      0,
                                                      queue,
                                                    ),
                                                'startInSelectionMode': true,
                                                'initialSelectionItemId':
                                                    item.id,
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                    ],

                                    // ---- Para ti hoy ----
                                    if (controller.usesDefaultHomeWidgetOrder &&
                                        controller.enabledHomeWidgets.contains(
                                          HomeWidgetId.recommendations,
                                        ) &&
                                        mode == HomeMode.audio &&
                                        (controller
                                                .recommendationCollections
                                                .isNotEmpty ||
                                            controller
                                                .isRecommendationsLoading
                                                .value)) ...[
                                      _SectionHeader(
                                        title: 'Para ti hoy',
                                        onTap: () => Get.toNamed(
                                          AppRoutes.homeSectionList,
                                          arguments: {
                                            'title': 'Para ti hoy',
                                            'items': controller.fullRecommended,
                                            'itemHintBuilder': controller
                                                .recommendationHintFor,
                                            'onItemTap': (item, index) =>
                                                controller.openMedia(
                                                  item,
                                                  index,
                                                  controller.fullRecommended,
                                                ),
                                            'onItemLongPress':
                                                (
                                                  item,
                                                  _, {
                                                  onStartMultiSelect,
                                                }) => actions.showItemActions(
                                                  context,
                                                  item,
                                                  onChanged:
                                                      controller.loadHome,
                                                  onStartMultiSelect:
                                                      onStartMultiSelect,
                                                ),
                                            'onShuffle': (queue) =>
                                                controller.openMedia(
                                                  queue.first,
                                                  0,
                                                  queue,
                                                ),
                                          },
                                        ),
                                        trailing: Text(
                                          controller.recommendationCycleHint,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (controller
                                          .isRecommendationsLoading
                                          .value)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        )
                                      else
                                        _RecommendationCollectionsRow(
                                          collections: controller
                                              .recommendationCollections,
                                          onTap: (collection, _) {
                                            controller
                                                .markRecommendationMixOpened(
                                                  collection,
                                                );
                                            Get.toNamed(
                                              AppRoutes.homeSectionList,
                                              arguments: {
                                                'title': collection.title,
                                                'items': collection.items,
                                                'itemHintBuilder': controller
                                                    .recommendationHintFor,
                                                'onItemTap': (item, index) =>
                                                    controller.openMedia(
                                                      item,
                                                      index,
                                                      collection.items,
                                                    ),
                                                'onItemLongPress':
                                                    (
                                                      item,
                                                      _, {
                                                      onStartMultiSelect,
                                                    }) =>
                                                        actions.showItemActions(
                                                          context,
                                                          item,
                                                          onChanged: controller
                                                              .loadHome,
                                                          onStartMultiSelect:
                                                              onStartMultiSelect,
                                                        ),
                                                'onShuffle': (queue) =>
                                                    controller.openMedia(
                                                      queue.first,
                                                      0,
                                                      queue,
                                                    ),
                                              },
                                            );
                                          },
                                        ),
                                      const SizedBox(height: 18),
                                    ],

                                    // ---- Más reproducido ----
                                    if (controller.usesDefaultHomeWidgetOrder &&
                                        controller.enabledHomeWidgets.contains(
                                          HomeWidgetId.mostPlayed,
                                        ) &&
                                        controller.mostPlayed.isNotEmpty) ...[
                                      _SectionHeader(
                                        title: 'Más reproducido',
                                        onTap: () => Get.toNamed(
                                          AppRoutes.homeSectionList,
                                          arguments: {
                                            'title': 'Más reproducido',
                                            'items': controller.fullMostPlayed,
                                            'itemTrailingBuilder':
                                                (MediaItem item, int _) =>
                                                    _PlayCountPill(item: item),
                                            'onItemTap': (item, index) =>
                                                controller.openMedia(
                                                  item,
                                                  index,
                                                  controller.fullMostPlayed,
                                                ),
                                            'onItemLongPress':
                                                (
                                                  item,
                                                  _, {
                                                  onStartMultiSelect,
                                                }) => actions.showItemActions(
                                                  context,
                                                  item,
                                                  onChanged:
                                                      controller.loadHome,
                                                  onStartMultiSelect:
                                                      onStartMultiSelect,
                                                ),
                                            'onShuffle': (queue) =>
                                                controller.openMedia(
                                                  queue.first,
                                                  0,
                                                  queue,
                                                ),
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _MostPlayedRow(
                                        items: controller.mostPlayed,
                                        onTap: (item, index) =>
                                            controller.openMedia(
                                              item,
                                              index,
                                              controller.fullMostPlayed,
                                            ),
                                        onLongPress: (item, _) {
                                          actions.showItemActions(
                                            context,
                                            item,
                                            onChanged: controller.loadHome,
                                            onStartMultiSelect: () => Get.toNamed(
                                              AppRoutes.homeSectionList,
                                              arguments: {
                                                'title': 'Más reproducido',
                                                'items':
                                                    controller.fullMostPlayed,
                                                'itemTrailingBuilder':
                                                    (MediaItem item, int _) =>
                                                        _PlayCountPill(
                                                          item: item,
                                                        ),
                                                'onItemTap': (item, index) =>
                                                    controller.openMedia(
                                                      item,
                                                      index,
                                                      controller.fullMostPlayed,
                                                    ),
                                                'onItemLongPress':
                                                    (
                                                      item,
                                                      _, {
                                                      onStartMultiSelect,
                                                    }) =>
                                                        actions.showItemActions(
                                                          context,
                                                          item,
                                                          onChanged: controller
                                                              .loadHome,
                                                          onStartMultiSelect:
                                                              onStartMultiSelect,
                                                        ),
                                                'onShuffle': (queue) =>
                                                    controller.openMedia(
                                                      queue.first,
                                                      0,
                                                      queue,
                                                    ),
                                                'startInSelectionMode': true,
                                                'initialSelectionItemId':
                                                    item.id,
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                    ],

                                    // ---- Reproducciones recientes ----
                                    if (controller.usesDefaultHomeWidgetOrder &&
                                        controller.enabledHomeWidgets.contains(
                                          HomeWidgetId.recentlyPlayed,
                                        ) &&
                                        controller.recentlyPlayed.isNotEmpty)
                                      MediaHorizontalList(
                                        title: 'Reproducciones recientes',
                                        items: controller.recentlyPlayed,
                                        onHeaderTap: () => Get.toNamed(
                                          AppRoutes.homeSectionList,
                                          arguments: {
                                            'title': 'Reproducciones recientes',
                                            'items':
                                                controller.fullRecentlyPlayed,
                                            'onItemTap': (item, index) =>
                                                controller.openMedia(
                                                  item,
                                                  index,
                                                  controller.fullRecentlyPlayed,
                                                ),
                                            'onItemLongPress':
                                                (
                                                  item,
                                                  _, {
                                                  onStartMultiSelect,
                                                }) => actions.showItemActions(
                                                  context,
                                                  item,
                                                  onChanged:
                                                      controller.loadHome,
                                                  onStartMultiSelect:
                                                      onStartMultiSelect,
                                                ),
                                            'onShuffle': (queue) =>
                                                controller.openMedia(
                                                  queue.first,
                                                  0,
                                                  queue,
                                                ),
                                          },
                                        ),
                                        onItemTap: (item, index) =>
                                            controller.openMedia(
                                              item,
                                              index,
                                              controller.fullRecentlyPlayed,
                                            ),
                                        onItemLongPress: (item, _, {onStartMultiSelect}) {
                                          actions.showItemActions(
                                            context,
                                            item,
                                            onChanged: controller.loadHome,
                                            onStartMultiSelect: () => Get.toNamed(
                                              AppRoutes.homeSectionList,
                                              arguments: {
                                                'title':
                                                    'Reproducciones recientes',
                                                'items': controller
                                                    .fullRecentlyPlayed,
                                                'onItemTap': (item, index) =>
                                                    controller.openMedia(
                                                      item,
                                                      index,
                                                      controller
                                                          .fullRecentlyPlayed,
                                                    ),
                                                'onItemLongPress':
                                                    (
                                                      item,
                                                      _, {
                                                      onStartMultiSelect,
                                                    }) =>
                                                        actions.showItemActions(
                                                          context,
                                                          item,
                                                          onChanged: controller
                                                              .loadHome,
                                                          onStartMultiSelect:
                                                              onStartMultiSelect,
                                                        ),
                                                'onShuffle': (queue) =>
                                                    controller.openMedia(
                                                      queue.first,
                                                      0,
                                                      queue,
                                                    ),
                                                'startInSelectionMode': true,
                                                'initialSelectionItemId':
                                                    item.id,
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    if (controller.usesDefaultHomeWidgetOrder &&
                                        controller.enabledHomeWidgets.contains(
                                          HomeWidgetId.recentlyPlayed,
                                        ) &&
                                        controller.recentlyPlayed.isNotEmpty)
                                      const SizedBox(height: 18),

                                    // ---- Destacado ----
                                    if (controller.usesDefaultHomeWidgetOrder &&
                                        controller.enabledHomeWidgets.contains(
                                          HomeWidgetId.featured,
                                        ) &&
                                        controller.featured.isNotEmpty) ...[
                                      _SectionHeader(
                                        title: 'Destacado',
                                        onTap: () => Get.toNamed(
                                          AppRoutes.homeSectionList,
                                          arguments: {
                                            'title': 'Destacado',
                                            'items': controller.fullFeatured,
                                            'onItemTap': (item, index) =>
                                                controller.openMedia(
                                                  item,
                                                  index,
                                                  controller.fullFeatured,
                                                ),
                                            'onItemLongPress':
                                                (
                                                  item,
                                                  _, {
                                                  onStartMultiSelect,
                                                }) => actions.showItemActions(
                                                  context,
                                                  item,
                                                  onChanged:
                                                      controller.loadHome,
                                                  onStartMultiSelect:
                                                      onStartMultiSelect,
                                                ),
                                            'onShuffle': (queue) =>
                                                controller.openMedia(
                                                  queue.first,
                                                  0,
                                                  queue,
                                                ),
                                          },
                                        ),
                                        trailing: null,
                                      ),
                                      const SizedBox(height: 10),
                                      _FeaturedList(
                                        items: controller.featured,
                                        onTap: (item, index) =>
                                            controller.openMedia(
                                              item,
                                              index,
                                              controller.fullFeatured,
                                            ),
                                        onLongPress: (item, _) =>
                                            actions.showItemActions(
                                              context,
                                              item,
                                              onChanged: controller.loadHome,
                                              onStartMultiSelect: () => Get.toNamed(
                                                AppRoutes.homeSectionList,
                                                arguments: {
                                                  'title': 'Destacado',
                                                  'items':
                                                      controller.fullFeatured,
                                                  'onItemTap': (item, index) =>
                                                      controller.openMedia(
                                                        item,
                                                        index,
                                                        controller.fullFeatured,
                                                      ),
                                                  'onItemLongPress':
                                                      (
                                                        item,
                                                        _, {
                                                        onStartMultiSelect,
                                                      }) => actions
                                                          .showItemActions(
                                                            context,
                                                            item,
                                                            onChanged:
                                                                controller
                                                                    .loadHome,
                                                            onStartMultiSelect:
                                                                onStartMultiSelect,
                                                          ),
                                                  'onShuffle': (queue) =>
                                                      controller.openMedia(
                                                        queue.first,
                                                        0,
                                                        queue,
                                                      ),
                                                  'startInSelectionMode': true,
                                                  'initialSelectionItemId':
                                                      item.id,
                                                },
                                              ),
                                            ),
                                      ),
                                      const SizedBox(height: 18),
                                    ],

                                    // ---- Últimos imports ----
                                    if (controller.usesDefaultHomeWidgetOrder &&
                                        controller.enabledHomeWidgets.contains(
                                          HomeWidgetId.latestDownloads,
                                        ) &&
                                        controller
                                            .latestDownloads
                                            .isNotEmpty) ...[
                                      MediaHorizontalList(
                                        title: 'Últimos imports',
                                        items: controller.latestDownloads,
                                        onHeaderTap: () => Get.toNamed(
                                          AppRoutes.homeSectionList,
                                          arguments: {
                                            'title': 'Últimos imports',
                                            'items':
                                                controller.fullLatestDownloads,
                                            'onItemTap': (item, index) =>
                                                controller.openMedia(
                                                  item,
                                                  index,
                                                  controller
                                                      .fullLatestDownloads,
                                                ),
                                            'onItemLongPress':
                                                (
                                                  item,
                                                  _, {
                                                  onStartMultiSelect,
                                                }) => actions.showItemActions(
                                                  context,
                                                  item,
                                                  onChanged:
                                                      controller.loadHome,
                                                  onStartMultiSelect:
                                                      onStartMultiSelect,
                                                ),
                                            'onShuffle': (queue) =>
                                                controller.openMedia(
                                                  queue.first,
                                                  0,
                                                  queue,
                                                ),
                                          },
                                        ),
                                        onItemTap: (item, index) =>
                                            controller.openMedia(
                                              item,
                                              index,
                                              controller.fullLatestDownloads,
                                            ),
                                        onItemLongPress: (item, _, {onStartMultiSelect}) {
                                          actions.showItemActions(
                                            context,
                                            item,
                                            onChanged: controller.loadHome,
                                            onStartMultiSelect: () => Get.toNamed(
                                              AppRoutes.homeSectionList,
                                              arguments: {
                                                'title': 'Últimos imports',
                                                'items': controller
                                                    .fullLatestDownloads,
                                                'onItemTap': (item, index) =>
                                                    controller.openMedia(
                                                      item,
                                                      index,
                                                      controller
                                                          .fullLatestDownloads,
                                                    ),
                                                'onItemLongPress':
                                                    (
                                                      item,
                                                      _, {
                                                      onStartMultiSelect,
                                                    }) =>
                                                        actions.showItemActions(
                                                          context,
                                                          item,
                                                          onChanged: controller
                                                              .loadHome,
                                                          onStartMultiSelect:
                                                              onStartMultiSelect,
                                                        ),
                                                'onShuffle': (queue) =>
                                                    controller.openMedia(
                                                      queue.first,
                                                      0,
                                                      queue,
                                                    ),
                                                'startInSelectionMode': true,
                                                'initialSelectionItemId':
                                                    item.id,
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ],

                                    _CustomHomeSections(
                                      controller: controller,
                                      actions: actions,
                                      mode: mode,
                                    ),

                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              // -------------------------------------------------------
              // B) BOTTOM NAV (fijo)
              // - ya pinta su fondo/divider/safeArea internamente
              // -------------------------------------------------------
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomNav(
                  currentIndex: 0,
                  onTap: (index) {
                    switch (index) {
                      case 1:
                        controller.goToPlaylists();
                        break;
                      case 2:
                        controller.goToArtists();
                        break;
                      case 3:
                        controller.goToDownloads();
                        break;
                      case 4:
                        controller.goToSources();
                        break;
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _HomeOrderedSections extends StatelessWidget {
  const _HomeOrderedSections({
    required this.controller,
    required this.actions,
    required this.mode,
  });

  final HomeController controller;
  final MediaActionsController actions;
  final HomeMode mode;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final id in controller.visibleHomeWidgetIdsForMode(mode)) {
      final section = _buildSection(context, id);
      if (section == null) continue;
      children.add(section);
      children.add(const SizedBox(height: 18));
    }
    return Column(children: children);
  }

  Widget? _buildSection(BuildContext context, HomeWidgetId id) {
    switch (id) {
      case HomeWidgetId.favorites:
        return _mediaSection(context, id: id, title: 'Mis favoritos');
      case HomeWidgetId.recommendations:
        if (mode != HomeMode.audio) return null;
        if (controller.recommendationCollections.isEmpty &&
            !controller.isRecommendationsLoading.value) {
          return null;
        }
        return Column(
          children: [
            _SectionHeader(
              title: 'Para ti hoy',
              onTap: () => _openRecommendationList(
                context,
                title: 'Para ti hoy',
                items: controller.fullItemsForHomeWidget(
                  HomeWidgetId.recommendations,
                ),
              ),
              trailing: Text(
                controller.recommendationCycleHint,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (controller.isRecommendationsLoading.value)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _RecommendationCollectionsRow(
                collections: controller.recommendationCollections,
                onTap: (collection, _) {
                  controller.markRecommendationMixOpened(collection);
                  _openRecommendationList(
                    context,
                    title: collection.title,
                    items: collection.items,
                  );
                },
              ),
          ],
        );
      case HomeWidgetId.mostPlayed:
        final mostPlayedItems = controller.fullItemsForHomeWidget(id);
        if (mostPlayedItems.isEmpty) return null;
        return Column(
          children: [
            _SectionHeader(
              title: 'Más reproducido',
              onTap: () => _openList(
                context,
                title: 'Más reproducido',
                items: mostPlayedItems,
                sourceId: HomeWidgetId.mostPlayed,
              ),
            ),
            const SizedBox(height: 10),
            _MostPlayedRow(
              items: mostPlayedItems.take(12).toList(),
              onTap: (item, index) => controller.openMedia(
                item,
                mostPlayedItems.indexOf(item),
                mostPlayedItems,
              ),
              onLongPress: (item, _) {
                actions.showItemActions(
                  context,
                  item,
                  onChanged: controller.loadHome,
                  onStartMultiSelect: () => _openList(
                    context,
                    title: 'Más reproducido',
                    items: mostPlayedItems,
                    sourceId: HomeWidgetId.mostPlayed,
                    initialSelectionItem: item,
                  ),
                );
              },
            ),
          ],
        );
      case HomeWidgetId.recentlyPlayed:
        return _mediaSection(
          context,
          id: id,
          title: 'Reproducciones recientes',
        );
      case HomeWidgetId.continueWatching:
        return _mediaSection(context, id: id, title: 'Seguir viendo');
      case HomeWidgetId.featured:
        return _mediaSection(context, id: id, title: 'Destacado');
      case HomeWidgetId.latestDownloads:
        return _mediaSection(context, id: id, title: 'Últimos imports');
      case HomeWidgetId.notPlayed:
        return _mediaSection(context, id: id, title: 'Por escuchar');
      case HomeWidgetId.randomMix:
        return _mediaSection(context, id: id, title: 'Mix aleatorio');
    }
  }

  Widget? _mediaSection(
    BuildContext context, {
    required HomeWidgetId id,
    required String title,
  }) {
    final full = controller.fullItemsForHomeWidget(id);
    final preview = controller.previewItemsForHomeWidget(id);
    if (preview.isEmpty) return null;
    final isVideoMode = mode == HomeMode.video;
    if (!isVideoMode &&
        controller.layoutForHomeWidgetInMode(id, mode) ==
            HomeCustomSectionLayout.list &&
        !id.hasFixedLayout) {
      return _MediaListSection(
        title: title,
        items: full,
        onHeaderTap: () =>
            _openList(context, title: title, items: full, sourceId: id),
        onTap: (item, index) => controller.openMedia(item, index, full),
        onLongPress: (item, index) {
          actions.showItemActions(
            context,
            item,
            onChanged: controller.loadHome,
            onStartMultiSelect: () => _openList(
              context,
              title: title,
              items: full,
              sourceId: id,
              initialSelectionItem: item,
            ),
          );
        },
      );
    }
    return MediaHorizontalList(
      title: title,
      items: preview,
      cardWidth: isVideoMode ? 178 : 120,
      thumbnailAspectRatio: isVideoMode ? 16 / 9 : 1,
      listHeight: isVideoMode ? 166 : 200,
      itemHintBuilder: id == HomeWidgetId.continueWatching
          ? (item, _) => controller.continueWatchingHintFor(item)
          : null,
      onHeaderTap: () =>
          _openList(context, title: title, items: full, sourceId: id),
      onItemTap: (item, index) => controller.openMedia(item, index, full),
      onItemLongPress: (item, _, {onStartMultiSelect}) {
        actions.showItemActions(
          context,
          item,
          onChanged: controller.loadHome,
          onStartMultiSelect: () => _openList(
            context,
            title: title,
            items: full,
            sourceId: id,
            initialSelectionItem: item,
          ),
        );
      },
    );
  }

  void _openRecommendationList(
    BuildContext context, {
    required String title,
    required List<MediaItem> items,
  }) {
    Get.toNamed(
      AppRoutes.homeSectionList,
      arguments: SectionListRouteData(
        title: title,
        items: items,
        itemHintBuilder: controller.recommendationHintFor,
        onItemTap: (item, index) => controller.openMedia(item, index, items),
        onItemLongPress: (item, _, {onStartMultiSelect}) =>
            actions.showItemActions(
              context,
              item,
              onChanged: controller.loadHome,
              onStartMultiSelect: onStartMultiSelect,
            ),
        onShuffle: (queue) => controller.openMedia(queue.first, 0, queue),
      ),
    );
  }

  void _openList(
    BuildContext context, {
    required String title,
    required List<MediaItem> items,
    HomeWidgetId? sourceId,
    MediaItem? initialSelectionItem,
  }) {
    Get.toNamed(
      AppRoutes.homeSectionList,
      arguments: {
        'title': title,
        'items': items,
        if (sourceId != null) 'sourceId': sourceId,
        if (mode == HomeMode.video) 'rectangularGrid': true,
        if (sourceId == HomeWidgetId.mostPlayed)
          'itemTrailingBuilder': (MediaItem item, int _) =>
              _PlayCountPill(item: item),
        'onItemTap': (item, index) => controller.openMedia(item, index, items),
        'onItemLongPress': (item, _, {onStartMultiSelect}) =>
            actions.showItemActions(
              context,
              item,
              onChanged: controller.loadHome,
              onStartMultiSelect: onStartMultiSelect,
            ),
        'onShuffle': (queue) => controller.openMedia(queue.first, 0, queue),
        if (initialSelectionItem != null) ...{
          'startInSelectionMode': true,
          'initialSelectionItemId': initialSelectionItem.id,
        },
      },
    );
  }
}

class _CustomHomeSections extends StatelessWidget {
  const _CustomHomeSections({
    required this.controller,
    required this.actions,
    required this.mode,
  });

  final HomeController controller;
  final MediaActionsController actions;
  final HomeMode mode;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final sections = mode == HomeMode.video
        ? controller.videoCustomHomeSections
        : controller.customHomeSections;
    for (final section in sections) {
      if (section.kind == HomeCustomSectionKind.collection) {
        final collectionSection = _buildCollectionSection(context, section);
        if (collectionSection == null) continue;
        children.add(collectionSection);
        children.add(const SizedBox(height: 18));
        continue;
      }
      if (section.kind == HomeCustomSectionKind.artist) {
        final artistSection = _buildArtistSection(context, section);
        if (artistSection == null) continue;
        children.add(artistSection);
        children.add(const SizedBox(height: 18));
        continue;
      }
      if (section.kind == HomeCustomSectionKind.playlist) {
        final playlistSection = _buildPlaylistSection(context, section);
        if (playlistSection == null) continue;
        children.add(playlistSection);
        children.add(const SizedBox(height: 18));
        continue;
      }
      final items = controller.resolveCustomSectionItems(section);
      if (items.isEmpty) continue;
      children.add(_buildSection(context, section, items));
      children.add(const SizedBox(height: 18));
    }
    return Column(children: children);
  }

  Widget _buildSection(
    BuildContext context,
    HomeCustomSection section,
    List<MediaItem> items,
  ) {
    if (section.layout == HomeCustomSectionLayout.list) {
      return _CustomHomeListSection(
        section: section,
        items: items,
        onHeaderTap: () => _openList(
          context,
          section.title,
          items,
          itemsRefreshBuilder: () =>
              controller.resolveCustomSectionItems(section),
        ),
        onTap: (item, index) => controller.openMedia(item, index, items),
        onLongPress: (item, index) => actions.showItemActions(
          context,
          item,
          onChanged: controller.loadHome,
          onStartMultiSelect: () => _openList(
            context,
            section.title,
            items,
            itemsRefreshBuilder: () =>
                controller.resolveCustomSectionItems(section),
            initialSelectionItem: item,
          ),
        ),
      );
    }

    return MediaHorizontalList(
      title: section.title,
      headerTrailing: _ModulePill(section: section),
      items: items.take(12).toList(growable: false),
      onHeaderTap: () => _openList(
        context,
        section.title,
        items,
        itemsRefreshBuilder: () =>
            controller.resolveCustomSectionItems(section),
      ),
      onItemTap: (item, index) => controller.openMedia(item, index, items),
      onItemLongPress: (item, _, {onStartMultiSelect}) {
        actions.showItemActions(
          context,
          item,
          onChanged: controller.loadHome,
          onStartMultiSelect: () => _openList(
            context,
            section.title,
            items,
            itemsRefreshBuilder: () =>
                controller.resolveCustomSectionItems(section),
            initialSelectionItem: item,
          ),
        );
      },
    );
  }

  Widget? _buildArtistSection(BuildContext context, HomeCustomSection section) {
    final artists = controller.resolveArtistsForCustomSection(section);
    if (artists.isEmpty) return null;
    void open(HomeArtistChoice artist) {
      Get.toNamed(AppRoutes.artistDetail, arguments: {'artistKey': artist.key});
    }

    void remove(HomeArtistChoice artist) {
      _confirmRemoveCustomItem(
        context: context,
        label: artist.name,
        onConfirm: () {
          controller.removeTargetFromCustomHomeSection(
            sectionId: section.id,
            targetId: artist.key,
          );
        },
      );
    }

    if (section.layout == HomeCustomSectionLayout.list) {
      return _CustomArtistListSection(
        section: section,
        artists: artists,
        onArtistTap: open,
        onArtistLongPress: remove,
      );
    }
    return _CustomArtistCardsSection(
      section: section,
      artists: artists,
      onArtistTap: open,
      onArtistLongPress: remove,
    );
  }

  Widget? _buildPlaylistSection(
    BuildContext context,
    HomeCustomSection section,
  ) {
    final playlists = controller.resolvePlaylistsForCustomSection(section);
    if (playlists.isEmpty) return null;
    void open(HomePlaylistChoice playlist) {
      Get.toNamed(
        AppRoutes.playlistDetail,
        arguments: {'playlistId': playlist.id},
      );
    }

    void remove(HomePlaylistChoice playlist) {
      _confirmRemoveCustomItem(
        context: context,
        label: playlist.name,
        onConfirm: () {
          controller.removeTargetFromCustomHomeSection(
            sectionId: section.id,
            targetId: playlist.id,
          );
        },
      );
    }

    if (section.layout == HomeCustomSectionLayout.list) {
      return _CustomPlaylistListSection(
        section: section,
        playlists: playlists,
        onPlaylistTap: open,
        onPlaylistLongPress: remove,
      );
    }
    return _CustomPlaylistCardsSection(
      section: section,
      playlists: playlists,
      onPlaylistTap: open,
      onPlaylistLongPress: remove,
    );
  }

  Widget? _buildCollectionSection(
    BuildContext context,
    HomeCustomSection section,
  ) {
    final collections = controller.resolveCollectionsForCustomSection(section);
    if (collections.isEmpty) return null;
    void open(HomeCollectionChoice collection) {
      Get.toNamed(
        AppRoutes.sourcePlaylist,
        arguments: {'playlistId': collection.id, 'themeId': collection.themeId},
      );
    }

    void remove(HomeCollectionChoice collection) {
      _confirmRemoveCustomItem(
        context: context,
        label: collection.name,
        onConfirm: () {
          controller.removeTargetFromCustomHomeSection(
            sectionId: section.id,
            targetId: collection.id,
            mode: HomeMode.video,
          );
        },
      );
    }

    return _CustomCollectionCardsSection(
      section: section,
      collections: collections,
      onCollectionTap: open,
      onCollectionLongPress: remove,
    );
  }

  Future<void> _confirmRemoveCustomItem({
    required BuildContext context,
    required String label,
    required VoidCallback onConfirm,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar item'),
        content: Text('¿Desea eliminar "$label" de la lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) onConfirm();
  }

  void _openList(
    BuildContext context,
    String title,
    List<MediaItem> items, {
    List<MediaItem> Function()? itemsRefreshBuilder,
    MediaItem? initialSelectionItem,
  }) {
    Get.toNamed(
      AppRoutes.homeSectionList,
      arguments: {
        'title': title,
        'items': items,
        'onItemTap': (item, index) => controller.openMedia(item, index, items),
        'onItemLongPress': (item, _, {onStartMultiSelect}) =>
            actions.showItemActions(
              context,
              item,
              onChanged: controller.loadHome,
              onStartMultiSelect: onStartMultiSelect,
            ),
        if (itemsRefreshBuilder != null)
          'itemsRefreshBuilder': itemsRefreshBuilder,
        if (initialSelectionItem != null) ...{
          'startInSelectionMode': true,
          'initialSelectionItemId': initialSelectionItem.id,
        },
      },
    );
  }
}

class _CustomHomeListSection extends StatelessWidget {
  const _CustomHomeListSection({
    required this.section,
    required this.items,
    required this.onHeaderTap,
    required this.onTap,
    required this.onLongPress,
  });

  final HomeCustomSection section;
  final List<MediaItem> items;
  final VoidCallback onHeaderTap;
  final void Function(MediaItem item, int index) onTap;
  final void Function(MediaItem item, int index) onLongPress;

  @override
  Widget build(BuildContext context) {
    final preview = items.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: section.title,
          onTap: onHeaderTap,
          trailing: _ModulePill(section: section),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              for (var i = 0; i < preview.length; i++) ...[
                MediaHistoryItemTile(
                  item: preview[i],
                  time: '${i + 1}',
                  onTap: () => onTap(preview[i], i),
                  onLongPress: () => onLongPress(preview[i], i),
                ),
                if (i != preview.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomArtistCardsSection extends StatelessWidget {
  const _CustomArtistCardsSection({
    required this.section,
    required this.artists,
    required this.onArtistTap,
    required this.onArtistLongPress,
  });

  final HomeCustomSection section;
  final List<HomeArtistChoice> artists;
  final void Function(HomeArtistChoice artist) onArtistTap;
  final void Function(HomeArtistChoice artist) onArtistLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: section.title,
          trailing: _ModulePill(section: section),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 152,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            scrollDirection: Axis.horizontal,
            itemCount: artists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _HomeArtistCard(
              artist: artists[index],
              onTap: () => onArtistTap(artists[index]),
              onLongPress: () => onArtistLongPress(artists[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomArtistListSection extends StatelessWidget {
  const _CustomArtistListSection({
    required this.section,
    required this.artists,
    required this.onArtistTap,
    required this.onArtistLongPress,
  });

  final HomeCustomSection section;
  final List<HomeArtistChoice> artists;
  final void Function(HomeArtistChoice artist) onArtistTap;
  final void Function(HomeArtistChoice artist) onArtistLongPress;

  @override
  Widget build(BuildContext context) {
    final preview = artists.take(8).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: section.title,
          trailing: _ModulePill(section: section),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              for (var i = 0; i < preview.length; i++) ...[
                _HomeArtistTile(
                  artist: preview[i],
                  onTap: () => onArtistTap(preview[i]),
                  onLongPress: () => onArtistLongPress(preview[i]),
                ),
                if (i != preview.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomPlaylistCardsSection extends StatelessWidget {
  const _CustomPlaylistCardsSection({
    required this.section,
    required this.playlists,
    required this.onPlaylistTap,
    required this.onPlaylistLongPress,
  });

  final HomeCustomSection section;
  final List<HomePlaylistChoice> playlists;
  final void Function(HomePlaylistChoice playlist) onPlaylistTap;
  final void Function(HomePlaylistChoice playlist) onPlaylistLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: section.title,
          trailing: _ModulePill(section: section),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 152,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            scrollDirection: Axis.horizontal,
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _HomePlaylistCard(
              playlist: playlists[index],
              onTap: () => onPlaylistTap(playlists[index]),
              onLongPress: () => onPlaylistLongPress(playlists[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomPlaylistListSection extends StatelessWidget {
  const _CustomPlaylistListSection({
    required this.section,
    required this.playlists,
    required this.onPlaylistTap,
    required this.onPlaylistLongPress,
  });

  final HomeCustomSection section;
  final List<HomePlaylistChoice> playlists;
  final void Function(HomePlaylistChoice playlist) onPlaylistTap;
  final void Function(HomePlaylistChoice playlist) onPlaylistLongPress;

  @override
  Widget build(BuildContext context) {
    final preview = playlists.take(8).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: section.title,
          trailing: _ModulePill(section: section),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              for (var i = 0; i < preview.length; i++) ...[
                _HomePlaylistTile(
                  playlist: preview[i],
                  onTap: () => onPlaylistTap(preview[i]),
                  onLongPress: () => onPlaylistLongPress(preview[i]),
                ),
                if (i != preview.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CustomCollectionCardsSection extends StatelessWidget {
  const _CustomCollectionCardsSection({
    required this.section,
    required this.collections,
    required this.onCollectionTap,
    required this.onCollectionLongPress,
  });

  final HomeCustomSection section;
  final List<HomeCollectionChoice> collections;
  final void Function(HomeCollectionChoice collection) onCollectionTap;
  final void Function(HomeCollectionChoice collection) onCollectionLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: section.title,
          trailing: _ModulePill(section: section),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            scrollDirection: Axis.horizontal,
            itemCount: collections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _HomeCollectionCard(
              collection: collections[index],
              onTap: () => onCollectionTap(collections[index]),
              onLongPress: () => onCollectionLongPress(collections[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeArtistCard extends StatelessWidget {
  const _HomeArtistCard({
    required this.artist,
    required this.onTap,
    required this.onLongPress,
  });

  final HomeArtistChoice artist;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = _artistImageProvider(artist.thumbnail);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                image: provider != null
                    ? DecorationImage(image: provider, fit: BoxFit.cover)
                    : null,
              ),
              child: provider == null
                  ? Icon(Icons.person_rounded, color: scheme.onSurfaceVariant)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${artist.count} canciones',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePlaylistCard extends StatelessWidget {
  const _HomePlaylistCard({
    required this.playlist,
    required this.onTap,
    required this.onLongPress,
  });

  final HomePlaylistChoice playlist;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = _homeImageProvider(playlist.cover);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                image: provider != null
                    ? DecorationImage(image: provider, fit: BoxFit.cover)
                    : null,
              ),
              child: provider == null
                  ? Icon(
                      Icons.queue_music_rounded,
                      color: scheme.onSurfaceVariant,
                    )
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${playlist.count} canciones',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCollectionCard extends StatelessWidget {
  const _HomeCollectionCard({
    required this.collection,
    required this.onTap,
    required this.onLongPress,
  });

  final HomeCollectionChoice collection;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = _homeImageProvider(collection.cover);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 172,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  image: provider != null
                      ? DecorationImage(image: provider, fit: BoxFit.cover)
                      : null,
                ),
                child: provider == null
                    ? Icon(
                        Icons.video_library_rounded,
                        color: scheme.onSurfaceVariant,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              collection.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${collection.count} items',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeArtistTile extends StatelessWidget {
  const _HomeArtistTile({
    required this.artist,
    required this.onTap,
    required this.onLongPress,
  });

  final HomeArtistChoice artist;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = _artistImageProvider(artist.thumbnail);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: scheme.primaryContainer,
              backgroundImage: provider,
              child: provider == null
                  ? Icon(Icons.person_rounded, color: scheme.onPrimaryContainer)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${artist.count} canciones',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePlaylistTile extends StatelessWidget {
  const _HomePlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onLongPress,
  });

  final HomePlaylistChoice playlist;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = _homeImageProvider(playlist.cover);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                image: provider != null
                    ? DecorationImage(image: provider, fit: BoxFit.cover)
                    : null,
              ),
              child: provider == null
                  ? Icon(
                      Icons.queue_music_rounded,
                      color: scheme.onPrimaryContainer,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${playlist.count} canciones',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ImageProvider? _artistImageProvider(String? raw) {
  return _homeImageProvider(raw);
}

ImageProvider? _homeImageProvider(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  return value.startsWith('http')
      ? NetworkImage(value)
      : FileImage(File(value)) as ImageProvider;
}

class _MediaListSection extends StatelessWidget {
  const _MediaListSection({
    required this.title,
    required this.items,
    required this.onHeaderTap,
    required this.onTap,
    required this.onLongPress,
  });

  final String title;
  final List<MediaItem> items;
  final VoidCallback onHeaderTap;
  final void Function(MediaItem item, int index) onTap;
  final void Function(MediaItem item, int index) onLongPress;

  @override
  Widget build(BuildContext context) {
    final preview = items.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, onTap: onHeaderTap),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              for (var i = 0; i < preview.length; i++) ...[
                MediaHistoryItemTile(
                  item: preview[i],
                  time: '${i + 1}',
                  onTap: () => onTap(preview[i], i),
                  onLongPress: () => onLongPress(preview[i], i),
                ),
                if (i != preview.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ModulePill extends StatelessWidget {
  const _ModulePill({required this.section});

  final HomeCustomSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: section.kind == HomeCustomSectionKind.smart ? null : 34,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(section.kind.icon, size: 14, color: scheme.onPrimaryContainer),
          if (section.kind == HomeCustomSectionKind.smart) ...[
            const SizedBox(width: 4),
            Text(
              section.kind.moduleLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ===============================================================
/// PILL TABS SUPERIORES
/// ===============================================================
class _HomePillTabs extends StatefulWidget {
  @override
  State<_HomePillTabs> createState() => _HomePillTabsState();
}

class _HomePillTabsState extends State<_HomePillTabs> {
  int _selected = 0;
  final _labels = const ['Para ti', 'Canciones', 'Lista de reproducción'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: _labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final selected = _selected == i;

          return ChoiceChip(
            label: Text(_labels[i]),
            selected: selected,
            onSelected: (_) => setState(() => _selected = i),

            // ✅ Contraste correcto
            labelStyle: theme.textTheme.bodyMedium?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),

            selectedColor: scheme.primary,
            backgroundColor: scheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

/// ===============================================================
/// SCROLL SIN GLOW (estilo iOS)
/// ===============================================================
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

/// ===============================================================
/// HEADER DE SECCIÓN (título + chevron o trailing)
/// ===============================================================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing, this.onTap});

  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Row(
          children: [
            Expanded(child: Text(title, style: titleStyle)),
            if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCollectionsRow extends StatelessWidget {
  const _RecommendationCollectionsRow({
    required this.collections,
    required this.onTap,
  });

  final List<RecommendationCollection> collections;
  final void Function(RecommendationCollection collection, int index) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 226,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: collections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final collection = collections[index];
          return _RecommendationCollectionCard(
            collection: collection,
            onTap: () => onTap(collection, index),
          );
        },
      ),
    );
  }
}

class _RecommendationCollectionCard extends StatelessWidget {
  const _RecommendationCollectionCard({
    required this.collection,
    required this.onTap,
  });

  final RecommendationCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = collection.items.take(2).map((e) => e.title).join(' • ');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 232,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _RecommendationCover(item: collection.items.first),
            ),
            const SizedBox(height: 8),
            Text(
              collection.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              collection.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.primary.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${collection.items.length} canciones',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCover extends StatelessWidget {
  const _RecommendationCover({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = item.effectiveThumbnail;
    if (thumb != null && thumb.isNotEmpty) {
      final provider = thumb.startsWith('http')
          ? NetworkImage(thumb)
          : FileImage(File(thumb)) as ImageProvider;
      return Stack(
        children: [
          Image(
            image: provider,
            width: double.infinity,
            height: 108,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(scheme),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.32)],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return _fallback(scheme);
  }

  Widget _fallback(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      height: 108,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        color: scheme.onSurfaceVariant,
        size: 34,
      ),
    );
  }
}

/// ===============================================================
/// FILA "MÁS REPRODUCIDO"
/// ===============================================================
class _MostPlayedRow extends StatelessWidget {
  const _MostPlayedRow({
    required this.items,
    required this.onTap,
    required this.onLongPress,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item, int index) onTap;
  final void Function(MediaItem item, int index) onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final item = items[i];
          final thumb = item.effectiveThumbnail;

          return GestureDetector(
            onTap: () => onTap(item, i),
            onLongPress: () => onLongPress(item, i),
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CircleThumb(thumb: thumb),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.remove_red_eye, size: 14),
                      const SizedBox(width: 4),
                      Text('${item.playCount}'),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ===============================================================
/// THUMB CIRCULAR (con play overlay)
/// ===============================================================
class _CircleThumb extends StatelessWidget {
  const _CircleThumb({required this.thumb});

  final String? thumb;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (thumb != null && thumb!.isNotEmpty) {
      final provider = thumb!.startsWith('http')
          ? NetworkImage(thumb!)
          : FileImage(File(thumb!)) as ImageProvider;

      return Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(radius: 44, backgroundImage: provider),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
          ),
        ],
      );
    }

    return CircleAvatar(
      radius: 44,
      backgroundColor: scheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, color: scheme.onSurfaceVariant),
    );
  }
}

/// ===============================================================
/// LISTA DESTACADO (tiles verticales)
/// ===============================================================
class _FeaturedList extends StatelessWidget {
  const _FeaturedList({
    required this.items,
    required this.onTap,
    required this.onLongPress,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item, int index) onTap;
  final void Function(MediaItem item, int index) onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: List.generate(items.take(6).length, (i) {
        final item = items[i];

        return Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: 10,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onTap(item, i),
            onLongPress: () => onLongPress(item, i),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  _SquareThumb(thumb: item.effectiveThumbnail),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.displaySubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// ===============================================================
/// THUMB CUADRADO
/// ===============================================================
class _SquareThumb extends StatelessWidget {
  const _SquareThumb({required this.thumb});

  final String? thumb;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (thumb != null && thumb!.isNotEmpty) {
      final provider = thumb!.startsWith('http')
          ? NetworkImage(thumb!)
          : FileImage(File(thumb!)) as ImageProvider;

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(image: provider, width: 56, height: 56, fit: BoxFit.cover),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.music_note, color: scheme.onSurfaceVariant),
    );
  }
}

class _PlayCountPill extends StatelessWidget {
  const _PlayCountPill({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = item.playCount == 1
        ? '1 reproducción'
        : '${item.playCount} reproducciones';

    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.remove_red_eye_rounded, size: 15, color: scheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
