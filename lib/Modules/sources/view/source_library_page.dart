import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
import '../../../app/services/audio_service.dart';
import '../../home/controller/home_controller.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../controller/sources_controller.dart';
import '../domain/source_origin.dart';
import '../domain/source_theme.dart';
import '../domain/source_theme_topic.dart';

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
  final TextEditingController _topicSearchController = TextEditingController();
  bool _gridView = false;
  String _topicQuery = '';
  _TopicSort _topicSort = _TopicSort.recent;
  Future<List<MediaItem>>? _itemsFuture;
  HomeMode? _itemsFutureMode;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<AudioService>()) {
      Get.find<AudioService>().pauseAndHideMiniPlayer();
    }
  }

  @override
  void dispose() {
    _topicSearchController.dispose();
    super.dispose();
  }

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

  Future<List<MediaItem>> _itemsFutureFor(HomeMode mode) {
    final cached = _itemsFuture;
    if (cached != null && _itemsFutureMode == mode) return cached;
    _itemsFutureMode = mode;
    _itemsFuture = _load(mode);
    return _itemsFuture!;
  }

  Future<void> _refreshItems(HomeMode mode) async {
    await _sources.refreshAll();
    _itemsFutureMode = mode;
    _itemsFuture = _load(mode);
    await _itemsFuture;
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
      // Biblioteca offline: siempre en modo video
      final displayMode = widget.onlyOffline
          ? HomeMode.video
          : (widget.forceKind == MediaVariantKind.audio
                ? HomeMode.audio
                : (widget.forceKind == MediaVariantKind.video
                      ? HomeMode.video
                      : homeMode));

      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppTopBar(
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: Get.back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: widget.onlyOffline
              ? ListenfyLogo(size: 28, color: scheme.primary)
              : Text(widget.title),
          // Sin toggle cuando es offline (solo video) o forceKind fijo
          onToggleMode: (widget.onlyOffline || widget.forceKind != null)
              ? null
              : home.toggleMode,
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
                  future: _itemsFutureFor(displayMode),
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
                        await _refreshItems(displayMode);
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
                      case 5:
                        home.goToAtlas();
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Collections',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Obx(() {
              final count = _sources.topicsForTheme(themeMeta.id).length;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count/10',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }),
            const Spacer(),
            IconButton.filledTonal(
              tooltip: 'Nueva Collection',
              icon: const Icon(Icons.create_new_folder_rounded),
              onPressed: () {
                if (limitReached) {
                  Get.snackbar(
                    'Collections',
                    'Límite de 10 Collections alcanzado',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                }
                _openCreateTopic(themeMeta);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _topicSearchController,
                  onChanged: (value) => setState(() => _topicQuery = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar Collection',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _topicQuery.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            onPressed: () {
                              _topicSearchController.clear();
                              setState(() => _topicQuery = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.55,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<_TopicSort>(
              tooltip: 'Ordenar',
              initialValue: _topicSort,
              onSelected: (value) => setState(() => _topicSort = value),
              icon: const Icon(Icons.sort_rounded),
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: _TopicSort.recent,
                  child: Text('Recientes primero'),
                ),
                PopupMenuItem(value: _TopicSort.name, child: Text('Nombre')),
                PopupMenuItem(
                  value: _TopicSort.items,
                  child: Text('Más items'),
                ),
                PopupMenuItem(
                  value: _TopicSort.lists,
                  child: Text('Más Collections'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _topicList(SourceTheme themeMeta) {
    return Obx(() {
      final allTopics = _sources.topicsForTheme(themeMeta.id);
      final query = _topicQuery.trim().toLowerCase();
      final topics = allTopics.where((topic) {
        if (query.isEmpty) return true;
        return topic.title.toLowerCase().contains(query);
      }).toList();
      topics.sort((a, b) {
        switch (_topicSort) {
          case _TopicSort.name:
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          case _TopicSort.items:
            return b.itemIds.length.compareTo(a.itemIds.length);
          case _TopicSort.lists:
            return _sources
                .playlistsForTopic(b.id)
                .length
                .compareTo(_sources.playlistsForTopic(a.id).length);
          case _TopicSort.recent:
            return b.createdAt.compareTo(a.createdAt);
        }
      });
      if (topics.isEmpty) {
        final emptyText = allTopics.isEmpty
            ? 'Crea una Collection para agrupar contenidos.'
            : 'No hay Collections con ese nombre.';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            emptyText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
    await Get.toNamed(
      AppRoutes.createEntity,
      preventDuplicates: false,
      arguments: CreateEntityArgs.topic(
        storageId: 'stt_${themeMeta.id}_create',
        themeId: themeMeta.id,
      ),
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
        title: const Text('Eliminar Collection'),
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
    final scheme = t.colorScheme;
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
            borderRadius: BorderRadius.circular(8),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isHovered
                        ? base.withValues(alpha: 0.65)
                        : scheme.outlineVariant.withValues(alpha: 0.48),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 4, color: base),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: base.withValues(alpha: 0.16),
                                border: Border.all(
                                  color: base.withValues(alpha: 0.22),
                                  width: 1,
                                ),
                              ),
                              child: provider != null
                                  ? Image(image: provider, fit: BoxFit.cover)
                                  : Icon(Icons.folder_rounded, color: base),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  topic.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.textTheme.titleMedium?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _TopicMetricChip(
                                      icon: Icons.library_music_rounded,
                                      label: '${topic.itemIds.length}',
                                    ),
                                    _TopicMetricChip(
                                      icon: Icons.queue_music_rounded,
                                      label: '${widget.listCount}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<_TopicAction>(
                            onSelected: (value) {
                              if (value == _TopicAction.edit) widget.onEdit();
                              if (value == _TopicAction.delete) {
                                widget.onDelete();
                              }
                            },
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: scheme.onSurfaceVariant,
                            ),
                            color: t.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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

enum _TopicSort { recent, name, items, lists }

class _TopicMetricChip extends StatelessWidget {
  const _TopicMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
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
