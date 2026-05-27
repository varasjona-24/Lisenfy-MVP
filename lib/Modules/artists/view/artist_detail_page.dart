import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/models/media_item.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../../../app/utils/country_catalog.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../controller/artists_controller.dart';
import '../domain/artist_profile.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/media/app_media_items_view.dart';
import 'widgets/artist_avatar.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';

class ArtistDetailPage extends GetView<ArtistsController> {
  const ArtistDetailPage({super.key, required this.artistKey});

  final String artistKey;

  List<MediaItem> _dedupeById(Iterable<MediaItem> input) {
    final out = <MediaItem>[];
    final seen = <String>{};
    for (final item in input) {
      if (!seen.add(item.id)) continue;
      out.add(item);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final home = Get.find<HomeController>();
    final actions = Get.find<MediaActionsController>();

    return Obx(() {
      ArtistGroup? artist;
      for (final entry in controller.artists) {
        if (entry.key == artistKey) {
          artist = entry;
          break;
        }
      }

      if (artist == null) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Artista'),
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            elevation: 0,
          ),
          body: const Center(child: Text('Artista no encontrado')),
        );
      }

      final resolved = artist;
      final artistsByKey = <String, ArtistGroup>{
        for (final entry in controller.artists) entry.key: entry,
      };
      final isBand = resolved.kind == ArtistProfileKind.band;

      final primarySongs = resolved.items
          .where((item) {
            final credits = ArtistCreditParser.parse(item.subtitle);
            return credits.isPrimaryArtistKey(resolved.key);
          })
          .toList(growable: false);
      final collaborationSongs = resolved.items
          .where((item) {
            final credits = ArtistCreditParser.parse(item.subtitle);
            return credits.isCollaborationForArtistKey(resolved.key);
          })
          .toList(growable: false);

      final memberArtists = resolved.memberKeys
          .map((key) => artistsByKey[key])
          .whereType<ArtistGroup>()
          .toList(growable: false);
      final memberKeySet = memberArtists.map((e) => e.key).toSet();

      final memberSingles = <MediaItem>[];
      final memberCollaborations = <MediaItem>[];
      if (isBand && memberKeySet.isNotEmpty) {
        final memberPool = _dedupeById(
          memberArtists.expand((entry) => entry.items),
        );
        for (final item in memberPool) {
          final credits = ArtistCreditParser.parse(item.subtitle);
          if (credits.containsArtistKey(resolved.key)) continue;

          final memberAsPrimary = memberKeySet.any(credits.isPrimaryArtistKey);
          final memberAsCollab =
              !memberAsPrimary &&
              memberKeySet.any(credits.isCollaborationForArtistKey);

          if (memberAsPrimary) {
            memberSingles.add(item);
          } else if (memberAsCollab) {
            memberCollaborations.add(item);
          }
        }
      }

      final displayQueue = _dedupeById([
        ...primarySongs,
        ...collaborationSongs,
        ...memberSingles,
        ...memberCollaborations,
      ]);

      final thumb = resolved.thumbnailLocalPath ?? resolved.thumbnail;
      final country = (resolved.country ?? '').trim();
      final countryFlag = CountryCatalog.flagFromIso(resolved.countryCode);
      final typeLabel = resolved.kind.label;
      final typeCountryLine = country.isNotEmpty
          ? '$typeLabel - ${countryFlag.isEmpty ? country : '$countryFlag $country'}'
          : typeLabel;

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: ListenfyLogo(size: 28, color: theme.colorScheme.primary),
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => Get.toNamed(
                AppRoutes.editEntity,
                arguments: EditEntityArgs.artist(resolved),
              ),
            ),
          ],
        ),
        body: AppGradientBackground(
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ArtistAvatar(thumb: thumb, radius: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                resolved.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                typeCountryLine,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '${resolved.count} canciones',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (isBand && memberArtists.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${memberArtists.length} integrantes',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (isBand && memberArtists.isNotEmpty) ...[
                  _MemberSection(
                    members: memberArtists,
                    onOpen: (member) => Get.toNamed(
                      AppRoutes.artistDetail,
                      arguments: member.key,
                      preventDuplicates: false,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _SongSection(
                  title: isBand ? 'Canciones del grupo musical' : 'Canciones',
                  subtitle: '${primarySongs.length} como artista principal',
                  items: primarySongs,
                  onPlay: (item) => home.openMedia(
                    item,
                    displayQueue.indexWhere((entry) => entry.id == item.id),
                    displayQueue,
                  ),
                  onMore: (item) => actions.showItemActions(
                    context,
                    item,
                    onChanged: controller.load,
                    onStartMultiSelect: () {
                      Get.toNamed(
                        AppRoutes.homeSectionList,
                        arguments: {
                          'title': isBand
                              ? 'Canciones del grupo musical'
                              : 'Canciones',
                          'items': primarySongs,
                          'onItemTap': (MediaItem tapped, int index) =>
                              home.openMedia(
                                tapped,
                                displayQueue.indexWhere(
                                  (e) => e.id == tapped.id,
                                ),
                                displayQueue,
                              ),
                          'onItemLongPress':
                              (
                                MediaItem target,
                                int _, {
                                VoidCallback? onStartMultiSelect,
                              }) => actions.showItemActions(
                                context,
                                target,
                                onChanged: controller.load,
                                onStartMultiSelect: onStartMultiSelect,
                              ),
                          'onDeleteSelected': (List<MediaItem> selected) async {
                            await actions.confirmDeleteMultiple(
                              context,
                              selected,
                              onChanged: controller.load,
                            );
                          },
                          'startInSelectionMode': true,
                          'initialSelectionItemId': item.id,
                        },
                      );
                    },
                  ),
                ),
                if (collaborationSongs.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SongSection(
                    title: isBand
                        ? 'Colaboraciones del grupo musical'
                        : 'Colaboraciones',
                    subtitle: '${collaborationSongs.length} como invitado',
                    items: collaborationSongs,
                    onPlay: (item) => home.openMedia(
                      item,
                      displayQueue.indexWhere((entry) => entry.id == item.id),
                      displayQueue,
                    ),
                    onMore: (item) => actions.showItemActions(
                      context,
                      item,
                      onChanged: controller.load,
                      onStartMultiSelect: () {
                        Get.toNamed(
                          AppRoutes.homeSectionList,
                          arguments: {
                            'title': isBand
                                ? 'Colaboraciones del grupo musical'
                                : 'Colaboraciones',
                            'items': collaborationSongs,
                            'onItemTap': (MediaItem tapped, int index) =>
                                home.openMedia(
                                  tapped,
                                  displayQueue.indexWhere(
                                    (e) => e.id == tapped.id,
                                  ),
                                  displayQueue,
                                ),
                            'onItemLongPress':
                                (
                                  MediaItem target,
                                  int _, {
                                  VoidCallback? onStartMultiSelect,
                                }) => actions.showItemActions(
                                  context,
                                  target,
                                  onChanged: controller.load,
                                  onStartMultiSelect: onStartMultiSelect,
                                ),
                            'onDeleteSelected':
                                (List<MediaItem> selected) async {
                                  await actions.confirmDeleteMultiple(
                                    context,
                                    selected,
                                    onChanged: controller.load,
                                  );
                                },
                            'startInSelectionMode': true,
                            'initialSelectionItemId': item.id,
                          },
                        );
                      },
                    ),
                  ),
                ],
                if (isBand && memberSingles.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SongSection(
                    title: 'Singles de integrantes',
                    subtitle:
                        '${memberSingles.length} canciones como principal',
                    items: memberSingles,
                    onPlay: (item) => home.openMedia(
                      item,
                      displayQueue.indexWhere((entry) => entry.id == item.id),
                      displayQueue,
                    ),
                    onMore: (item) => actions.showItemActions(
                      context,
                      item,
                      onChanged: controller.load,
                      onStartMultiSelect: () {
                        Get.toNamed(
                          AppRoutes.homeSectionList,
                          arguments: {
                            'title': 'Singles de integrantes',
                            'items': memberSingles,
                            'onItemTap': (MediaItem tapped, int index) =>
                                home.openMedia(
                                  tapped,
                                  displayQueue.indexWhere(
                                    (e) => e.id == tapped.id,
                                  ),
                                  displayQueue,
                                ),
                            'onItemLongPress':
                                (
                                  MediaItem target,
                                  int _, {
                                  VoidCallback? onStartMultiSelect,
                                }) => actions.showItemActions(
                                  context,
                                  target,
                                  onChanged: controller.load,
                                  onStartMultiSelect: onStartMultiSelect,
                                ),
                            'onDeleteSelected':
                                (List<MediaItem> selected) async {
                                  await actions.confirmDeleteMultiple(
                                    context,
                                    selected,
                                    onChanged: controller.load,
                                  );
                                },
                            'startInSelectionMode': true,
                            'initialSelectionItemId': item.id,
                          },
                        );
                      },
                    ),
                  ),
                ],
                if (isBand && memberCollaborations.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SongSection(
                    title: 'Colaboraciones de integrantes',
                    subtitle:
                        '${memberCollaborations.length} canciones como invitados',
                    items: memberCollaborations,
                    onPlay: (item) => home.openMedia(
                      item,
                      displayQueue.indexWhere((entry) => entry.id == item.id),
                      displayQueue,
                    ),
                    onMore: (item) => actions.showItemActions(
                      context,
                      item,
                      onChanged: controller.load,
                      onStartMultiSelect: () {
                        Get.toNamed(
                          AppRoutes.homeSectionList,
                          arguments: {
                            'title': 'Colaboraciones de integrantes',
                            'items': memberCollaborations,
                            'onItemTap': (MediaItem tapped, int index) =>
                                home.openMedia(
                                  tapped,
                                  displayQueue.indexWhere(
                                    (e) => e.id == tapped.id,
                                  ),
                                  displayQueue,
                                ),
                            'onItemLongPress':
                                (
                                  MediaItem target,
                                  int _, {
                                  VoidCallback? onStartMultiSelect,
                                }) => actions.showItemActions(
                                  context,
                                  target,
                                  onChanged: controller.load,
                                  onStartMultiSelect: onStartMultiSelect,
                                ),
                            'onDeleteSelected':
                                (List<MediaItem> selected) async {
                                  await actions.confirmDeleteMultiple(
                                    context,
                                    selected,
                                    onChanged: controller.load,
                                  );
                                },
                            'startInSelectionMode': true,
                            'initialSelectionItemId': item.id,
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _MemberSection extends StatelessWidget {
  const _MemberSection({required this.members, required this.onOpen});

  final List<ArtistGroup> members;
  final ValueChanged<ArtistGroup> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Integrantes',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (_, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final member = members[index];
              return _MemberArtistCard(
                member: member,
                onTap: () => onOpen(member),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MemberArtistCard extends StatelessWidget {
  const _MemberArtistCard({required this.member, required this.onTap});

  final ArtistGroup member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final thumb = member.thumbnailLocalPath ?? member.thumbnail;
    final imageProvider = (thumb != null && thumb.isNotEmpty)
        ? (thumb.startsWith('http')
              ? NetworkImage(thumb)
              : FileImage(File(thumb)) as ImageProvider)
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
                image: imageProvider != null
                    ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                    : null,
              ),
              child: imageProvider == null
                  ? Icon(
                      Icons.person_rounded,
                      size: 34,
                      color: scheme.onSurfaceVariant,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              ArtistProfileKind.singer.label,
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

class _SongSection extends StatefulWidget {
  const _SongSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onPlay,
    required this.onMore,
  });

  final String title;
  final String subtitle;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onPlay;
  final ValueChanged<MediaItem> onMore;

  @override
  State<_SongSection> createState() => _SongSectionState();
}

class _SongSectionState extends State<_SongSection> {
  bool _gridMode = false;
  HomeMediaSort _sort = HomeMediaSort.title;
  bool _sortAscending = true;
  final GetStorage _storage = GetStorage();

  @override
  void initState() {
    super.initState();
    _gridMode = _storage.read('artist_detail_grid_view') ?? false;
    _sort = _readSort();
    _sortAscending = _storage.read('artist_detail_song_sort_ascending') ?? true;
  }

  HomeMediaSort _readSort() {
    final raw = (_storage.read('artist_detail_song_sort') as String?)?.trim();
    for (final option in _sortOptions) {
      if (option.key == raw) return option;
    }
    return HomeMediaSort.title;
  }

  List<HomeMediaSort> get _sortOptions => const [
    HomeMediaSort.title,
    HomeMediaSort.artist,
    HomeMediaSort.importedAt,
    HomeMediaSort.size,
    HomeMediaSort.plays,
    HomeMediaSort.duration,
    HomeMediaSort.recent,
  ];

  List<MediaItem> get _sortedItems {
    final list = widget.items.toList(growable: true);
    int compareString(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    list.sort((a, b) {
      final result = switch (_sort) {
        HomeMediaSort.title => compareString(a.title, b.title),
        HomeMediaSort.artist => compareString(
          a.displaySubtitle,
          b.displaySubtitle,
        ),
        HomeMediaSort.importedAt => _latestVariantCreatedAt(
          a,
        ).compareTo(_latestVariantCreatedAt(b)),
        HomeMediaSort.size => _localSizeBytes(a).compareTo(_localSizeBytes(b)),
        HomeMediaSort.plays => a.playCount.compareTo(b.playCount),
        HomeMediaSort.duration => (a.effectiveDurationSeconds ?? 0).compareTo(
          b.effectiveDurationSeconds ?? 0,
        ),
        HomeMediaSort.recent => (a.lastPlayedAt ?? 0).compareTo(
          b.lastPlayedAt ?? 0,
        ),
      };
      if (result != 0) return _sortAscending ? result : -result;
      return compareString(a.title, b.title);
    });
    return list;
  }

  int _latestVariantCreatedAt(MediaItem item) {
    var maxTs = 0;
    for (final variant in item.variants) {
      if (variant.localPath?.trim().isNotEmpty != true) continue;
      if (variant.createdAt > maxTs) maxTs = variant.createdAt;
    }
    return maxTs;
  }

  int _localSizeBytes(MediaItem item) {
    var total = 0;
    for (final variant in item.variants) {
      if (variant.localPath?.trim().isNotEmpty != true) continue;
      total += variant.size ?? 0;
    }
    return total;
  }

  void _setSort(HomeMediaSort value) {
    setState(() => _sort = value);
    _storage.write('artist_detail_song_sort', value.key);
  }

  void _setSortAscending(bool value) {
    setState(() => _sortAscending = value);
    _storage.write('artist_detail_song_sort_ascending', value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final items = _sortedItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: _gridMode ? 'Vista de cuadrícula' : 'Vista de lista',
              onPressed: () {
                setState(() {
                  _gridMode = !_gridMode;
                  _storage.write('artist_detail_grid_view', _gridMode);
                });
              },
              icon: Icon(
                _gridMode ? Icons.grid_view_rounded : Icons.view_list_rounded,
              ),
            ),
            IconButton(
              tooltip: 'Ordenar',
              onPressed: () => _openSortSheet(context),
              icon: const Icon(Icons.sort_rounded),
            ),
          ],
        ),
        Text(
          widget.subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        AppMediaItemsList(
          items: items,
          gridView: _gridMode,
          onTap: (item, index) => widget.onPlay(item),
          onLongPress: (item, index) => widget.onMore(item),
          compactListCard: true,
        ),
      ],
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateSort(HomeMediaSort value) {
              _setSort(value);
              setSheetState(() {});
            }

            void updateDirection(bool value) {
              _setSortAscending(value);
              setSheetState(() {});
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ordenar canciones',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final option in _sortOptions)
                      _ArtistSongSortOption(
                        icon: option.icon,
                        label: option.label,
                        selected: _sort == option,
                        onTap: () => updateSort(option),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    _ArtistSongSortOption(
                      icon: Icons.south_rounded,
                      label: _directionLabel(ascending: false),
                      selected: !_sortAscending,
                      onTap: () => updateDirection(false),
                    ),
                    _ArtistSongSortOption(
                      icon: Icons.north_rounded,
                      label: _directionLabel(ascending: true),
                      selected: _sortAscending,
                      onTap: () => updateDirection(true),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Aceptar'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => nav?.setOverlayOpen(false));
  }

  String _directionLabel({required bool ascending}) {
    return switch (_sort) {
      HomeMediaSort.title || HomeMediaSort.artist => ascending ? 'A-Z' : 'Z-A',
      HomeMediaSort.importedAt || HomeMediaSort.recent =>
        ascending ? 'Más antiguo primero' : 'Más reciente primero',
      HomeMediaSort.plays ||
      HomeMediaSort.size ||
      HomeMediaSort.duration => ascending ? 'Menor a mayor' : 'Mayor a menor',
    };
  }
}

class _ArtistSongSortOption extends StatelessWidget {
  const _ArtistSongSortOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
