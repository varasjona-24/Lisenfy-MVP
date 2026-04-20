import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/media/media_item_grid.dart';
import '../controller/home_controller.dart';

class AppSongsSearchPage extends StatefulWidget {
  const AppSongsSearchPage({super.key});

  @override
  State<AppSongsSearchPage> createState() => _AppSongsSearchPageState();
}

class _AppSongsSearchPageState extends State<AppSongsSearchPage> {
  final HomeController _home = Get.find<HomeController>();
  final MediaActionsController _actions = Get.find<MediaActionsController>();
  final TextEditingController _searchCtrl = TextEditingController();

  String _query = '';
  bool _gridView = false;

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

    items.sort((a, b) => _importedAt(b).compareTo(_importedAt(a)));
    return items;
  }

  int _importedAt(MediaItem item) {
    if (item.variants.isEmpty) return 0;
    return item.variants
        .map((v) => v.createdAt)
        .fold<int>(0, (maxValue, value) => value > maxValue ? value : maxValue);
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
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = list[index];
        return _SearchItemTile(
          item: item,
          onTap: () => _home.openMedia(item, index, list),
          onMore: () => _openItemActions(context, item, list),
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
      onMore: (item, index) => _openItemActions(context, item, list),
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
    required this.onMore,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onMore;

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
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Más opciones',
                color: scheme.onSurfaceVariant,
                onPressed: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
