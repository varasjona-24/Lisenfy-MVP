import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../controller/home_controller.dart';

class MediaSearchDelegate extends SearchDelegate<MediaItem?> {
  MediaSearchDelegate(this.controller);

  final HomeController controller;
  final MediaActionsController _actions = Get.find<MediaActionsController>();
  bool _didUnfocusOnOpen = false;

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(elevation: 0),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildResultsList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _dismissKeyboardOnFirstOpen(context);
    if (query.trim().isEmpty) {
      return _buildSuggestions(context);
    }
    return _buildResultsList(context);
  }

  void _dismissKeyboardOnFirstOpen(BuildContext context) {
    if (_didUnfocusOnOpen) return;
    _didUnfocusOnOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  Widget _buildSuggestions(BuildContext context) {
    final all = _allModeItems();
    if (all.isEmpty) {
      return _emptyState(context, 'Empieza a escribir para buscar.');
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Todos',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(all.length, (index) {
          final item = all[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _resultTile(context, item, all, index),
          );
        }),
      ],
    );
  }

  Widget _buildResultsList(BuildContext context) {
    final list = _searchItems(query);
    if (list.isEmpty) {
      return _emptyState(context, 'No hay resultados.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = list[index];
        return _resultTile(context, item, list, index);
      },
    );
  }

  List<MediaItem> _searchItems(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return <MediaItem>[];

    final isAudioMode = controller.mode.value == HomeMode.audio;

    return controller.allItems.where((item) {
      final matchesMode = isAudioMode ? item.hasAudioLocal : item.hasVideoLocal;
      if (!matchesMode) return false;

      final title = item.title.toLowerCase();
      final subtitle = item.displaySubtitle.toLowerCase();
      return title.contains(q) || subtitle.contains(q);
    }).toList();
  }

  List<MediaItem> _allModeItems() {
    final isAudioMode = controller.mode.value == HomeMode.audio;
    final items = controller.allItems.where((item) {
      return isAudioMode ? item.hasAudioLocal : item.hasVideoLocal;
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

  Widget _resultTile(
    BuildContext context,
    MediaItem item,
    List<MediaItem> list,
    int index,
  ) {
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
        onTap: () {
          close(context, item);
          controller.openMedia(item, index, list);
        },
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
                onPressed: () {
                  _actions.showItemActions(
                    context,
                    item,
                    onChanged: controller.loadHome,
                    onStartMultiSelect: () {
                      close(context, null);
                      Get.toNamed(
                        AppRoutes.homeSectionList,
                        arguments: {
                          'title': 'Resultados de búsqueda',
                          'items': list,
                          'onItemTap': (MediaItem tapped, int tapIndex) =>
                              controller.openMedia(
                                tapped,
                                tapIndex < 0 ? 0 : tapIndex,
                                list,
                              ),
                          'onItemLongPress':
                              (
                                MediaItem target,
                                int _, {
                                VoidCallback? onStartMultiSelect,
                              }) => _actions.showItemActions(
                                context,
                                target,
                                onChanged: controller.loadHome,
                                onStartMultiSelect: onStartMultiSelect,
                              ),
                          'onDeleteSelected': (List<MediaItem> selected) async {
                            await _actions.confirmDeleteMultiple(
                              context,
                              selected,
                              onChanged: controller.loadHome,
                            );
                          },
                          'startInSelectionMode': true,
                          'initialSelectionItemId': item.id,
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
