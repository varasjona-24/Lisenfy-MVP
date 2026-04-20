import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/models/media_item.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/themes/app_grid_theme.dart';
import '../../../app/ui/widgets/media/media_item_grid.dart';

import '../../../app/routes/app_routes.dart';
import '../../home/controller/home_controller.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../controller/sources_controller.dart';
import '../domain/source_origin.dart';
import '../domain/source_theme.dart';
import '../domain/source_theme_topic.dart';
import '../ui/source_color_picker_field.dart';

// ============================
// 🧭 PAGE: SOURCE LIBRARY
// ============================
class SourceLibraryPage extends StatefulWidget {
  const SourceLibraryPage({
    super.key,
    this.origin,
    this.origins,
    this.onlyOffline = false,
    this.forceKind,
    this.themeId,
    required this.title,
  });

  final SourceOrigin? origin;
  final List<SourceOrigin>? origins;
  final bool onlyOffline;
  final MediaVariantKind? forceKind;
  final String? themeId;
  final String title;

  @override
  State<SourceLibraryPage> createState() => _SourceLibraryPageState();
}

class _SourceLibraryPageState extends State<SourceLibraryPage> {
  final SourcesController _sources = Get.find<SourcesController>();
  final MediaActionsController _actions = Get.find<MediaActionsController>();
  bool _gridView = false;

  // ============================
  // 📚 DATA
  // ============================
  Future<List<MediaItem>> _load([HomeMode? mode]) async {
    if (widget.forceKind != null) {
      return _sources.loadLibraryItems(
        onlyOffline: widget.onlyOffline,
        origin: widget.origin,
        origins: widget.origins,
        forceKind: widget.forceKind,
      );
    }

    final modeKind = mode == null
        ? null
        : (mode == HomeMode.audio
              ? MediaVariantKind.audio
              : MediaVariantKind.video);

    return _sources.loadLibraryItems(
      onlyOffline: widget.onlyOffline,
      origin: widget.origin,
      origins: widget.origins,
      modeKind: modeKind,
    );
  }

  // ============================
  // 🧱 UI
  // ============================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final HomeController home = Get.find<HomeController>();
    SourceTheme? themeMeta;
    if (widget.themeId != null) {
      for (final t in _sources.themes) {
        if (t.id == widget.themeId) {
          themeMeta = t;
          break;
        }
      }
    }

