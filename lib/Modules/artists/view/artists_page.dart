import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/utils/country_catalog.dart';
import '../../../app/routes/app_routes.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import '../controller/artists_controller.dart';
import '../domain/artist_profile.dart';
import '../../edit/controller/edit_entity_controller.dart';
import 'widgets/artist_avatar.dart';

class ArtistsPage extends GetView<ArtistsController> {
  const ArtistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final barBg = Color.alphaBlend(
      scheme.primary.withValues(alpha: isDark ? 0.24 : 0.28),
      scheme.surface,
    );

    final home = Get.find<HomeController>();

    return Obx(() {
      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppTopBar(title: ListenfyLogo(size: 28, color: scheme.primary)),
        body: AppGradientBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: controller.load,
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
                                _header(theme),
                                const SizedBox(height: AppSpacing.md),
                                _recentArtists(theme),
                                const SizedBox(height: AppSpacing.lg),
                                _searchField(theme),
                                const SizedBox(height: AppSpacing.md),
                                _summaryRow(theme, context),
                                const SizedBox(height: AppSpacing.md),
                                _artistList(),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: barBg,
                    border: Border(
                      top: BorderSide(
                        color: scheme.primary.withValues(
                          alpha: isDark ? 0.22 : 0.18,
                        ),
                        width: 56,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: AppBottomNav(
                      currentIndex: 2,
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
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _header(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Artistas',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _searchField(ThemeData theme) {
    return TextField(
      onChanged: controller.setQuery,
      decoration: InputDecoration(
        labelText: 'Buscar artista',
        hintText: 'Nombre, pais o region',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainer,
      ),
    );
  }

  Widget _recentArtists(ThemeData theme) {
    return Obx(() {
      final list = controller.recentArtists;
      if (list.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reproducciones recientes',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 162,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final artist = list[i];
                return _ArtistCoverCard(artist: artist);
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _summaryRow(ThemeData theme, BuildContext context) {
    return Obx(() {
      final count = controller.filtered.length;
      return Row(
        children: [
          Text(
            '$count artistas',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            onPressed: () => _openSortSheet(context),
            tooltip: 'Ordenar',
          ),
        ],
      );
    });
  }

  Widget _artistList() {
    return Obx(() {
      final list = controller.filtered;
      if (list.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'No hay artistas disponibles.',
              style: Get.textTheme.bodyMedium?.copyWith(
                color: Get.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      final bands = list
          .where((artist) => artist.kind == ArtistProfileKind.band)
          .toList(growable: false);
      final singers = list
          .where((artist) => artist.kind != ArtistProfileKind.band)
          .toList(growable: false);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bands.isNotEmpty) ...[
            _ArtistSectionHeader(
              title: 'Bandas',
              count: bands.length,
              minimized: controller.bandsMinimized.value,
              onToggle: controller.toggleBandsMinimized,
            ),
            const SizedBox(height: 8),
            if (!controller.bandsMinimized.value)
              for (final artist in bands) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ArtistCard(
                    artist: artist,
                    onOpen: () => Get.toNamed(
                      AppRoutes.artistDetail,
                      arguments: artist.key,
                    ),
                    onEdit: () => Get.toNamed(
                      AppRoutes.editEntity,
                      arguments: EditEntityArgs.artist(artist),
                    ),
                  ),
                ),
              ],
          ],
          if (singers.isNotEmpty) ...[
            if (bands.isNotEmpty) const SizedBox(height: 8),
            _ArtistSectionHeader(
              title: 'Cantantes',
              count: singers.length,
              minimized: controller.singersMinimized.value,
              onToggle: controller.toggleSingersMinimized,
            ),
            const SizedBox(height: 8),
            if (!controller.singersMinimized.value)
              for (final artist in singers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ArtistCard(
                    artist: artist,
                    onOpen: () => Get.toNamed(
                      AppRoutes.artistDetail,
                      arguments: artist.key,
                    ),
                    onEdit: () => Get.toNamed(
                      AppRoutes.editEntity,
                      arguments: EditEntityArgs.artist(artist),
                    ),
                  ),
                ),
          ],
        ],
      );
    });
  }

  Future<void> _openSortSheet(BuildContext context) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Obx(() {
          final sort = controller.sort.value;
          final asc = controller.sortAscending.value;

          return SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              minChildSize: 0.4,
              initialChildSize: 0.72,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    Text(
                      'Ordenar por',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SortOption(
                      label: 'Nombre del artista',
                      selected: sort == ArtistSort.name,
                      onTap: () => controller.setSort(ArtistSort.name),
                    ),
                    _SortOption(
                      label: 'Número de canciones',
                      selected: sort == ArtistSort.count,
                      onTap: () => controller.setSort(ArtistSort.count),
                    ),
                    _SortOption(
                      label: 'Aleatorio',
                      selected: sort == ArtistSort.random,
                      onTap: () => controller.setSort(ArtistSort.random),
                    ),
                    const Divider(height: 28),
                    _SortOption(
                      label: 'Tamaño más a menos',
                      selected: !asc,
                      onTap: () => controller.setSortAscending(false),
                    ),
                    _SortOption(
                      label: 'Tamaño menos a más',
                      selected: asc,
                      onTap: () => controller.setSortAscending(true),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Aceptar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        });
      },
    );
  }
}

class _ArtistSectionHeader extends StatelessWidget {
  const _ArtistSectionHeader({
    required this.title,
    required this.count,
    required this.minimized,
    required this.onToggle,
  });

  final String title;
  final int count;
  final bool minimized;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            '$title ($count)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onToggle,
          icon: Icon(
            minimized ? Icons.expand_more_rounded : Icons.expand_less_rounded,
            size: 18,
          ),
          label: Text(minimized ? 'Mostrar' : 'Minimizar'),
          style: TextButton.styleFrom(
            foregroundColor: scheme.primary,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

class _ArtistCard extends StatelessWidget {
  const _ArtistCard({
    required this.artist,
    required this.onOpen,
    required this.onEdit,
  });

  final ArtistGroup artist;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final thumb = artist.thumbnailLocalPath ?? artist.thumbnail;
    final country = (artist.country ?? '').trim();
    final flag = CountryCatalog.flagFromIso(artist.countryCode);
    final typeLabel = artist.kind == ArtistProfileKind.band
        ? 'Banda'
        : 'Cantante';
    final typeCountryLine = country.isNotEmpty
        ? '$typeLabel - ${flag.isEmpty ? country : '$flag $country'}'
        : typeLabel;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: ArtistAvatar(thumb: thumb, radius: 24),
        title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(typeCountryLine, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              '${artist.count} canciones',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_rounded),
          onPressed: onEdit,
        ),
        onTap: onOpen,
      ),
    );
  }
}

class _ArtistCoverCard extends StatelessWidget {
  const _ArtistCoverCard({required this.artist});

  final ArtistGroup artist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final thumb = artist.thumbnailLocalPath ?? artist.thumbnail;
    final country = (artist.country ?? '').trim();
    final flag = CountryCatalog.flagFromIso(artist.countryCode);
    final typeLabel = artist.kind == ArtistProfileKind.band
        ? 'Banda'
        : 'Cantante';
    final typeCountryLine = country.isNotEmpty
        ? '$typeLabel - ${flag.isEmpty ? country : '$flag $country'}'
        : typeLabel;

    final imageProvider = (thumb != null && thumb.isNotEmpty)
        ? (thumb.startsWith('http')
              ? NetworkImage(thumb)
              : FileImage(File(thumb)) as ImageProvider)
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Get.toNamed(AppRoutes.artistDetail, arguments: artist.key),
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                image: imageProvider != null
                    ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                    : null,
              ),
              child: imageProvider == null
                  ? Icon(Icons.person_rounded, color: scheme.onSurfaceVariant)
                  : null,
            ),
            const SizedBox(height: 6),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              typeCountryLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
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

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: selected ? scheme.primary : scheme.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      onTap: onTap,
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
