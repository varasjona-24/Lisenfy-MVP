import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/local/local_library_store.dart';
import '../../../models/media_item.dart';
import '../../../services/audio_service.dart';
import '../../../services/karaoke_flow_coordinator_service.dart';

void openPlayerKaraokeSheet(
  MediaItem item, {
  double heightFactor = 0.92,
  String? topActionLabel,
  Future<void> Function()? onTopAction,
  bool showFlowStatus = false,
}) {
  if (Get.isBottomSheetOpen ?? false) return;

  Get.bottomSheet<void>(
    FractionallySizedBox(
      heightFactor: heightFactor,
      child: PlayerKaraokeSheet(
        item: item,
        topActionLabel: topActionLabel,
        onTopAction: onTopAction,
        showFlowStatus: showFlowStatus,
      ),
    ),
    isScrollControlled: true,
    useRootNavigator: true,
    ignoreSafeArea: false,
    isDismissible: true,
    enableDrag: true,
  );
}

class PlayerKaraokeSheet extends StatefulWidget {
  const PlayerKaraokeSheet({
    super.key,
    required this.item,
    this.topActionLabel,
    this.onTopAction,
    this.showFlowStatus = false,
  });

  final MediaItem item;
  final String? topActionLabel;
  final Future<void> Function()? onTopAction;
  final bool showFlowStatus;

  @override
  State<PlayerKaraokeSheet> createState() => _PlayerKaraokeSheetState();
}

class _PlayerKaraokeSheetState extends State<PlayerKaraokeSheet> {
  static const String _musicalBreakSymbol = '♪';
  static const int _fallbackLeadInMs = 420;
  static const int _fallbackTailMs = 280;
  static const int _fallbackMinLineMs = 780;
  static const int _fallbackMinBreakMs = 560;

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

  final ScrollController _scrollCtrl = ScrollController();
  final Map<int, GlobalKey> _lineKeys = <int, GlobalKey>{};

  Map<String, String> _byLang = const <String, String>{};
  Map<String, List<TimedLyricCue>> _timedByLang =
      const <String, List<TimedLyricCue>>{};
  String _selectedLang = '';
  bool _resolving = false;

  List<String> _lines = const <String>[];
  List<TimedLyricCue> _timedCues = const <TimedLyricCue>[];
  List<TimedLyricCue> _estimatedCues = const <TimedLyricCue>[];
  int _estimatedForDurationMs = -1;
  int _activeLine = 0;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  AudioService? _audioService;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;

