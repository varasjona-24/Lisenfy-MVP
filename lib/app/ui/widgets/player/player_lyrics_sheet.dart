import 'dart:async';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/local/local_library_store.dart';
import '../../../models/media_item.dart';
import '../../../services/audio_service.dart';

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
  static const Set<String> _langCodes = <String>{
    'es',
    'en',
    'ja',
    'ja-romaji',
    'ko',
    'ko-romaja',
    'pt',
    'fr',
    'it',
    'de',
  };

  Map<String, String> _byLang = const <String, String>{};
  Map<String, List<TimedLyricCue>> _timedByLang =
      const <String, List<TimedLyricCue>>{};
  String _selectedLang = '';
  bool _resolving = false;
  Duration _playbackPosition = Duration.zero;
  int _lastAutoScrolledIndex = -1;

  final ScrollController _lyricsScrollController = ScrollController();
  List<GlobalKey> _cueKeys = const <GlobalKey>[];
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _bindAudioService();
    _applyItem(widget.item);
    _resolveLatestItem();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _bindAudioService() {
    if (!Get.isRegistered<AudioService>()) return;
    final audioService = Get.find<AudioService>();
    _playbackPosition = audioService.currentPosition;
    _positionSub = audioService.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _playbackPosition = position;
      });
      _scheduleActiveCueScroll();
    });
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

  String _langLabel(String lang) {
    final normalized = lang.trim().toLowerCase();
    return switch (normalized) {
      'ja-romaji' => tr('player.languages.ja_romaji'),
      'ko-romaja' => tr('player.languages.ko_romaja'),
      _ when _langCodes.contains(normalized) => tr(
        'player.languages.$normalized',
      ),
      _ => lang.toUpperCase(),
    };
  }

  void _applyItem(MediaItem item) {
    final next = _buildLyricsMap(item);
    final timed = _buildTimedLyricsMap(item);
    _byLang = next;
    _timedByLang = timed;
    if (next.isEmpty) {
      _selectedLang = '';
      return;
    }
    if (!next.containsKey(_selectedLang)) {
      _selectedLang = next.keys.first;
      _lastAutoScrolledIndex = -1;
    }
  }

  Map<String, List<TimedLyricCue>> _buildTimedLyricsMap(MediaItem item) {
    final raw = item.timedLyrics ?? const <String, List<TimedLyricCue>>{};
    final out = <String, List<TimedLyricCue>>{};
    for (final entry in raw.entries) {
      final key = entry.key.trim().toLowerCase();
      if (key.isEmpty) continue;
      final cues =
          entry.value
              .where((cue) => cue.text.trim().isNotEmpty)
              .toList(growable: false)
            ..sort((a, b) => a.startMs.compareTo(b.startMs));
      if (cues.isEmpty) continue;
      out[key] = cues;
    }
    return out;
  }

  int _activeCueIndex(List<TimedLyricCue> cues, int positionMs) {
    if (cues.isEmpty) return -1;
    if (positionMs < cues.first.startMs) return -1;

    for (var i = 0; i < cues.length; i++) {
      final cue = cues[i];
      final next = i + 1 < cues.length ? cues[i + 1] : null;
      final endMs = cue.endMs ?? next?.startMs;
      if (endMs == null) return i;
      if (positionMs >= cue.startMs && positionMs < endMs) return i;
    }

    return cues.length - 1;
  }

  void _scheduleActiveCueScroll() {
    final cues = _timedByLang[_selectedLang] ?? const <TimedLyricCue>[];
    final activeIndex = _activeCueIndex(cues, _playbackPosition.inMilliseconds);
    if (activeIndex < 0 || activeIndex == _lastAutoScrolledIndex) return;
    _lastAutoScrolledIndex = activeIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || activeIndex >= _cueKeys.length) return;
      final context = _cueKeys[activeIndex].currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.38,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  void _syncCueKeys(int count) {
    if (_cueKeys.length == count) return;
    _cueKeys = List<GlobalKey>.generate(count, (_) => GlobalKey());
    _lastAutoScrolledIndex = -1;
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
    final timedCues = _timedByLang[_selectedLang] ?? const <TimedLyricCue>[];
    final activeCueIndex = _activeCueIndex(
      timedCues,
      _playbackPosition.inMilliseconds,
    );
    _syncCueKeys(timedCues.length);

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
                          _lastAutoScrolledIndex = -1;
                        });
                        _scheduleActiveCueScroll();
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
                          tr('player.lyrics.empty'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : timedCues.isNotEmpty
                    ? _TimedLyricsView(
                        cues: timedCues,
                        activeIndex: activeCueIndex,
                        scrollController: _lyricsScrollController,
                        cueKeys: _cueKeys,
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

class _TimedLyricsView extends StatelessWidget {
  const _TimedLyricsView({
    required this.cues,
    required this.activeIndex,
    required this.scrollController,
    required this.cueKeys,
  });

  final List<TimedLyricCue> cues;
  final int activeIndex;
  final ScrollController scrollController;
  final List<GlobalKey> cueKeys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List<Widget>.generate(cues.length, (index) {
          final cue = cues[index];
          final isActive = index == activeIndex;
          final isPast = activeIndex >= 0 && index < activeIndex;
          return Padding(
            padding: EdgeInsets.only(bottom: index == cues.length - 1 ? 0 : 6),
            child: AnimatedContainer(
              key: index < cueKeys.length ? cueKeys[index] : null,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.74)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                cue.text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isActive
                      ? theme.colorScheme.onPrimaryContainer
                      : isPast
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  height: 1.28,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
