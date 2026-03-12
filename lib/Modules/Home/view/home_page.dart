import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_listenfy/Modules/home/controller/home_controller.dart';
import '../../../app/models/media_item.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/list/media_horizontal_list.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/routes/app_routes.dart';

import '../../../app/ui/widgets/layout/app_gradient_background.dart';

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
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.only(
                              top: AppSpacing.md,

                              // ✅ espacio real para que nada quede debajo del nav
                              // - BottomNavigationBarHeight: altura base
                              // - safeBottom: notch iOS
                              // - 18: aire extra visual
                              bottom:
                                  kBottomNavigationBarHeight + safeBottom + 18,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ---- Favoritos ----
                                if (controller.favorites.isNotEmpty) ...[
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
                                        'onItemLongPress': (item, _) =>
                                            actions.showItemActions(
                                              context,
                                              item,
                                              onChanged: controller.loadHome,
                                            ),
                                        'onShuffle': (queue) => controller
                                            .openMedia(queue.first, 0, queue),
                                      },
                                    ),
                                    onItemTap: (item, index) {
                                      final fullQueue =
                                          controller.fullFavorites;
                                      final fullIndex = fullQueue.indexWhere(
                                        (e) => e.id == item.id,
                                      );
                                      controller.openMedia(
                                        item,
                                        fullIndex < 0 ? 0 : fullIndex,
                                        fullQueue,
                                      );
                                    },
                                    onItemLongPress: (item, _) {
                                      actions.showItemActions(
                                        context,
                                        item,
                                        onChanged: controller.loadHome,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                // ---- Para ti hoy ----
                                if (mode == HomeMode.audio &&
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
                                        'itemHintBuilder':
                                            controller.recommendationHintFor,
                                        'onItemTap': (item, index) =>
                                            controller.openMedia(
                                              item,
                                              index,
                                              controller.fullRecommended,
                                            ),
                                        'onItemLongPress': (item, _) =>
                                            actions.showItemActions(
                                              context,
                                              item,
                                              onChanged: controller.loadHome,
                                            ),
                                        'onShuffle': (queue) => controller
                                            .openMedia(queue.first, 0, queue),
                                      },
                                    ),
                                    trailing: IconButton(
                                      splashRadius: 18,
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 20,
                                      ),
                                      onPressed:
                                          controller
                                              .canRecommendationRefresh
                                              .value
                                          ? controller.refreshRecommendations
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (controller.isRecommendationsLoading.value)
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
                                      collections:
                                          controller.recommendationCollections,
                                      onTap: (collection, _) {
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
                                            'onItemLongPress': (item, _) =>
                                                actions.showItemActions(
                                                  context,
                                                  item,
                                                  onChanged:
                                                      controller.loadHome,
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
                                if (controller.mostPlayed.isNotEmpty) ...[
                                  _SectionHeader(
                                    title: 'Más reproducido',
                                    onTap: () => Get.toNamed(
                                      AppRoutes.homeSectionList,
                                      arguments: {
                                        'title': 'Más reproducido',
                                        'items': controller.fullMostPlayed,
                                        'onItemTap': (item, index) =>
                                            controller.openMedia(
                                              item,
                                              index,
                                              controller.fullMostPlayed,
                                            ),
                                        'onItemLongPress': (item, _) =>
                                            actions.showItemActions(
                                              context,
                                              item,
                                              onChanged: controller.loadHome,
                                            ),
                                        'onShuffle': (queue) => controller
                                            .openMedia(queue.first, 0, queue),
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _MostPlayedRow(
                                    items: controller.mostPlayed,
                                    onTap: (item, index) {
                                      final fullQueue =
                                          controller.fullMostPlayed;
                                      final fullIndex = fullQueue.indexWhere(
                                        (e) => e.id == item.id,
                                      );
                                      controller.openMedia(
                                        item,
                                        fullIndex < 0 ? 0 : fullIndex,
                                        fullQueue,
                                      );
                                    },
                                    onLongPress: (item, _) {
                                      actions.showItemActions(
                                        context,
                                        item,
                                        onChanged: controller.loadHome,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                // ---- Reproducciones recientes ----
                                if (controller.recentlyPlayed.isNotEmpty)
                                  MediaHorizontalList(
                                    title: 'Reproducciones recientes',
                                    items: controller.recentlyPlayed,
                                    onHeaderTap: () =>
                                        Get.toNamed(AppRoutes.history),
                                    onItemTap: (item, index) {
                                      final fullQueue =
                                          controller.fullRecentlyPlayed;
                                      final fullIndex = fullQueue.indexWhere(
                                        (e) => e.id == item.id,
                                      );
                                      controller.openMedia(
                                        item,
                                        fullIndex < 0 ? 0 : fullIndex,
                                        fullQueue,
                                      );
                                    },
                                    onItemLongPress: (item, _) {
                                      actions.showItemActions(
                                        context,
                                        item,
                                        onChanged: controller.loadHome,
                                      );
                                    },
                                  ),
                                if (controller.recentlyPlayed.isNotEmpty)
                                  const SizedBox(height: 18),

                                // ---- Destacado ----
                                if (controller.featured.isNotEmpty) ...[
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
                                        'onItemLongPress': (item, _) =>
                                            actions.showItemActions(
                                              context,
                                              item,
                                              onChanged: controller.loadHome,
                                            ),
                                        'onShuffle': (queue) => controller
                                            .openMedia(queue.first, 0, queue),
                                      },
                                    ),
                                    trailing: null,
                                  ),
                                  const SizedBox(height: 10),
                                  _FeaturedList(
                                    items: controller.featured,
                                    onTap: (item, index) {
                                      final fullQueue = controller.fullFeatured;
                                      final fullIndex = fullQueue.indexWhere(
                                        (e) => e.id == item.id,
                                      );
                                      controller.openMedia(
                                        item,
                                        fullIndex < 0 ? 0 : fullIndex,
                                        fullQueue,
                                      );
                                    },
                                    onLongPress: (item, _) =>
                                        actions.showItemActions(
                                          context,
                                          item,
                                          onChanged: controller.loadHome,
                                        ),
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                // ---- Últimos imports ----
                                if (controller.latestDownloads.isNotEmpty) ...[
                                  MediaHorizontalList(
                                    title: 'Últimos imports',
                                    items: controller.latestDownloads,
                                    onHeaderTap: () => Get.toNamed(
                                      AppRoutes.homeSectionList,
                                      arguments: {
                                        'title': 'Últimos imports',
                                        'items': controller.fullLatestDownloads,
                                        'onItemTap': (item, index) =>
                                            controller.openMedia(
                                              item,
                                              index,
                                              controller.fullLatestDownloads,
                                            ),
                                        'onItemLongPress': (item, _) =>
                                            actions.showItemActions(
                                              context,
                                              item,
                                              onChanged: controller.loadHome,
                                            ),
                                        'onShuffle': (queue) => controller
                                            .openMedia(queue.first, 0, queue),
                                      },
                                    ),
                                    onItemTap: (item, index) {
                                      final fullQueue =
                                          controller.fullLatestDownloads;
                                      final fullIndex = fullQueue.indexWhere(
                                        (e) => e.id == item.id,
                                      );
                                      controller.openMedia(
                                        item,
                                        fullIndex < 0 ? 0 : fullIndex,
                                        fullQueue,
                                      );
                                    },
                                    onItemLongPress: (item, _) {
                                      actions.showItemActions(
                                        context,
                                        item,
                                        onChanged: controller.loadHome,
                                      );
                                    },
                                  ),
                                ],

                                const SizedBox(height: 24),
                              ],
                            ),
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
