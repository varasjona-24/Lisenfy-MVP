import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/local/local_library_store.dart';
import '../../../models/media_item.dart';

void openPlayerLyricsSheet(MediaItem item, {double heightFactor = 0.62}) {
  if (Get.isBottomSheetOpen ?? false) return;

  Get.bottomSheet<void>(
    FractionallySizedBox(
      heightFactor: heightFactor,
      child: PlayerLyricsSheet(item: item),
    ),
    isScrollControlled: true,
    useRootNavigator: true,
    ignoreSafeArea: false,
    isDismissible: true,
    enableDrag: true,
  );
}

class PlayerLyricsSheet extends StatefulWidget {
  const PlayerLyricsSheet({super.key, required this.item});

  final MediaItem item;

  @override
  State<PlayerLyricsSheet> createState() => _PlayerLyricsSheetState();
}

class _PlayerLyricsSheetState extends State<PlayerLyricsSheet> {
  static const Map<String, String> _langLabels = <String, String>{
    'es': 'Español',
    'en': 'Inglés',
    'ja': 'Japonés',
    'ja-romaji': 'Japonés (Romaji)',
    'ko': 'Coreano',
    'ko-romaja': 'Coreano (Romaja)',
    'pt': 'Portugués',
    'fr': 'Francés',
    'it': 'Italiano',
    'de': 'Alemán',
  };

  Map<String, String> _byLang = const <String, String>{};
  String _selectedLang = '';
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _applyItem(widget.item);
    _resolveLatestItem();
  }

  Map<String, String> _buildLyricsMap(MediaItem item) {
    final map = <String, String>{};

    final main = (item.lyrics ?? '').trim();
    final mainLang = (item.lyricsLanguage ?? 'es').trim().toLowerCase();
    if (main.isNotEmpty) {
      map[mainLang.isEmpty ? 'main' : mainLang] = main;
    }

    final translations = item.translations ?? const <String, String>{};
    for (final entry in translations.entries) {
      final key = entry.key.trim().toLowerCase();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      if (map[key] == value) continue;
      map[key] = value;
    }

    return map;
  }

  String _langLabel(String lang) => _langLabels[lang] ?? lang.toUpperCase();

  void _applyItem(MediaItem item) {
    final next = _buildLyricsMap(item);
    _byLang = next;
    if (next.isEmpty) {
      _selectedLang = '';
      return;
    }
    if (!next.containsKey(_selectedLang)) {
      _selectedLang = next.keys.first;
    }
  }

  Future<void> _resolveLatestItem() async {
    if (!Get.isRegistered<LocalLibraryStore>()) return;

    final baseId = widget.item.id.trim();
    final basePublicId = widget.item.publicId.trim();
    if (baseId.isEmpty && basePublicId.isEmpty) return;

    setState(() {
      _resolving = true;
    });

    try {
      final store = Get.find<LocalLibraryStore>();
      final all = await store.readAll();
      MediaItem? match;

      for (final entry in all) {
        if (baseId.isNotEmpty && entry.id.trim() == baseId) {
          match = entry;
          break;
        }
        if (basePublicId.isNotEmpty &&
            entry.publicId.trim().isNotEmpty &&
            entry.publicId.trim() == basePublicId) {
          match = entry;
          break;
        }
      }

      if (!mounted || match == null) return;
      setState(() {
        _applyItem(match!);
      });
    } finally {
      if (mounted) {
        setState(() {
          _resolving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lyrics = _selectedLang.isEmpty ? '' : (_byLang[_selectedLang] ?? '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.item.displaySubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (_byLang.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _byLang.keys
                  .map(
                    (lang) => ChoiceChip(
                      label: Text(_langLabel(lang)),
                      selected: _selectedLang == lang,
                      onSelected: (_) {
                        setState(() {
                          _selectedLang = lang;
                        });
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _resolving
                    ? const Center(child: CircularProgressIndicator())
                    : _byLang.isEmpty
                    ? Center(
                        child: Text(
                          'Esta canción no tiene letras guardadas.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: SelectableText(
                          lyrics,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