  @override
  void initState() {
    super.initState();
    _applyItem(widget.item);
    _resolveLatestItem();
    _bindPlayback();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
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

  bool _isBreakLine(String text) => text.trim() == _musicalBreakSymbol;

  List<String> _normalizeLyricLinesWithBreaks(String raw) {
    final entries = raw.split(RegExp(r'\r?\n'));
    final out = <String>[];
    var previousWasBreak = false;

    for (final entry in entries) {
      final text = entry.replaceAll('\t', ' ').trim();
      if (text.isEmpty) {
        if (out.isNotEmpty && !previousWasBreak) {
          out.add(_musicalBreakSymbol);
          previousWasBreak = true;
        }
        continue;
      }
      out.add(text);
      previousWasBreak = false;
    }

    if (out.isNotEmpty && out.last == _musicalBreakSymbol) {
      out.removeLast();
    }
    return out;
  }

  List<TimedLyricCue> _retitleCuesByIndex(
    List<TimedLyricCue> cues,
    List<String> lines,
  ) {
    final maxLen = cues.length < lines.length ? cues.length : lines.length;
    final out = <TimedLyricCue>[];
    for (int i = 0; i < maxLen; i++) {
      final cue = cues[i];
      out.add(
        TimedLyricCue(text: lines[i], startMs: cue.startMs, endMs: cue.endMs),
      );
    }
    return out;
  }

  List<TimedLyricCue> _expandLegacyCuesWithBreaks(
    List<TimedLyricCue> cues,
    List<String> lines,
  ) {
    final sorted = List<TimedLyricCue>.from(cues)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    final out = <TimedLyricCue>[];
    var cueIndex = 0;

    for (final line in lines) {
      if (_isBreakLine(line)) {
        if (out.isEmpty || cueIndex >= sorted.length) continue;
        final prev = out.last;
        final next = sorted[cueIndex];
        var start = (prev.endMs ?? prev.startMs) + 1;
        var end = next.startMs - 1;
        if (start >= next.startMs) {
          start = next.startMs - 80;
          end = next.startMs - 1;
        }
        if (end < 0) continue;
        if (start < 0) start = 0;
        if (end < start) continue;
        out.add(
          TimedLyricCue(text: _musicalBreakSymbol, startMs: start, endMs: end),
        );
        continue;
      }

      if (cueIndex >= sorted.length) break;
      final cue = sorted[cueIndex++];
      out.add(
        TimedLyricCue(text: line, startMs: cue.startMs, endMs: cue.endMs),
      );
    }

    return out;
  }

  List<TimedLyricCue> _mergeTimedCuesWithBreaks(
    List<TimedLyricCue> cues,
    List<String> rawLines,
  ) {
    if (rawLines.isEmpty || cues.isEmpty) return cues;
    final sorted = List<TimedLyricCue>.from(cues)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    final hasBreaksInRaw = rawLines.any(_isBreakLine);
    if (!hasBreaksInRaw) {
      return _retitleCuesByIndex(sorted, rawLines);
    }

    final hasBreaksInCues = sorted.any((cue) => _isBreakLine(cue.text));
    final nonBreakCount = rawLines.where((line) => !_isBreakLine(line)).length;
    if (!hasBreaksInCues && sorted.length == nonBreakCount) {
      return _expandLegacyCuesWithBreaks(sorted, rawLines);
    }

    return _retitleCuesByIndex(sorted, rawLines);
  }

  Map<String, List<TimedLyricCue>> _buildTimedLyricsMap(MediaItem item) {
    final source = item.timedLyrics;
    if (source == null || source.isEmpty) {
      return const <String, List<TimedLyricCue>>{};
    }

    final out = <String, List<TimedLyricCue>>{};
    for (final entry in source.entries) {
      final lang = entry.key.trim().toLowerCase();
      if (lang.isEmpty || entry.value.isEmpty) continue;
      final cues = entry.value
          .where((cue) => cue.text.trim().isNotEmpty)
          .toList(growable: false);
      if (cues.isEmpty) continue;
      out[lang] = List<TimedLyricCue>.from(cues)
        ..sort((a, b) => a.startMs.compareTo(b.startMs));
    }
    return out;
  }

  void _applyItem(MediaItem item) {
    final next = _buildLyricsMap(item);
    final timed = _buildTimedLyricsMap(item);
    _byLang = next;
    _timedByLang = timed;
    final availableLangs = <String>{...next.keys, ...timed.keys};
    if (availableLangs.isEmpty) {
      _selectedLang = '';
      _lines = const <String>[];
      _timedCues = const <TimedLyricCue>[];
      _estimatedCues = const <TimedLyricCue>[];
      _estimatedForDurationMs = -1;
      _activeLine = 0;
      return;
    }
    if (!availableLangs.contains(_selectedLang)) {
      _selectedLang = next.keys.isNotEmpty ? next.keys.first : timed.keys.first;
    }
    _rebuildLinesForSelectedLanguage();
  }

  void _rebuildLinesForSelectedLanguage() {
    final timed = _timedByLang[_selectedLang] ?? const <TimedLyricCue>[];
    if (timed.isNotEmpty) {
      final rawLyrics = _selectedLang.isEmpty
          ? ''
          : (_byLang[_selectedLang] ?? '');
      final rawLines = _normalizeLyricLinesWithBreaks(rawLyrics);
      final mergedTimed = _mergeTimedCuesWithBreaks(timed, rawLines);
      _timedCues = mergedTimed.isEmpty ? timed : mergedTimed;
      _lines = _timedCues.map((cue) => cue.text).toList(growable: false);
      _estimatedCues = const <TimedLyricCue>[];
      _estimatedForDurationMs = -1;
      _activeLine = 0;
      _lineKeys
        ..clear()
        ..addEntries(
          Iterable<int>.generate(_lines.length).map((i) {
            return MapEntry<int, GlobalKey>(i, GlobalKey());
          }),
        );
      _syncActiveLine(scrollToLine: false);
      return;
    }

    _timedCues = const <TimedLyricCue>[];
    final raw = _selectedLang.isEmpty ? '' : (_byLang[_selectedLang] ?? '');
    final lines = _normalizeLyricLinesWithBreaks(raw);
    _lines = lines;
    _estimatedCues = const <TimedLyricCue>[];
    _estimatedForDurationMs = -1;

    if (lines.isEmpty) {
      _activeLine = 0;
      _lineKeys.clear();
      return;
    }
    _lineKeys
      ..clear()
      ..addEntries(
        Iterable<int>.generate(lines.length).map((i) {
          return MapEntry<int, GlobalKey>(i, GlobalKey());
        }),
      );

    _syncActiveLine(scrollToLine: false);
  }

  int _safeDurationMs() =>
      _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 0;

  int _lineWordCount(String text) {
    return RegExp(r'\S+').allMatches(text).length;
  }

  int _linePunctuationCount(String text) {
    return RegExp(r'[,:;.!?…]').allMatches(text).length;
  }

  double _lineWeight(String line) {
    if (_isBreakLine(line)) return 1.55;
    final trimmed = line.trim();
    if (trimmed.isEmpty) return 1.0;

    final words = _lineWordCount(trimmed);
    final chars = trimmed.runes.length;
    final punctuation = _linePunctuationCount(trimmed);
    final hasCjk = RegExp(
      r'[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7a3]',
    ).hasMatch(trimmed);
    final languageFactor = hasCjk ? 1.2 : 1.0;

    final base =
        (words * 1.15) +
        ((chars / 14.0) * languageFactor) +
        (punctuation * 0.4);
    return base.clamp(1.0, 14.0);
  }

  List<TimedLyricCue> _estimateCuesFromLines(
    List<String> lines,
    int durationMs,
  ) {
    if (lines.isEmpty || durationMs <= 0) return const <TimedLyricCue>[];

    final safeDuration = math.max(1, durationMs);
    final leadIn = math.min(_fallbackLeadInMs, safeDuration ~/ 8);
    final tail = math.min(_fallbackTailMs, safeDuration ~/ 10);
    final usable = math.max(1, safeDuration - leadIn - tail);

    final minDurations = lines
        .map(
          (line) =>
              _isBreakLine(line) ? _fallbackMinBreakMs : _fallbackMinLineMs,
        )
        .toList(growable: false);
    final minSum = minDurations.fold<int>(0, (sum, ms) => sum + ms);
    final minScale = minSum > usable ? (usable / minSum) : 1.0;

    final scaledMinimums = minDurations
        .map((ms) => math.max(160, (ms * minScale).round()))
        .toList(growable: false);
    final allocatedMin = scaledMinimums.fold<int>(0, (sum, ms) => sum + ms);
    final remaining = math.max(0, usable - allocatedMin);

    final weights = lines.map(_lineWeight).toList(growable: false);
    final weightSum = weights.fold<double>(0, (sum, w) => sum + w);

    final dynamicDurations = <int>[];
    for (int i = 0; i < lines.length; i++) {
      final extra = weightSum <= 0
          ? 0
          : ((weights[i] / weightSum) * remaining).round();
      dynamicDurations.add(scaledMinimums[i] + extra);
    }

    var consumed = dynamicDurations.fold<int>(0, (sum, ms) => sum + ms);
    final drift = usable - consumed;
    if (drift != 0 && dynamicDurations.isNotEmpty) {
      dynamicDurations[dynamicDurations.length - 1] += drift;
      consumed = dynamicDurations.fold<int>(0, (sum, ms) => sum + ms);
      if (consumed <= 0) return const <TimedLyricCue>[];
    }

    final cues = <TimedLyricCue>[];
    var cursor = leadIn;
    final maxMs = safeDuration - 1;
    for (int i = 0; i < lines.length; i++) {
      if (cursor > maxMs) break;
      final segment = math.max(120, dynamicDurations[i]);
      final isLast = i == lines.length - 1;
      final start = cursor.clamp(0, maxMs);
      final end = isLast
          ? maxMs
          : math.min(maxMs, math.max(start, start + segment - 1));
      cues.add(TimedLyricCue(text: lines[i], startMs: start, endMs: end));
      cursor = end + 1;
    }

    return cues;
  }

  void _ensureEstimatedCues() {
    if (_timedCues.isNotEmpty || _lines.isEmpty) {
      _estimatedCues = const <TimedLyricCue>[];
      _estimatedForDurationMs = -1;
      return;
    }

    final durationMs = _safeDurationMs();
    if (durationMs <= 0) return;
    if (_estimatedForDurationMs == durationMs && _estimatedCues.isNotEmpty) {
      return;
    }

    _estimatedCues = _estimateCuesFromLines(_lines, durationMs);
    _estimatedForDurationMs = durationMs;
  }

  int _activeLineFromCues(List<TimedLyricCue> cues, int posMs) {
    if (cues.isEmpty) return 0;
    if (posMs <= cues.first.startMs) return 0;

    for (int i = 0; i < cues.length; i++) {
      final cue = cues[i];
      final nextCue = i + 1 < cues.length ? cues[i + 1] : null;
      final start = cue.startMs;
      final inferredEnd = nextCue != null ? nextCue.startMs - 1 : null;
      int end = cue.endMs ?? inferredEnd ?? start + 4200;
      if (end < start) end = start;
      if (posMs >= start && posMs <= end) return i;
    }
    return cues.length - 1;
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

  void _bindPlayback() {
    if (!Get.isRegistered<AudioService>()) return;
    _audioService = Get.find<AudioService>();

    _posSub = _audioService!.positionStream.listen((pos) {
      _position = pos;
      _syncActiveLine();
    });

    _durSub = _audioService!.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        _duration = dur;
      }
      _syncActiveLine();
    });
  }

  int _computeActiveLine() {
    if (_timedCues.isNotEmpty) {
      return _activeLineFromCues(_timedCues, _position.inMilliseconds);
    }

    _ensureEstimatedCues();
    if (_estimatedCues.isNotEmpty) {
      return _activeLineFromCues(_estimatedCues, _position.inMilliseconds);
    }
    return _lines.isEmpty ? 0 : _lines.length - 1;
  }

  void _syncActiveLine({bool scrollToLine = true}) {
    final next = _computeActiveLine();
    if (next == _activeLine) return;

    setState(() {
      _activeLine = next;
    });

    if (!scrollToLine) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _lineKeys[_activeLine];
      final ctx = key?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.45,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final langKeys = <String>{..._byLang.keys, ..._timedByLang.keys}.toList()
      ..sort((a, b) => a.compareTo(b));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
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
                    const SizedBox(height: 2),
                    Text(
                      widget.item.displaySubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (widget.onTopAction != null)
                TextButton.icon(
                  onPressed: () async {
                    await widget.onTopAction?.call();
                  },
                  icon: const Icon(Icons.close_rounded),
                  label: Text(widget.topActionLabel ?? 'Cancelar'),
                ),
              IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close_rounded),
                onPressed: Get.back,
              ),
            ],
          ),
          if (widget.showFlowStatus &&
              Get.isRegistered<KaraokeFlowCoordinatorService>()) ...[
            const SizedBox(height: 8),
            Obx(() {
              final flow =
                  Get.find<KaraokeFlowCoordinatorService>().activeFlow.value;
              if (flow == null) return const SizedBox.shrink();
              final message = flow.error?.trim().isNotEmpty == true
                  ? flow.error!.trim()
                  : flow.message;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.outlineVariant),
                ),
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 8),
          if (langKeys.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: langKeys
                    .map((lang) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_langLabel(lang)),
                          selected: _selectedLang == lang,
                          onSelected: (_) {
                            setState(() {
                              _selectedLang = lang;
                              _rebuildLinesForSelectedLanguage();
                            });
                          },
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: _resolving
                    ? const Center(child: CircularProgressIndicator())
                    : _lines.isEmpty
                    ? Center(
                        child: Text(
                          'Esta canción no tiene letras para modo karaoke.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: color.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        itemCount: _lines.length,
                        itemBuilder: (context, index) {
                          final line = _lines[index];
                          final isBreak = line == _musicalBreakSymbol;
                          final isActive = index == _activeLine;
                          final distance = (index - _activeLine).abs();
                          final dim = math.min(1.0, distance / 6.0);
                          final alpha = (1.0 - dim * 0.65).clamp(0.25, 1.0);

                          return Container(
                            key: _lineKeys[index],
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: isActive
                                  ? color.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                            ),
                            child: Text(
                              line,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                fontSize: isBreak ? 16 : (isActive ? 22 : 18),
                                fontStyle: isBreak
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                height: 1.35,
                                color: color.onSurface.withValues(alpha: alpha),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
