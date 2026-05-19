part of '../home_page.dart';

Future<void> _openHomeEditorSheet(
  BuildContext context, {
  required HomeController controller,
  required HomeMode mode,
}) async {
  final nav = Get.isRegistered<NavigationController>()
      ? Get.find<NavigationController>()
      : null;
  nav?.setOverlayOpen(true);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _HomeWidgetEditor(controller: controller, mode: mode),
  ).whenComplete(() => nav?.setOverlayOpen(false));
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
    _order = controller
        .editableHomeWidgetOrderForMode(mode)
        .toList(growable: true);
    _enabled = controller.enabledHomeWidgetIdsForMode(mode).toSet();
    _layouts = Map<String, HomeCustomSectionLayout>.from(
      controller.homeWidgetLayouts,
    );
    _customSections =
        (mode == HomeMode.video
                ? controller.videoCustomHomeSections
                : controller.customHomeSections)
            .toList(growable: true);
  }

  List<HomeWidgetId> get _visibleItems {
    if (mode == HomeMode.video) {
      return _order
          .where((id) => id.videoHomeSupported)
          .toList(growable: false);
    }
    return _order.where((id) => !id.audioOnly).toList(growable: false);
  }

  HomeCustomSectionLayout _layoutForWidget(HomeWidgetId id) {
    if (mode == HomeMode.video) return HomeCustomSectionLayout.cards;
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
    if (mode == HomeMode.video) return;
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
      if (mode == HomeMode.video) {
        _order = HomeWidgetId.values
            .where((id) => id.videoHomeSupported)
            .toList(growable: true);
        _enabled = _order.toSet();
      } else {
        _order = HomeWidgetId.values.toList(growable: true);
        _enabled = HomeWidgetId.values.toSet();
      }
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

  Set<String> _selectedPlaylistIds() {
    HomeCustomSection? section;
    for (final entry in _customSections) {
      if (entry.id == 'playlists_custom') {
        section = entry;
        break;
      }
    }
    if (section == null) return <String>{};
    return section.targetId
        .split('|')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }

  Set<String> _selectedArtistKeys() {
    HomeCustomSection? section;
    for (final entry in _customSections) {
      if (entry.id == 'artists_custom') {
        section = entry;
        break;
      }
    }
    if (section == null) return <String>{};
    return section.targetId
        .split('|')
        .map(ArtistCreditParser.normalizeKey)
        .where((entry) => entry.isNotEmpty && entry != 'unknown')
        .toSet();
  }

  Set<String> _selectedCollectionIds() {
    HomeCustomSection? section;
    for (final entry in _customSections) {
      if (entry.id == 'collections_custom') {
        section = entry;
        break;
      }
    }
    if (section == null) return <String>{};
    return section.targetId
        .split('|')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
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

  void _addCollectionSection({required String collectionId}) {
    final cleanId = collectionId.trim();
    if (cleanId.isEmpty) return;
    const sectionId = 'collections_custom';
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
          kind: HomeCustomSectionKind.collection,
          targetId: ids.join('|'),
          title: 'Collections',
          layout: HomeCustomSectionLayout.cards,
        );
      } else {
        _customSections.add(
          HomeCustomSection(
            id: sectionId,
            kind: HomeCustomSectionKind.collection,
            targetId: cleanId,
            title: 'Collections',
          ),
        );
      }
    });
  }

  void _save() {
    controller.applyHomeLayoutSnapshot(
      mode: mode,
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
                        onLayoutToggle:
                            mode == HomeMode.video || id.hasFixedLayout
                            ? null
                            : () => _toggleWidgetLayout(id),
                      );
                    },
                  ),
                  if (mode == HomeMode.audio) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showPlaylistPicker(context),
                            icon: const Icon(
                              Icons.queue_music_rounded,
                              size: 18,
                            ),
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
                  ] else ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showCollectionPicker(context),
                        icon: const Icon(Icons.video_library_rounded, size: 18),
                        label: const Text('Collection'),
                      ),
                    ),
                  ],
                  if (_customSections.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._customSections.map((section) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            section.kind.icon,
                            color: scheme.primary,
                          ),
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
                                onPressed: mode == HomeMode.video
                                    ? null
                                    : () => _toggleCustomSectionLayout(
                                        section.id,
                                      ),
                                icon: Icon(section.layout.icon),
                              ),
                              IconButton(
                                tooltip: 'Quitar',
                                onPressed: () =>
                                    _removeCustomSection(section.id),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
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
    final existing = _selectedPlaylistIds();
    final playlists = controller
        .playlistChoices()
        .where((playlist) => !existing.contains(playlist.id))
        .toList(growable: false);
    if (!context.mounted) return;
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _HomePlaylistPickerSheet(
          playlists: playlists,
          totalCount: controller.playlistChoices().length,
        );
      },
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    for (final id in selected) {
      _addPlaylistSection(playlistId: id);
    }
  }

  Future<void> _showArtistPicker(BuildContext context) async {
    final existing = _selectedArtistKeys();
    final allArtists = controller.artistChoices();
    final artists = allArtists
        .where((artist) => !existing.contains(artist.key))
        .toList(growable: false);

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _HomeArtistPickerSheet(
          artists: artists,
          totalCount: allArtists.length,
        );
      },
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    for (final key in selected) {
      _addArtistSection(artistKey: key);
    }
  }

  Future<void> _showCollectionPicker(BuildContext context) async {
    final existing = _selectedCollectionIds();
    final allCollections = controller.collectionChoices();
    final collections = allCollections
        .where((collection) => !existing.contains(collection.id))
        .toList(growable: false);

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _HomeCollectionPickerSheet(
          collections: collections,
          totalCount: allCollections.length,
        );
      },
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    for (final id in selected) {
      _addCollectionSection(collectionId: id);
    }
  }
}