    return Obx(() {
      final homeMode = home.mode.value;
      final displayMode = widget.forceKind == MediaVariantKind.audio
          ? HomeMode.audio
          : (widget.forceKind == MediaVariantKind.video
                ? HomeMode.video
                : homeMode);

      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppTopBar(
          title: widget.onlyOffline
              ? ListenfyLogo(size: 28, color: scheme.primary)
              : Text(widget.title),
          onToggleMode: widget.forceKind == null ? home.toggleMode : null,
          showLocalConnectAction: false,
          mode: displayMode == HomeMode.audio
              ? AppMediaMode.audio
              : AppMediaMode.video,
        ),
        body: AppGradientBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: FutureBuilder<List<MediaItem>>(
                  future: _load(displayMode),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final list = snap.data ?? const <MediaItem>[];

                    bool hasAudio(MediaItem e) =>
                        e.variants.any((v) => v.kind == MediaVariantKind.audio);
                    bool hasVideo(MediaItem e) =>
                        e.variants.any((v) => v.kind == MediaVariantKind.video);

                    final modeList = widget.forceKind != null
                        ? list
                        : (displayMode == HomeMode.audio
                              ? list.where(hasAudio).toList()
                              : list.where(hasVideo).toList());

                    return RefreshIndicator(
                      onRefresh: () async {
                        await _sources.refreshAll();
                        await _load(displayMode);
                        if (mounted) setState(() {});
                      },
                      child: ScrollConfiguration(
                        behavior: const _NoGlowScrollBehavior(),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(
                            top: 12,
                            bottom: kBottomNavigationBarHeight + 18,
                            left: 12,
                            right: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.onlyOffline) ...[
                                _offlineHeader(theme),
                                const SizedBox(height: 10),
                                _offlineSummary(
                                  theme,
                                  modeList.length,
                                  displayMode,
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              if (themeMeta != null &&
                                  themeMeta.onlyOffline != true) ...[
                                _topicHeader(themeMeta),
                                const SizedBox(height: 8),
                                _topicList(themeMeta),
                                const SizedBox(height: 18),
                              ],
                              if (themeMeta == null ||
                                  themeMeta.onlyOffline == true) ...[
                                if (!widget.onlyOffline) ...[
                                  _librarySummary(
                                    theme,
                                    modeList.length,
                                    displayMode,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (modeList.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      'No hay contenido aquí todavía.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  )
                                else if (_gridView)
                                  _itemGrid(modeList, displayMode)
                                else
                                  ...modeList.map(
                                    (item) =>
                                        _itemTile(item, modeList, displayMode),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // NAV
              Positioned(
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
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _itemTile(MediaItem item, List<MediaItem> queue, HomeMode mode) {
    final v = _variantForMode(item, mode) ?? item.variants.first;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final thumb = item.effectiveThumbnail ?? '';
    final hasThumb = thumb.isNotEmpty;
    final imageProvider = hasThumb
        ? (thumb.startsWith('http')
              ? NetworkImage(thumb)
              : FileImage(File(thumb)) as ImageProvider)
        : null;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.onlyOffline ? 12 : 8),
      child: Card(
        elevation: 0,
        color: widget.onlyOffline
            ? scheme.surfaceContainer
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.onlyOffline ? 18 : 12),
        ),
        child: ListTile(
          contentPadding: widget.onlyOffline
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
              : EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 44,
              height: 44,
              color: scheme.surfaceContainerHighest,
              child: imageProvider != null
                  ? Image(image: imageProvider, fit: BoxFit.cover)
                  : Icon(
                      v.kind == MediaVariantKind.video
                          ? Icons.videocam_rounded
                          : Icons.music_note_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
            ),
          ),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: item.subtitle.trim().isEmpty
              ? null
              : Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Wrap(
            spacing: 6,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: () {
                  _playSourceItem(item, queue, mode);
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Acciones',
                onPressed: () async {
                  await _actions.showItemActions(
                    context,
                    item,
                    onChanged: () async {
                      await _sources.refreshAll();
                      if (mounted) setState(() {});
                    },
                    onStartMultiSelect: () {
                      Get.toNamed(
                        AppRoutes.homeSectionList,
                        arguments: {
                          'title': widget.title,
                          'items': queue,
                          'onItemTap': (MediaItem tapped, int index) {
                            _playSourceItem(tapped, queue, mode);
                          },
                          'onItemLongPress':
                              (
                                MediaItem target,
                                int _, {
                                VoidCallback? onStartMultiSelect,
                              }) => _actions.showItemActions(
                                context,
                                target,
                                onChanged: () async {
                                  await _sources.refreshAll();
                                  if (mounted) setState(() {});
                                },
                                onStartMultiSelect: onStartMultiSelect,
                              ),
                          'onDeleteSelected': (List<MediaItem> selected) async {
                            await _actions.confirmDeleteMultiple(
                              context,
                              selected,
                              onChanged: () async {
                                await _sources.refreshAll();
                                if (mounted) setState(() {});
                              },
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

  Widget _itemGrid(List<MediaItem> queue, HomeMode mode) {
    return MediaItemGrid(
      items: queue,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: AppGridTheme.childAspectRatio,
      crossAxisSpacing: AppGridTheme.spacing,
      mainAxisSpacing: AppGridTheme.spacing,
      fallbackIcon: mode == HomeMode.audio
          ? Icons.music_note_rounded
          : Icons.videocam_rounded,
      onTap: (item, index) => _playSourceItem(item, queue, mode),
      onMore: (item, index) => _openGridItemActions(item, queue, mode),
    );
  }

  Future<void> _openGridItemActions(
    MediaItem item,
    List<MediaItem> queue,
    HomeMode mode,
  ) {
    return _actions.showItemActions(
      context,
      item,
      onChanged: () async {
        await _sources.refreshAll();
        if (mounted) setState(() {});
      },
      onStartMultiSelect: () {
        Get.toNamed(
          AppRoutes.homeSectionList,
          arguments: {
            'title': widget.title,
            'items': queue,
            'onItemTap': (MediaItem tapped, int index) {
              _playSourceItem(tapped, queue, mode);
            },
            'onItemLongPress':
                (MediaItem target, int _, {VoidCallback? onStartMultiSelect}) =>
                    _actions.showItemActions(
                      context,
                      target,
                      onChanged: () async {
                        await _sources.refreshAll();
                        if (mounted) setState(() {});
                      },
                      onStartMultiSelect: onStartMultiSelect,
                    ),
            'onDeleteSelected': (List<MediaItem> selected) async {
              await _actions.confirmDeleteMultiple(
                context,
                selected,
                onChanged: () async {
                  await _sources.refreshAll();
                  if (mounted) setState(() {});
                },
              );
            },
            'startInSelectionMode': true,
            'initialSelectionItemId': item.id,
          },
        );
      },
    );
  }

  void _playSourceItem(MediaItem item, List<MediaItem> queue, HomeMode mode) {
    final idx = queue.indexWhere((e) => e.id == item.id);
    final safeIdx = idx == -1 ? 0 : idx;
    final variant = _variantForMode(item, mode);
    final route = mode == HomeMode.audio
        ? AppRoutes.audioPlayer
        : AppRoutes.videoPlayer;

    Get.toNamed(
      route,
      arguments: {
        'queue': queue,
        'index': safeIdx,
        if (variant?.playableUrl.isNotEmpty == true)
          'playableUrl': variant!.playableUrl,
      },
    );
  }

  MediaVariant? _variantForMode(MediaItem item, HomeMode mode) {
    return mode == HomeMode.audio
        ? item.localAudioVariant
        : item.localVideoVariant;
  }

  Widget _offlineHeader(ThemeData theme) {
    return Text(
      'Biblioteca offline',
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _offlineSummary(ThemeData theme, int total, HomeMode mode) {
    return _librarySummary(theme, total, mode);
  }

  Widget _librarySummary(ThemeData theme, int total, HomeMode mode) {
    final label = mode == HomeMode.audio ? 'audio' : 'video';
    return Row(
      children: [
        Expanded(
          child: Text(
            '$total elementos de $label',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: _gridView ? 'Ver como lista' : 'Ver como cuadrícula',
          onPressed: () => setState(() => _gridView = !_gridView),
          icon: Icon(
            _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
          ),
        ),
      ],
    );
  }

  Widget _topicHeader(SourceTheme themeMeta) {
    final limitReached = _sources.topicsForTheme(themeMeta.id).length >= 10;
    return Row(
      children: [
        Text(
          'Temáticas',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.add_rounded),
          onPressed: () {
            if (limitReached) {
              Get.snackbar(
                'Temáticas',
                'Límite de 10 temáticas alcanzado',
                snackPosition: SnackPosition.BOTTOM,
              );
              return;
            }
            _openCreateTopic(themeMeta);
          },
        ),
      ],
    );
  }

  Widget _topicList(SourceTheme themeMeta) {
    return Obx(() {
      final topics = _sources.topicsForTheme(themeMeta.id);
      if (topics.isEmpty) {
        return Text(
          'Crea una temática para agrupar contenidos.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      }

      return Column(
        children: [
          for (final topic in topics)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TopicCard(
                themeMeta: themeMeta,
                topic: topic,
                listCount: _sources.playlistsForTopic(topic.id).length,
                onOpen: () => Get.toNamed(
                  AppRoutes.sourceTheme,
                  arguments: {
                    'topicId': topic.id,
                    'theme': themeMeta,
                    'origins': widget.origins,
                  },
                ),
                onEdit: () => _openEditTopic(topic),
                onDelete: () => _confirmDeleteTopic(topic),
              ),
            ),
        ],
      );
    });
  }

  // ============================
  // 🪄 DIALOGOS
  // ============================
  Future<void> _openCreateTopic(SourceTheme themeMeta) async {
    String name = '';
    String? coverUrl;
    String? coverLocal;
    int? colorValue;
    Color draftColor = Theme.of(context).colorScheme.primary;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Nueva temática (${themeMeta.title})'),
          content: StatefulBuilder(
            builder: (ctx2, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (v) => name = v,
                      decoration: const InputDecoration(hintText: 'Nombre'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (v) => coverUrl = v,
                      decoration: const InputDecoration(
                        hintText: 'URL de imagen (opcional)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SourceColorPickerField(
                      color: colorValue != null
                          ? Color(colorValue!)
                          : draftColor,
                      onChanged: (c) => setState(() {
                        draftColor = c;
                        colorValue = c.value;
                      }),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final res = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const [
                            'jpg',
                            'jpeg',
                            'png',
                            'webp',
                          ],
                        );
                        final file = (res != null && res.files.isNotEmpty)
                            ? res.files.first
                            : null;
                        final path = file?.path;
                        if (path != null && path.isNotEmpty) {
                          coverLocal = path;
                        }
                      },
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Elegir imagen'),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _sources.addTopic(
                  themeId: themeMeta.id,
                  title: name,
                  coverUrl: coverUrl,
                  coverLocalPath: coverLocal,
                  colorValue: colorValue,
                );
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditTopic(SourceThemeTopic topic) async {
    await Get.toNamed(
      AppRoutes.editEntity,
      arguments: EditEntityArgs.topic(topic),
    );
  }

  Future<void> _confirmDeleteTopic(SourceThemeTopic topic) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar temática'),
        content: Text('¿Eliminar "${topic.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _sources.deleteTopic(topic);
    }
  }
}

class _TopicCard extends StatefulWidget {
  const _TopicCard({
    required this.themeMeta,
    required this.topic,
    required this.listCount,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final SourceTheme themeMeta;
  final SourceThemeTopic topic;
  final int listCount;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final topic = widget.topic;
    final base = topic.colorValue != null
        ? Color(topic.colorValue!)
        : widget.themeMeta.colors.first;
    final textColor = Colors.white;
    final scale = _isPressed ? 0.97 : (_isHovered ? 1.01 : 1.0);

    ImageProvider? provider;
    final path = topic.coverLocalPath?.trim();
    final url = topic.coverUrl?.trim();
    if (path != null && path.isNotEmpty) {
      provider = FileImage(File(path));
    } else if (url != null && url.isNotEmpty) {
      provider = NetworkImage(url);
    }

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 200),
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
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [base.withOpacity(0.95), base.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: base.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Subtle glass overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: provider != null
                                  ? Image(image: provider, fit: BoxFit.cover)
                                  : Icon(
                                      Icons.folder_rounded,
                                      color: textColor,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topic.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.textTheme.titleMedium?.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${topic.itemIds.length} items · ${widget.listCount} listas',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.textTheme.bodySmall?.copyWith(
                                    color: textColor.withOpacity(0.85),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<_TopicAction>(
                            onSelected: (value) {
                              if (value == _TopicAction.edit) widget.onEdit();
                              if (value == _TopicAction.delete)
                                widget.onDelete();
                            },
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: textColor.withOpacity(0.9),
                            ),
                            color: t.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: _TopicAction.edit,
                                child: Text('Editar'),
                              ),
                              const PopupMenuItem(
                                value: _TopicAction.delete,
                                child: Text('Eliminar'),
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

enum _TopicAction { edit, delete }

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
