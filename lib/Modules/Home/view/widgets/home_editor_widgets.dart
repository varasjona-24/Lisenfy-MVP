part of '../home_page.dart';

Future<void> _openHomeEditorSheet(
  BuildContext context, {
  required HomeController controller,
  required HomeMode mode,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _HomeWidgetEditor(controller: controller, mode: mode),
  );
}

class _HomeWidgetEditor extends StatefulWidget {
  const _HomeWidgetEditor({required this.controller, required this.mode});

  final HomeController controller;
  final HomeMode mode;

  @override
  State<_HomeWidgetEditor> createState() => _HomeWidgetEditorState();
}

class _HomeWidgetEditorState extends State<_HomeWidgetEditor> {
  late List<HomeWidgetId> _order;
  late Set<HomeWidgetId> _enabled;
  late Map<String, HomeCustomSectionLayout> _layouts;
  late List<HomeCustomSection> _customSections;

  HomeController get controller => widget.controller;
  HomeMode get mode => widget.mode;

  @override
  void initState() {
    super.initState();
    _order = controller.homeWidgetOrder.toList(growable: true);
    _enabled = controller.enabledHomeWidgets.toSet();
    _layouts = Map<String, HomeCustomSectionLayout>.from(
      controller.homeWidgetLayouts,
    );
    _customSections = controller.customHomeSections.toList(growable: true);
  }

  List<HomeWidgetId> get _visibleItems {
    return _order
        .where((id) => mode == HomeMode.audio || !id.audioOnly)
        .toList(growable: false);
  }

  HomeCustomSectionLayout _layoutForWidget(HomeWidgetId id) {
    if (id.hasFixedLayout) return HomeCustomSectionLayout.cards;
    return _layouts[id.key] ?? HomeCustomSectionLayout.cards;
  }

  void _toggleWidget(HomeWidgetId id) {
    setState(() {
      if (_enabled.contains(id)) {
        _enabled.remove(id);
      } else {
        _enabled.add(id);
      }
    });
  }

  void _toggleWidgetLayout(HomeWidgetId id) {
    if (id.hasFixedLayout) return;
    setState(() {
      final current = _layoutForWidget(id);
      _layouts[id.key] = current == HomeCustomSectionLayout.cards
          ? HomeCustomSectionLayout.list
          : HomeCustomSectionLayout.cards;
    });
  }