class _HomePlaylistPickerSheet extends StatefulWidget {
  const _HomePlaylistPickerSheet({
    required this.playlists,
    required this.totalCount,
  });

  final List<HomePlaylistChoice> playlists;
  final int totalCount;

  @override
  State<_HomePlaylistPickerSheet> createState() =>
      _HomePlaylistPickerSheetState();
}

class _HomePlaylistPickerSheetState extends State<_HomePlaylistPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selected = <String>{};
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HomePlaylistChoice> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.playlists;
    return widget.playlists
        .where((playlist) => playlist.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final query = _query.trim();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            _HomePickerHeader(
              icon: Icons.queue_music_rounded,
              title: 'Agregar playlists',
              searchController: _searchCtrl,
              searchHint: 'Buscar playlist',
              query: _query,
              onQueryChanged: (value) => setState(() => _query = value),
              onClear: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
              chips: [
                _HomePickerChipData(
                  icon: Icons.library_music_rounded,
                  label: '${widget.playlists.length} disponibles',
                ),
                _HomePickerChipData(
                  icon: Icons.check_circle_rounded,
                  label: '${_selected.length} seleccionadas',
                ),
                if (query.isNotEmpty)
                  _HomePickerChipData(
                    icon: Icons.filter_alt_rounded,
                    label: '${items.length} resultados',
                  ),
              ],
            ),
            Expanded(
              child: items.isEmpty
                  ? _HomePickerEmptyText(
                      text: query.isEmpty
                          ? widget.totalCount == 0
                                ? 'No hay playlists disponibles.'
                                : 'Todas las playlists ya estan en inicio.'
                          : 'No se encontraron playlists.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final playlist = items[index];
                        return _HomeChoiceTile(
                          selected: _selected.contains(playlist.id),
                          title: playlist.name,
                          subtitle:
                              '${playlist.count} cancion${playlist.count != 1 ? 'es' : ''}',
                          image: playlist.cover,
                          fallbackIcon: Icons.queue_music_rounded,
                          onTap: () => _toggle(playlist.id),
                        );
                      },
                    ),
            ),
            _HomePickerSubmitButton(
              selectedCount: _selected.length,
              emptyLabel: 'Selecciona playlists',
              activeLabel: 'Agregar ${_selected.length} seleccionadas',
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selected.toList()),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) {
        _selected.add(id);
      }
    });
  }
}

class _HomeArtistPickerSheet extends StatefulWidget {
  const _HomeArtistPickerSheet({
    required this.artists,
    required this.totalCount,
  });

  final List<HomeArtistChoice> artists;
  final int totalCount;

  @override
  State<_HomeArtistPickerSheet> createState() => _HomeArtistPickerSheetState();
}

class _HomeCollectionPickerSheet extends StatefulWidget {
  const _HomeCollectionPickerSheet({
    required this.collections,
    required this.totalCount,
  });

  final List<HomeCollectionChoice> collections;
  final int totalCount;

  @override
  State<_HomeCollectionPickerSheet> createState() =>
      _HomeCollectionPickerSheetState();
}

