import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/dialogs/sort_options_sheet.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/utils/country_catalog.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/controllers/navigation_controller.dart';
import 'package:listenfy/Modules/Home/Controller/home_controller.dart';
import '../controller/artists_controller.dart';
import '../domain/artist_profile.dart';
import '../../edit/controller/edit_entity_controller.dart';
import 'widgets/artist_avatar.dart';

String _localizedArtistCountry(ArtistGroup artist, BuildContext context) {
  final byCode = CountryCatalog.countryNameFromCodeForLocale(
    artist.countryCode,
    context.locale.languageCode,
  );
  if ((byCode ?? '').trim().isNotEmpty) return byCode!.trim();
  return (artist.country ?? '').trim();
}

class ArtistsPage extends GetView<ArtistsController> {
  const ArtistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final home = Get.find<HomeController>();

    return Obx(() {
      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppTopBar(
          title: ListenfyLogo(size: 28, color: scheme.primary),
          extraActions: [
            IconButton(
              tooltip: tr('artists.atlas'),
              icon: const Icon(Icons.public_rounded),
              onPressed: () => Get.toNamed(AppRoutes.worldMode),
            ),
          ],
        ),
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
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.md,
                                  AppSpacing.md,
                                  AppSpacing.md,
                                  AppSpacing.md,
                                ),
                                sliver: SliverList.list(
                                  children: [
                                    _header(theme, context),
                                    const SizedBox(height: AppSpacing.md),
                                    _recentArtists(theme),
                                    const SizedBox(height: AppSpacing.lg),
                                    _searchAndSortRow(theme, context),
                                    const SizedBox(height: AppSpacing.md),
                                  ],
                                ),
                              ),
                              ..._artistSlivers(),
                              const SliverToBoxAdapter(
                                child: SizedBox(
                                  height: kBottomNavigationBarHeight + 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
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
            ],
          ),
        ),
      );
    });
  }

  Widget _header(ThemeData theme, BuildContext context) {
    final scheme = theme.colorScheme;
    final artists = controller.filtered;
    final songIds = <String>{};
    for (final artist in artists) {
      for (final item in artist.items) {
        if (!item.hasAudioLocal) continue;
        final key = item.publicId.trim().isNotEmpty
            ? item.publicId.trim()
            : item.id.trim();
        if (key.isNotEmpty) songIds.add(key);
      }
    }
    final totalSongs = songIds.length;
    final bands = artists
        .where((artist) => artist.kind == ArtistProfileKind.band)
        .length;
    final countries = artists
        .map((artist) => _localizedArtistCountry(artist, context))
        .where((country) => country.trim().isNotEmpty)
        .toSet()
        .length;

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
            tr('artists.title'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            tr('artists.header_subtitle'),
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
          _ArtistsHeaderStats(
            totalArtists: artists.length,
            totalSongs: totalSongs,
            bands: bands,
            countries: countries,
          ),
        ],
      ),
    );
  }

  Widget _searchAndSortRow(ThemeData theme, BuildContext context) {
    return Row(
      children: [
        Expanded(child: _searchField(theme)),
        const SizedBox(width: 10),
        _SearchSortButton(onPressed: () => _openSortSheet(context)),
      ],
    );
  }

  Widget _searchField(ThemeData theme) {
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: TextField(
        onChanged: controller.setQuery,
        decoration: InputDecoration(
          labelText: tr('artists.search_label'),
          hintText: tr('artists.search_hint'),
          prefixIcon: const Icon(Icons.search_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: scheme.primary, width: 1.3),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
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
            tr('artists.recent'),
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

  List<Widget> _artistSlivers() {
    final list = controller.filtered;
    if (list.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                tr('artists.empty'),
                style: Get.textTheme.bodyMedium?.copyWith(
                  color: Get.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ];
    }

    final bands = list
        .where((artist) => artist.kind == ArtistProfileKind.band)
        .toList(growable: false);
    final singers = list
        .where((artist) => artist.kind != ArtistProfileKind.band)
        .toList(growable: false);

    return [
      if (bands.isNotEmpty) ...[
        _artistSectionHeaderSliver(
          title: ArtistProfileKind.band.sectionLabel,
          count: bands.length,
          minimized: controller.bandsMinimized.value,
          onToggle: controller.toggleBandsMinimized,
        ),
        if (!controller.bandsMinimized.value) _artistListSliver(bands),
      ],
      if (singers.isNotEmpty) ...[
        if (bands.isNotEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        _artistSectionHeaderSliver(
          title: ArtistProfileKind.singer.sectionLabel,
          count: singers.length,
          minimized: controller.singersMinimized.value,
          onToggle: controller.toggleSingersMinimized,
        ),
        if (!controller.singersMinimized.value) _artistListSliver(singers),
      ],
    ];
  }

  Widget _artistSectionHeaderSliver({
    required String title,
    required int count,
    required bool minimized,
    required VoidCallback onToggle,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 8),
      sliver: SliverToBoxAdapter(
        child: _ArtistSectionHeader(
          title: title,
          count: count,
          minimized: minimized,
          onToggle: onToggle,
        ),
      ),
    );
  }

  Widget _artistListSliver(List<ArtistGroup> artists) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverList.builder(
        itemCount: artists.length,
        itemBuilder: (context, index) {
          final artist = artists[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ArtistCard(
              artist: artist,
              onOpen: () =>
                  Get.toNamed(AppRoutes.artistDetail, arguments: artist.key),
              onEdit: () => Get.toNamed(
                AppRoutes.editEntity,
                arguments: EditEntityArgs.artist(artist),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openSortSheet(BuildContext context) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nav = Get.isRegistered<NavigationController>()
        ? Get.find<NavigationController>()
        : null;
    nav?.setOverlayOpen(true);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return Obx(() {
          final sort = controller.sort.value;
          final asc = controller.sortAscending.value;
          void pickSort(ArtistSort next) {
            if (sort == next) {
              controller.setSortAscending(!asc);
              return;
            }
            controller.setSort(next);
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('artists.sort_by'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SortOption(
                        icon: Icons.sort_by_alpha_rounded,
                        label: tr('artists.sort_name'),
                        sublabel: _artistDirectionLabel(
                          ArtistSort.name,
                          ascending: sort == ArtistSort.name ? asc : true,
                        ),
                        selected: sort == ArtistSort.name,
                        ascending: sort == ArtistSort.name ? asc : null,
                        onTap: () => pickSort(ArtistSort.name),
                      ),
                      const SizedBox(height: 6),
                      _SortOption(
                        icon: Icons.library_music_rounded,
                        label: tr('artists.sort_song_count'),
                        sublabel: _artistDirectionLabel(
                          ArtistSort.count,
                          ascending: sort == ArtistSort.count ? asc : false,
                        ),
                        selected: sort == ArtistSort.count,
                        ascending: sort == ArtistSort.count ? asc : null,
                        onTap: () => pickSort(ArtistSort.count),
                      ),
                      const SizedBox(height: 6),
                      _SortOption(
                        icon: Icons.equalizer_rounded,
                        label: tr('artists.sort_plays'),
                        sublabel: _artistDirectionLabel(
                          ArtistSort.plays,
                          ascending: sort == ArtistSort.plays ? asc : false,
                        ),
                        selected: sort == ArtistSort.plays,
                        ascending: sort == ArtistSort.plays ? asc : null,
                        onTap: () => pickSort(ArtistSort.plays),
                      ),
                      const SizedBox(height: 6),
                      _SortOption(
                        icon: Icons.history_rounded,
                        label: tr('artists.sort_recent'),
                        sublabel: _artistDirectionLabel(
                          ArtistSort.recent,
                          ascending: sort == ArtistSort.recent ? asc : false,
                        ),
                        selected: sort == ArtistSort.recent,
                        ascending: sort == ArtistSort.recent ? asc : null,
                        onTap: () => pickSort(ArtistSort.recent),
                      ),
                      const SizedBox(height: 6),
                      _SortOption(
                        icon: Icons.flag_rounded,
                        label: tr('artists.sort_country'),
                        sublabel: _artistDirectionLabel(
                          ArtistSort.country,
                          ascending: sort == ArtistSort.country ? asc : true,
                        ),
                        selected: sort == ArtistSort.country,
                        ascending: sort == ArtistSort.country ? asc : null,
                        onTap: () => pickSort(ArtistSort.country),
                      ),
                      const SizedBox(height: 6),
                      _SortOption(
                        icon: Icons.public_rounded,
                        label: tr('artists.sort_region'),
                        sublabel: _artistDirectionLabel(
                          ArtistSort.region,
                          ascending: sort == ArtistSort.region ? asc : true,
                        ),
                        selected: sort == ArtistSort.region,
                        ascending: sort == ArtistSort.region ? asc : null,
                        onTap: () => pickSort(ArtistSort.region),
                      ),
                      const SizedBox(height: 6),
                      _SortOption(
                        icon: Icons.shuffle_rounded,
                        label: tr('artists.sort_random'),
                        sublabel: tr('artists.sort_random'),
                        selected: sort == ArtistSort.random,
                        ascending: null,
                        onTap: () => controller.setSort(ArtistSort.random),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(tr('common.accept')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    ).whenComplete(() => nav?.setOverlayOpen(false));
  }

  String _artistDirectionLabel(ArtistSort sort, {required bool ascending}) {
    return switch (sort) {
      ArtistSort.name ||
      ArtistSort.country ||
      ArtistSort.region => ascending ? 'A-Z' : 'Z-A',
      ArtistSort.recent =>
        ascending
            ? tr('artists.least_recent_first')
            : tr('artists.most_recent_first'),
      ArtistSort.count || ArtistSort.plays =>
        ascending ? tr('artists.low_to_high') : tr('artists.high_to_low'),
      ArtistSort.random => tr('artists.sort_random'),
    };
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              title == ArtistProfileKind.band.sectionLabel
                  ? Icons.groups_rounded
                  : Icons.person_rounded,
              size: 19,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title ($count)',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onToggle,
            icon: Icon(
              minimized ? Icons.expand_more_rounded : Icons.expand_less_rounded,
              size: 18,
            ),
            label: Text(
              minimized ? tr('artists.show') : tr('artists.minimize'),
            ),
            style: TextButton.styleFrom(
              foregroundColor: scheme.primary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSortButton extends StatelessWidget {
  const _SearchSortButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Tooltip(
            message: tr('artists.sort'),
            child: Icon(Icons.sort_rounded, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}

class _ArtistsHeaderStats extends StatelessWidget {
  const _ArtistsHeaderStats({
    required this.totalArtists,
    required this.totalSongs,
    required this.bands,
    required this.countries,
  });

  final int totalArtists;
  final int totalSongs;
  final int bands;
  final int countries;

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
            child: _ArtistInfoMetric(
              icon: Icons.person_outline_rounded,
              value: totalArtists,
              label: tr('artists.metric_artists'),
            ),
          ),
          Expanded(
            child: _ArtistInfoMetric(
              icon: Icons.music_note_rounded,
              value: totalSongs,
              label: tr('artists.metric_songs'),
            ),
          ),
          Expanded(
            child: _ArtistInfoMetric(
              icon: Icons.groups_2_outlined,
              value: bands,
              label: tr('artists.metric_groups'),
            ),
          ),
          Expanded(
            child: _ArtistInfoMetric(
              icon: Icons.public_rounded,
              value: countries,
              label: tr('artists.metric_countries'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistInfoMetric extends StatelessWidget {
  const _ArtistInfoMetric({
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
    final country = _localizedArtistCountry(artist, context);
    final flag = CountryCatalog.flagFromIso(artist.countryCode);
    final typeLabel = artist.kind.label;
    final typeCountryLine = country.isNotEmpty
        ? '$typeLabel - ${flag.isEmpty ? country : '$flag $country'}'
        : typeLabel;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainer.withValues(alpha: 0.78),
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
              tr(
                artist.count == 1 ? 'common.songs.one' : 'common.songs.other',
                args: ['${artist.count}'],
              ),
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
    final country = _localizedArtistCountry(artist, context);
    final flag = CountryCatalog.flagFromIso(artist.countryCode);
    final typeLabel = artist.kind.label;
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
              tr(
                artist.count == 1 ? 'common.songs.one' : 'common.songs.other',
                args: ['${artist.count}'],
              ),
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
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
    this.ascending,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;
  final bool? ascending;

  @override
  Widget build(BuildContext context) {
    return SortOptionTile(
      icon: icon,
      label: label,
      sublabel: sublabel,
      selected: selected,
      ascending: ascending,
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