  void _moveWidget(int oldIndex, int newIndex) {
    final modeItems = _visibleItems.toList(growable: true);
    if (oldIndex < 0 || oldIndex >= modeItems.length) return;
    if (newIndex < 0 || newIndex > modeItems.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = modeItems.removeAt(oldIndex);
    modeItems.insert(newIndex, moved);

    var modeIndex = 0;
    final nextOrder = <HomeWidgetId>[];
    for (final id in _order) {
      if (mode == HomeMode.video && id.audioOnly) {
        nextOrder.add(id);
      } else {
        nextOrder.add(modeItems[modeIndex]);
        modeIndex++;
      }
    }

    setState(() => _order = nextOrder);
  }

  void _reset() {
    setState(() {
      _order = HomeWidgetId.values.toList(growable: true);
      _enabled = HomeWidgetId.values.toSet();
      _layouts = <String, HomeCustomSectionLayout>{};
      _customSections = <HomeCustomSection>[];
    });
  }

  void _toggleCustomSectionLayout(String id) {
    final index = _customSections.indexWhere((section) => section.id == id);
    if (index < 0) return;
    final current = _customSections[index];
    final nextLayout = current.layout == HomeCustomSectionLayout.cards
        ? HomeCustomSectionLayout.list
        : HomeCustomSectionLayout.cards;
    setState(() {
      _customSections[index] = current.copyWith(layout: nextLayout);
    });
  }

  void _removeCustomSection(String id) {
    setState(() {
      _customSections.removeWhere((section) => section.id == id);
    });
  }

  void _addPlaylistSection({required String playlistId}) {
    final cleanId = playlistId.trim();
    if (cleanId.isEmpty) return;
    const sectionId = 'playlists_custom';
    final index = _customSections.indexWhere((e) => e.id == sectionId);
    setState(() {
      if (index >= 0) {
        final current = _customSections[index];
        final ids =
            current.targetId
                .split('|')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toSet()
              ..add(cleanId);
        _customSections[index] = HomeCustomSection(
          id: current.id,
          kind: HomeCustomSectionKind.playlist,
          targetId: ids.join('|'),
          title: 'Listas de reproducción',
          layout: current.layout,
        );
      } else {
        _customSections.add(
          const HomeCustomSection(
            id: sectionId,
            kind: HomeCustomSectionKind.playlist,
            targetId: '',
            title: 'Listas de reproducción',
          ),
        );
        _customSections[_customSections.length - 1] = HomeCustomSection(
          id: sectionId,
          kind: HomeCustomSectionKind.playlist,
          targetId: cleanId,
          title: 'Listas de reproducción',
        );
      }
    });
  }

  void _addArtistSection({required String artistKey}) {
    final cleanKey = ArtistCreditParser.normalizeKey(artistKey);
    if (cleanKey.isEmpty || cleanKey == 'unknown') return;
    const sectionId = 'artists_custom';
    final index = _customSections.indexWhere((e) => e.id == sectionId);
    setState(() {
      if (index >= 0) {
        final current = _customSections[index];
        final keys =
            current.targetId
                .split('|')
                .map(ArtistCreditParser.normalizeKey)
                .where((e) => e.isNotEmpty && e != 'unknown')
                .toSet()
              ..add(cleanKey);
        _customSections[index] = HomeCustomSection(
          id: current.id,
          kind: HomeCustomSectionKind.artist,
          targetId: keys.join('|'),
          title: 'Artistas',
          layout: current.layout,
        );
      } else {
        _customSections.add(
          HomeCustomSection(
            id: sectionId,
            kind: HomeCustomSectionKind.artist,
            targetId: cleanKey,
            title: 'Artistas',
          ),
        );
      }
    });
  }

  void _save() {
    controller.applyHomeLayoutSnapshot(
      order: _order,
      enabled: _enabled.toList(growable: false),
      layouts: _layouts,
      customSections: _customSections,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = _visibleItems;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Editar inicio',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Restablecer'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(onPressed: _save, child: const Text('Guardar')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final t = Curves.easeOut.transform(animation.value);
                          return Transform.scale(
                            scale: 1 + (0.025 * t),
                            child: Material(
                              color: Colors.transparent,
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    onReorder: _moveWidget,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final id = items[index];
                      final enabled = _enabled.contains(id);
                      return _EditableHomeWidgetRow(
                        key: ValueKey(id.key),
                        id: id,
                        index: index,
                        enabled: enabled,
                        layout: _layoutForWidget(id),
                        onToggle: () => _toggleWidget(id),
                        onLayoutToggle: id.hasFixedLayout
                            ? null
                            : () => _toggleWidgetLayout(id),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showPlaylistPicker(context),
                          icon: const Icon(Icons.queue_music_rounded, size: 18),
                          label: const Text('Playlist'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showArtistPicker(context),
                          icon: const Icon(Icons.person_rounded, size: 18),
                          label: const Text('Artista'),
                        ),
                      ),
                    ],
                  ),
                  if (_customSections.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._customSections.map((section) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(section.kind.icon, color: scheme.primary),
                        title: Text(
                          section.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Vista: ${section.layout.label}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Cambiar vista',
                              onPressed: () =>
                                  _toggleCustomSectionLayout(section.id),
                              icon: Icon(section.layout.icon),
                            ),
                            IconButton(
                              tooltip: 'Quitar',
                              onPressed: () => _removeCustomSection(section.id),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPlaylistPicker(BuildContext context) async {
    final playlists = await controller.loadPlaylistChoices();
    if (!context.mounted) return;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final searchQuery = ValueNotifier<String>('');

        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setState) {
              final filtered = searchQuery.value.isEmpty
                  ? playlists
                  : playlists
                        .where(
                          (p) => p.name.toLowerCase().contains(
                            searchQuery.value.toLowerCase(),
                          ),
                        )
                        .toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      onChanged: (value) {
                        searchQuery.value = value;
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar playlist...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No se encontraron playlists',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final playlist = filtered[index];
                              final cover = playlist.coverCleared
                                  ? null
                                  : (playlist.coverLocalPath
                                                ?.trim()
                                                .isNotEmpty ==
                                            true
                                        ? playlist.coverLocalPath!.trim()
                                        : playlist.coverUrl?.trim());
                              final provider = _homeImageProvider(cover);
                              return ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                    image: provider != null
                                        ? DecorationImage(
                                            image: provider,
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: provider == null
                                      ? Icon(
                                          Icons.queue_music_rounded,
                                          color: scheme.onPrimaryContainer,
                                        )
                                      : null,
                                ),
                                title: Text(playlist.name),
                                subtitle: Text(
                                  '${playlist.itemIds.length} canción${playlist.itemIds.length != 1 ? 'es' : ''}',
                                ),
                                onTap: () {
                                  _addPlaylistSection(playlistId: playlist.id);
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showArtistPicker(BuildContext context) async {
    final artists = controller.artistChoices();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final searchQuery = ValueNotifier<String>('');

        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setState) {
              final filtered = searchQuery.value.isEmpty
                  ? artists
                  : artists
                        .where(
                          (a) =>
                              a.name.toLowerCase().contains(
                                searchQuery.value.toLowerCase(),
                              ) ||
                              a.key.toLowerCase().contains(
                                searchQuery.value.toLowerCase(),
                              ),
                        )
                        .toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      onChanged: (value) {
                        searchQuery.value = value;
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar artista...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No se encontraron artistas',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final artist = filtered[index];
                              final thumb = artist.thumbnail;
                              final hasImage =
                                  thumb != null && thumb.isNotEmpty;

                              return ListTile(
                                leading: hasImage
                                    ? CircleAvatar(
                                        backgroundImage:
                                            thumb.startsWith('http')
                                            ? NetworkImage(thumb)
                                                  as ImageProvider
                                            : FileImage(File(thumb))
                                                  as ImageProvider,
                                        radius: 20,
                                      )
                                    : CircleAvatar(
                                        radius: 20,
                                        backgroundColor:
                                            scheme.primaryContainer,
                                        child: Icon(
                                          Icons.person_rounded,
                                          color: scheme.onPrimaryContainer,
                                        ),
                                      ),
                                title: Text(artist.name),
                                subtitle: Text(
                                  '${artist.count} canción${artist.count != 1 ? 'es' : ''}',
                                ),
                                onTap: () {
                                  _addArtistSection(artistKey: artist.key);
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _EditableHomeWidgetRow extends StatelessWidget {
  const _EditableHomeWidgetRow({
    super.key,
    required this.id,
    required this.index,
    required this.enabled,
    required this.layout,
    required this.onToggle,
    this.onLayoutToggle,
  });

  final HomeWidgetId id;
  final int index;
  final bool enabled;
  final HomeCustomSectionLayout layout;
  final VoidCallback onToggle;
  final VoidCallback? onLayoutToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actionColor = enabled ? Colors.redAccent : Colors.green;
    final actionIcon = enabled ? Icons.remove_rounded : Icons.add_rounded;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            IconButton(
              onPressed: onToggle,
              visualDensity: VisualDensity.compact,
              icon: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: actionColor,
                ),
                child: Icon(actionIcon, color: Colors.white, size: 18),
              ),
            ),
            Icon(
              id.icon,
              size: 22,
              color: enabled
                  ? scheme.primary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.58),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: enabled
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    id.hasFixedLayout ? 'Vista especial' : layout.label,
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
            if (onLayoutToggle != null)
              IconButton(
                tooltip: 'Cambiar vista',
                onPressed: enabled ? onLayoutToggle : null,
                icon: Icon(
                  layout.icon,
                  color: enabled
                      ? scheme.onSurfaceVariant
                      : scheme.onSurfaceVariant.withValues(alpha: 0.36),
                ),
              ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