class _HomeCollectionPickerSheetState
    extends State<_HomeCollectionPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selected = <String>{};
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HomeCollectionChoice> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.collections;
    return widget.collections
        .where((collection) => collection.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final query = _query.trim();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            _HomePickerHeader(
              icon: Icons.video_library_rounded,
              title: 'Agregar Collections',
              searchController: _searchCtrl,
              searchHint: 'Buscar Collection',
              query: _query,
              onQueryChanged: (value) => setState(() => _query = value),
              onClear: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
              chips: [
                _HomePickerChipData(
                  icon: Icons.collections_bookmark_rounded,
                  label: '${widget.collections.length} disponibles',
                ),
                _HomePickerChipData(
                  icon: Icons.check_circle_rounded,
                  label: '${_selected.length} seleccionadas',
                ),
                if (query.isNotEmpty)
                  _HomePickerChipData(
                    icon: Icons.filter_alt_rounded,
                    label: '${items.length} resultados',
                  ),
              ],
            ),
            Expanded(
              child: items.isEmpty
                  ? _HomePickerEmptyText(
                      text: query.isEmpty
                          ? widget.totalCount == 0
                                ? 'No hay Collections disponibles.'
                                : 'Todas las Collections ya estan en inicio.'
                          : 'No se encontraron Collections.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final collection = items[index];
                        return _HomeChoiceTile(
                          selected: _selected.contains(collection.id),
                          title: collection.name,
                          subtitle:
                              '${collection.count} item${collection.count != 1 ? 's' : ''}',
                          image: collection.cover,
                          fallbackIcon: Icons.video_library_rounded,
                          onTap: () => _toggle(collection.id),
                        );
                      },
                    ),
            ),
            _HomePickerSubmitButton(
              selectedCount: _selected.length,
              emptyLabel: 'Selecciona Collections',
              activeLabel: 'Agregar ${_selected.length} seleccionadas',
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selected.toList()),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) {
        _selected.add(id);
      }
    });
  }
}

class _HomeArtistPickerSheetState extends State<_HomeArtistPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selected = <String>{};
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HomeArtistChoice> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.artists;
    return widget.artists
        .where(
          (artist) =>
              artist.name.toLowerCase().contains(query) ||
              artist.key.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final query = _query.trim();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            _HomePickerHeader(
              icon: Icons.person_add_alt_rounded,
              title: 'Agregar artistas',
              searchController: _searchCtrl,
              searchHint: 'Buscar artista',
              query: _query,
              onQueryChanged: (value) => setState(() => _query = value),
              onClear: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
              chips: [
                _HomePickerChipData(
                  icon: Icons.groups_rounded,
                  label: '${widget.artists.length} disponibles',
                ),
                _HomePickerChipData(
                  icon: Icons.check_circle_rounded,
                  label: '${_selected.length} seleccionados',
                ),
                if (query.isNotEmpty)
                  _HomePickerChipData(
                    icon: Icons.filter_alt_rounded,
                    label: '${items.length} resultados',
                  ),
              ],
            ),
            Expanded(
              child: items.isEmpty
                  ? _HomePickerEmptyText(
                      text: query.isEmpty
                          ? widget.totalCount == 0
                                ? 'No hay artistas disponibles.'
                                : 'Todos los artistas ya estan en inicio.'
                          : 'No se encontraron artistas.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final artist = items[index];
                        return _HomeChoiceTile(
                          selected: _selected.contains(artist.key),
                          title: artist.name,
                          subtitle:
                              '${artist.count} cancion${artist.count != 1 ? 'es' : ''}',
                          image: artist.thumbnail,
                          fallbackIcon: Icons.person_rounded,
                          circleImage: true,
                          onTap: () => _toggle(artist.key),
                        );
                      },
                    ),
            ),
            _HomePickerSubmitButton(
              selectedCount: _selected.length,
              emptyLabel: 'Selecciona artistas',
              activeLabel: 'Agregar ${_selected.length} seleccionados',
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selected.toList()),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(String key) {
    setState(() {
      if (!_selected.remove(key)) {
        _selected.add(key);
      }
    });
  }
}

class _HomePickerHeader extends StatelessWidget {
  const _HomePickerHeader({
    required this.icon,
    required this.title,
    required this.searchController,
    required this.searchHint,
    required this.query,
    required this.onQueryChanged,
    required this.onClear,
    required this.chips,
  });

  final IconData icon;
  final String title;
  final TextEditingController searchController;
  final String searchHint;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final List<_HomePickerChipData> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.trim().isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: onClear,
                    ),
              hintText: searchHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in chips)
                Chip(
                  avatar: Icon(chip.icon, size: 18),
                  label: Text(chip.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomePickerChipData {
  const _HomePickerChipData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _HomePickerEmptyText extends StatelessWidget {
  const _HomePickerEmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _HomePickerSubmitButton extends StatelessWidget {
  const _HomePickerSubmitButton({
    required this.selectedCount,
    required this.emptyLabel,
    required this.activeLabel,
    required this.onPressed,
  });

  final int selectedCount;
  final String emptyLabel;
  final String activeLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add_rounded),
          label: Text(selectedCount == 0 ? emptyLabel : activeLabel),
        ),
      ),
    );
  }
}

class _HomeChoiceTile extends StatelessWidget {
  const _HomeChoiceTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.fallbackIcon,
    required this.onTap,
    this.circleImage = false,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final String? image;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final bool circleImage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = _homeImageProvider(image);
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(circleImage ? 24 : 10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: provider == null
                ? ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(fallbackIcon),
                  )
                : Image(image: provider, fit: BoxFit.cover),
          ),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Checkbox(value: selected, onChanged: (_) => onTap()),
      ),
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
