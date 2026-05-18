import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/media/media_item_grid.dart';
import '../controller/home_controller.dart';

enum _SongLibrarySort { importedAt, title, artist, size, plays, duration }

class AppSongsSearchPage extends StatefulWidget {
  const AppSongsSearchPage({super.key});

  @override
  State<AppSongsSearchPage> createState() => _AppSongsSearchPageState();
}

class _AppSongsSearchPageState extends State<AppSongsSearchPage> {
  final HomeController _home = Get.find<HomeController>();
  final MediaActionsController _actions = Get.find<MediaActionsController>();
  final TextEditingController _searchCtrl = TextEditingController();
  final GetStorage _storage = GetStorage();

  String _query = '';
  bool _gridView = false;
  late _SongLibrarySort _sort;
  late bool _sortAscending;

  @override
  void initState() {
    super.initState();
    _sort = _readSort();
    _sortAscending = _storage.read('song_library_sort_ascending') ?? false;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Get.back(),
        ),
        title: ListenfyLogo(size: 28, color: scheme.primary),
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: AppGradientBackground(
        child: Obx(() {
          final list = _filteredItems();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Biblioteca de canciones',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ordenar',
                      onPressed: () => _openSortSheet(context),
                      icon: const Icon(Icons.sort_rounded),
                    ),
                    IconButton(
                      tooltip: _gridView ? 'Ver como lista' : 'Ver cuadrícula',
                      onPressed: () => setState(() => _gridView = !_gridView),
                      icon: Icon(
                        _gridView
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  '${list.length} resultados',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Buscar por título o artista',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                          'No hay resultados.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : _gridView
                    ? _buildGridResults(theme, scheme, list)
                    : _buildListResults(theme, list),
              ),
            ],
          );
        }),
      ),
    );
  }

  List<MediaItem> _filteredItems() {
    final isAudioMode = _home.mode.value == HomeMode.audio;
    final q = _query.toLowerCase();

    final items = _home.allItems.where((item) {
      final matchesMode = isAudioMode ? item.hasAudioLocal : item.hasVideoLocal;
      if (!matchesMode) return false;
      if (q.isEmpty) return true;

      final title = item.title.toLowerCase();
      final subtitle = item.displaySubtitle.toLowerCase();
      return title.contains(q) || subtitle.contains(q);
    }).toList();

    _sortItems(items);
    return items;
  }

  void _sortItems(List<MediaItem> items) {
    items.sort((a, b) {
      final result = switch (_sort) {
        _SongLibrarySort.importedAt => _importedAt(a).compareTo(_importedAt(b)),
        _SongLibrarySort.title => _compareText(a.title, b.title),
        _SongLibrarySort.artist => _compareText(_artist(a), _artist(b)),
        _SongLibrarySort.size => _size(a).compareTo(_size(b)),
        _SongLibrarySort.plays => a.playCount.compareTo(b.playCount),
        _SongLibrarySort.duration => _duration(a).compareTo(_duration(b)),
      };
      if (result != 0) return result;
      return _compareText(a.title, b.title);
    });
    if (!_sortAscending) {
      items.setAll(0, items.reversed.toList(growable: false));
    }
  }

  int _importedAt(MediaItem item) {
    if (item.variants.isEmpty) return 0;
    return item.variants
        .map((v) => v.createdAt)
        .fold<int>(0, (maxValue, value) => value > maxValue ? value : maxValue);
  }

  int _size(MediaItem item) {
    final variant = item.localAudioVariant ?? item.localVideoVariant;
    return variant?.size ?? 0;
  }

  int _duration(MediaItem item) => item.effectiveDurationSeconds ?? 0;

  String _artist(MediaItem item) {
    final parsed = item.displaySubtitle.trim();
    return parsed.isEmpty ? 'Artista desconocido' : parsed;
  }

  int _compareText(String a, String b) {
    return a.trim().toLowerCase().compareTo(b.trim().toLowerCase());
  }

  _SongLibrarySort _readSort() {
    final raw = (_storage.read('song_library_sort') as String?)?.trim();
    for (final option in _SongLibrarySort.values) {
      if (option.name == raw) return option;
    }
    return _SongLibrarySort.importedAt;
  }

  void _setSort(_SongLibrarySort value) {
    setState(() => _sort = value);
    _storage.write('song_library_sort', value.name);
  }

  void _setSortAscending(bool value) {
    setState(() => _sortAscending = value);
    _storage.write('song_library_sort_ascending', value);
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
        return StatefulBuilder(
          builder: (context, modalSetState) {
            void selectSort(_SongLibrarySort value) {
              _setSort(value);
              modalSetState(() {});
            }

            void selectDirection(bool value) {
              _setSortAscending(value);
              modalSetState(() {});
            }

            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ordenar por',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SongSortOption(
                        label: 'Tiempo importado',
                        selected: _sort == _SongLibrarySort.importedAt,
                        onTap: () => selectSort(_SongLibrarySort.importedAt),
                      ),
                      _SongSortOption(
                        label: 'Nombre de cancion',
                        selected: _sort == _SongLibrarySort.title,
                        onTap: () => selectSort(_SongLibrarySort.title),
                      ),
                      _SongSortOption(
                        label: 'Nombre del artista',
                        selected: _sort == _SongLibrarySort.artist,
                        onTap: () => selectSort(_SongLibrarySort.artist),
                      ),
                      _SongSortOption(
                        label: 'Tamano',
                        selected: _sort == _SongLibrarySort.size,
                        onTap: () => selectSort(_SongLibrarySort.size),
                      ),
                      _SongSortOption(
                        label: 'Reproducciones',
                        selected: _sort == _SongLibrarySort.plays,
                        onTap: () => selectSort(_SongLibrarySort.plays),
                      ),
                      _SongSortOption(
                        label: 'Duracion',
                        selected: _sort == _SongLibrarySort.duration,
                        onTap: () => selectSort(_SongLibrarySort.duration),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                          height: 1,
                        ),
                      ),
                      _SongSortOption(
                        label: 'Mayor a menor / recientes primero',
                        selected: !_sortAscending,
                        onTap: () => selectDirection(false),
                      ),
                      _SongSortOption(
                        label: 'Menor a mayor / antiguos primero',
                        selected: _sortAscending,
                        onTap: () => selectDirection(true),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cerrar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => nav?.setOverlayOpen(false));
  }

  Widget _buildListResults(ThemeData theme, List<MediaItem> list) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = list[index];
        return _SearchItemTile(
          item: item,
          onTap: () => _home.openMedia(item, index, list),
          onLongPress: () => _openItemActions(context, item, list),
        );
      },
    );
  }

  Widget _buildGridResults(
    ThemeData theme,
    ColorScheme scheme,
    List<MediaItem> list,
  ) {
    return MediaItemGrid(
      items: list,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      onTap: (item, index) => _home.openMedia(item, index, list),
      onLongPress: (item, index) => _openItemActions(context, item, list),
    );
  }

  Future<void> _openItemActions(
    BuildContext context,
    MediaItem item,
    List<MediaItem> list,
  ) {
    return _actions.showItemActions(
      context,
      item,
      onChanged: _home.loadHome,
      onStartMultiSelect: () {
        Get.toNamed(
          AppRoutes.homeSectionList,
          arguments: {
            'title': 'Resultados de búsqueda',
            'items': list,
            'onItemTap': (MediaItem tapped, int tapIndex) =>
                _home.openMedia(tapped, tapIndex < 0 ? 0 : tapIndex, list),
            'onItemLongPress':
                (MediaItem target, int _, {VoidCallback? onStartMultiSelect}) =>
                    _actions.showItemActions(
                      context,
                      target,
                      onChanged: _home.loadHome,
                      onStartMultiSelect: onStartMultiSelect,
                    ),
            'onDeleteSelected': (List<MediaItem> selected) async {
              await _actions.confirmDeleteMultiple(
                context,
                selected,
                onChanged: _home.loadHome,
              );
            },
            'startInSelectionMode': true,
            'initialSelectionItemId': item.id,
          },
        );
      },
    );
  }
}

class _SearchItemTile extends StatelessWidget {
  const _SearchItemTile({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isVideo = item.hasVideoLocal || item.localVideoVariant != null;
    final icon = isVideo ? Icons.videocam_rounded : Icons.music_note_rounded;
    final thumb = item.effectiveThumbnail?.trim() ?? '';
    final hasThumb = thumb.isNotEmpty;
    final imageProvider = hasThumb
        ? (thumb.startsWith('http')
              ? NetworkImage(thumb)
              : FileImage(File(thumb)) as ImageProvider)
        : null;

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 48,
                  height: 48,
                  color: scheme.surfaceContainerHighest,
                  child: imageProvider != null
                      ? Image(image: imageProvider, fit: BoxFit.cover)
                      : Icon(icon, color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.displaySubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

class _SongSortOption extends StatelessWidget {
  const _SongSortOption({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: selected ? scheme.primary : scheme.outline,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
