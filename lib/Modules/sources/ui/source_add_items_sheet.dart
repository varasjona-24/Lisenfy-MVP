import 'package:flutter/material.dart';

import '../../../app/models/media_item.dart';
import 'source_media_list_item.dart';

class SourceAddItemsSheet extends StatefulWidget {
  const SourceAddItemsSheet({
    super.key,
    required this.items,
    required this.keyForItem,
    required this.onAdd,
  });

  final List<MediaItem> items;
  final String Function(MediaItem item) keyForItem;
  final Future<void> Function(List<MediaItem> selected) onAdd;

  @override
  State<SourceAddItemsSheet> createState() => _SourceAddItemsSheetState();
}

class _SourceAddItemsSheetState extends State<SourceAddItemsSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selected = <String>{};
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MediaItem> get _filteredItems {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.items;
    return widget.items
        .where((item) {
          return item.title.toLowerCase().contains(query) ||
              item.displaySubtitle.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = _filteredItems;
    final hasVideoItems = widget.items.any((item) => item.hasVideoLocal);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.playlist_add_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Agregar items',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
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
                    controller: _searchCtrl,
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                      hintText: hasVideoItems
                          ? 'Buscar por titulo'
                          : 'Buscar por cancion o artista',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(
                          Icons.library_music_rounded,
                          size: 18,
                        ),
                        label: Text('${widget.items.length} disponibles'),
                      ),
                      Chip(
                        avatar: const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                        ),
                        label: Text('${_selected.length} seleccionados'),
                      ),
                      if (_query.trim().isNotEmpty)
                        Chip(
                          avatar: const Icon(
                            Icons.filter_alt_rounded,
                            size: 18,
                          ),
                          label: Text('${items.length} resultados'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.items.isEmpty
                              ? 'No hay items disponibles para esta Collection.'
                              : 'No se encontraron items.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final key = widget.keyForItem(item);
                        final checked = _selected.contains(key);
                        return _SelectableSourceItem(
                          item: item,
                          selected: checked,
                          videoStyle: hasVideoItems && item.hasVideoLocal,
                          onTap: () => _toggle(key, checked),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty ? null : _addSelected,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    _selected.isEmpty
                        ? 'Selecciona items'
                        : 'Agregar ${_selected.length} seleccionados',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(String key, bool checked) {
    setState(() {
      if (checked) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  Future<void> _addSelected() async {
    final selectedItems = widget.items
        .where((item) {
          return _selected.contains(widget.keyForItem(item));
        })
        .toList(growable: false);
    await widget.onAdd(selectedItems);
    if (mounted) Navigator.of(context).pop();
  }
}

class _SelectableSourceItem extends StatelessWidget {
  const _SelectableSourceItem({
    required this.item,
    required this.selected,
    required this.videoStyle,
    required this.onTap,
  });

  final MediaItem item;
  final bool selected;
  final bool videoStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.48)
          : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              videoStyle ? 10 : 0,
              videoStyle ? 10 : 0,
              42,
              videoStyle ? 10 : 0,
            ),
            child: SourceMediaListItem(
              item: item,
              videoStyle: videoStyle,
              onTap: onTap,
              onLongPress: onTap,
              onMore: onTap,
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Checkbox(value: selected, onChanged: (_) => onTap()),
            ),
          ),
        ],
      ),
    );
  }
}
