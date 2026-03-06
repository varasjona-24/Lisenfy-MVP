import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_listenfy/app/ui/widgets/dialogs/lyrics_search_dialog.dart';

import 'package:flutter_listenfy/app/models/media_item.dart';
import 'package:flutter_listenfy/app/services/audio_service.dart';
import 'package:flutter_listenfy/app/services/lyrics_service.dart';

class LyricsEntryArgs {
  final String title;
  final String artist;
  final String? lyrics;
  final String? lyricsLanguage;
  final Map<String, String>? translations;
  final Map<String, List<TimedLyricCue>>? timedLyrics;

  const LyricsEntryArgs({
    required this.title,
    required this.artist,
    this.lyrics,
    this.lyricsLanguage,
    this.translations,
    this.timedLyrics,
  });
}

class LyricsEntryResult {
  final String lyrics;
  final String lyricsLanguage;
  final Map<String, String> translations;
  final Map<String, List<TimedLyricCue>> timedLyrics;

  const LyricsEntryResult({
    required this.lyrics,
    required this.lyricsLanguage,
    required this.translations,
    required this.timedLyrics,
  });
}

class LyricsEntryPage extends StatefulWidget {
  const LyricsEntryPage({super.key});

  @override
  State<LyricsEntryPage> createState() => _LyricsEntryPageState();
}

class _LyricsEntryPageState extends State<LyricsEntryPage> {
  static const String _musicalBreakSymbol = '♪';

  static const Map<String, String> _languageLabels = {
    'es': 'Español',
    'en': 'Inglés',
    'ja': 'Japonés',
    'ko': 'Coreano',
    'pt': 'Portugués',
    'fr': 'Francés',
    'it': 'Italiano',
    'de': 'Alemán',
  };

  static const Map<String, String> _extraTranslationLabels = {
    'ja-romaji': 'Japonés (Romaji)',
    'ko-romaja': 'Coreano (Romaja)',
  };

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _lyricsController = TextEditingController();
  final TextEditingController _translationPreviewController =
      TextEditingController();

  final Map<String, String> _translations = <String, String>{};
  final Map<String, List<TimedLyricCue>> _timedLyrics =
      <String, List<TimedLyricCue>>{};

  bool _loading = false;
  String _lyricsLang = 'es';
  String _targetLang = 'en';
  String _activePreviewKey = 'en';

  AudioService? _audioService;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  Future<void> _searchLyrics() async {
    final query = "${_titleController.text} ${_artistController.text}".trim();
    if (query.isEmpty) {
      Get.snackbar(
        'Letras',
        'Ingresa titulo o artista para buscar.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final result = await Get.dialog<String>(
      LyricsSearchDialog(initialQuery: query),
    );
    if (result != null && mounted) {
      if (result.trim().isEmpty) return;
      final normalized = _normalizeSelectedLyrics(result);
      setState(() {
        // Se pega exactamente lo seleccionado por el usuario.
        _lyricsController.text = normalized;
      });
    }
  }

  String _normalizeSelectedLyrics(String value) {
    var out = value;
    out = out.replaceAll('\r\n', '\n');
    out = out.replaceAll(r'\r\n', '\n');
    out = out.replaceAll(r'\n', '\n');
    out = out.replaceAll(r'\t', '\t');
    return out;
  }

  void _bindAudioService() {
    if (!Get.isRegistered<AudioService>()) return;
    _audioService = Get.find<AudioService>();

    _positionSub = _audioService!.positionStream.listen((pos) {
      _playbackPosition = pos;
      if (mounted) setState(() {});
    });

    _durationSub = _audioService!.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        _playbackDuration = dur;
        if (mounted) setState(() {});
      }
    });
  }

  List<String> _primaryLyricsLines() {
    final raw = _lyricsController.text.replaceAll('\r\n', '\n').split('\n');
    final out = <String>[];
    var previousWasBreak = false;

    for (final line in raw) {
      final text = line.trim();
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

  List<TimedLyricCue> _sortedCues(List<TimedLyricCue> cues) {
    final out = List<TimedLyricCue>.from(cues)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    return out;
  }

  bool _isBreakLine(String text) => text.trim() == _musicalBreakSymbol;

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
    return _sortedCues(out);
  }

  List<TimedLyricCue> _expandLegacyCuesWithBreaks(
    List<TimedLyricCue> cues,
    List<String> lines,
  ) {
    final sorted = _sortedCues(cues);
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

    return _sortedCues(out);
  }

  List<TimedLyricCue> _normalizeCuesAgainstLines(
    List<TimedLyricCue> cues,
    List<String> lines,
  ) {
    if (lines.isEmpty || cues.isEmpty) return const <TimedLyricCue>[];
    final sorted = _sortedCues(cues);
    final hasBreaksInLines = lines.any(_isBreakLine);
    if (!hasBreaksInLines) {
      return _retitleCuesByIndex(sorted, lines);
    }

    final hasBreaksInCues = sorted.any((cue) => _isBreakLine(cue.text));
    final nonBreakCount = lines.where((line) => !_isBreakLine(line)).length;
    if (!hasBreaksInCues && sorted.length == nonBreakCount) {
      return _expandLegacyCuesWithBreaks(sorted, lines);
    }

    return _retitleCuesByIndex(sorted, lines);
  }

  List<TimedLyricCue> _closeCueEnds(List<TimedLyricCue> cues) {
    if (cues.isEmpty) return const <TimedLyricCue>[];
    final sorted = _sortedCues(cues);
    final out = <TimedLyricCue>[];
    final maxDurationMs = _playbackDuration.inMilliseconds;

    for (int i = 0; i < sorted.length; i++) {
      final current = sorted[i];
      final next = i + 1 < sorted.length ? sorted[i + 1] : null;
      int? endMs = current.endMs;
      if (next != null) {
        final candidate = next.startMs - 1;
        endMs = candidate > current.startMs ? candidate : current.startMs + 120;
      } else if (maxDurationMs > current.startMs) {
        endMs = maxDurationMs;
      }
      out.add(
        TimedLyricCue(
          text: current.text,
          startMs: current.startMs,
          endMs: endMs,
        ),
      );
    }

    return out;
  }

  List<TimedLyricCue> _currentLangTimedCues() {
    final current = _timedLyrics[_lyricsLang] ?? const <TimedLyricCue>[];
    final lines = _primaryLyricsLines();
    return _normalizeCuesAgainstLines(current, lines);
  }

  String _formatMs(int ms) {
    final safe = ms < 0 ? 0 : ms;
    final dur = Duration(milliseconds: safe);
    final m = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = dur.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs = ((dur.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }

  Map<String, List<TimedLyricCue>> _parseTimedLyricsFromDynamic(Map raw) {
    final out = <String, List<TimedLyricCue>>{};
    for (final entry in raw.entries) {
      final lang = entry.key.toString().trim().toLowerCase();
      if (lang.isEmpty) continue;
      final listRaw = entry.value;
      if (listRaw is! List) continue;
      final cues = <TimedLyricCue>[];
      for (final cueRaw in listRaw) {
        if (cueRaw is! Map) continue;
        final cue = TimedLyricCue.fromJson(Map<String, dynamic>.from(cueRaw));
        if (cue.text.trim().isEmpty) continue;
        cues.add(cue);
      }
      if (cues.isEmpty) continue;
      out[lang] = _sortedCues(cues);
    }
    return out;
  }

  Future<void> _togglePlayback() async {
    if (_audioService == null) return;
    await _audioService!.toggle();
    if (mounted) setState(() {});
  }

  Future<void> _seekBackTwoSeconds() async {
    if (_audioService == null) return;
    final nextMs = (_playbackPosition.inMilliseconds - 2000).clamp(0, 1 << 31);
    await _audioService!.seek(Duration(milliseconds: nextMs));
  }

  Future<void> _seekToStart() async {
    if (_audioService == null) return;
    await _audioService!.seek(Duration.zero);
  }

  void _clearCurrentLanguageTiming() {
    setState(() {
      _timedLyrics.remove(_lyricsLang);
    });
  }

  void _undoLastCue() {
    final current = List<TimedLyricCue>.from(
      _timedLyrics[_lyricsLang] ?? const <TimedLyricCue>[],
    );
    if (current.isEmpty) return;

    current.removeLast();
    if (current.isNotEmpty) {
      final prev = current.last;
      current[current.length - 1] = TimedLyricCue(
        text: prev.text,
        startMs: prev.startMs,
      );
    }
    setState(() {
      if (current.isEmpty) {
        _timedLyrics.remove(_lyricsLang);
      } else {
        _timedLyrics[_lyricsLang] = current;
      }
    });
  }

  void _markNextCue() {
    if (_audioService == null) {
      Get.snackbar(
        'Karaoke',
        'Reproduce la canción en el player para sincronizar.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final lines = _primaryLyricsLines();
    if (lines.isEmpty) {
      Get.snackbar(
        'Karaoke',
        'Primero agrega la letra principal.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final current = _normalizeCuesAgainstLines(
      _timedLyrics[_lyricsLang] ?? const <TimedLyricCue>[],
      lines,
    );

    if (current.length >= lines.length) {
      Get.snackbar(
        'Karaoke',
        'Todas las lineas ya fueron marcadas.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    int startMs = _playbackPosition.inMilliseconds;
    if (current.isNotEmpty && startMs <= current.last.startMs) {
      startMs = current.last.startMs + 120;
    }
    if (startMs < 0) startMs = 0;

    final updated = List<TimedLyricCue>.from(current);
    if (updated.isNotEmpty) {
      final prev = updated.last;
      final prevEnd = startMs > prev.startMs ? startMs - 1 : prev.startMs + 120;
      updated[updated.length - 1] = TimedLyricCue(
        text: prev.text,
        startMs: prev.startMs,
        endMs: prevEnd,
      );
    }

    updated.add(
      TimedLyricCue(text: lines[updated.length], startMs: startMs, endMs: null),
    );

    setState(() {
      _timedLyrics[_lyricsLang] = updated;
    });
  }

  Future<void> _translateLyrics() async {
    if (_lyricsController.text.isEmpty) return;
    if (_targetLang == _lyricsLang) {
      Get.snackbar(
        'Traduccion',
        'El idioma objetivo debe ser diferente al idioma principal.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _loading = true);
    final translated = await LyricsService.translateLyricsDetailed(
      _lyricsController.text,
      _targetLang,
      sourceLang: _lyricsLang,
    );
    if (mounted) {
      final translatedText = translated?.translated.trim() ?? '';
      if (translatedText.isNotEmpty) {
        final clean = translatedText;
        _translationPreviewController.text = clean;
        _translations[_targetLang] = clean;
        _activePreviewKey = _targetLang;
        final romanizedKey = _romanizationKeyForLang(_targetLang);
        final romanizedText = translated?.romanized?.trim() ?? '';
        if (romanizedKey != null) {
          if (romanizedText.isNotEmpty) {
            _translations[romanizedKey] = romanizedText;
          } else {
            _translations.remove(romanizedKey);
          }
        }
      } else {
        Get.snackbar(
          'Traduccion',
          'No se pudo traducir en este momento.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _bindAudioService();
    _hydrateFromArgs(Get.arguments);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _titleController.dispose();
    _artistController.dispose();
    _lyricsController.dispose();
    _translationPreviewController.dispose();
    super.dispose();
  }

  void _hydrateFromArgs(dynamic args) {
    LyricsEntryArgs? entryArgs;
    if (args is LyricsEntryArgs) {
      entryArgs = args;
    } else if (args is Map) {
      final map = Map<String, dynamic>.from(args);
      final rawTranslations = map['translations'];
      final rawTimedLyrics = map['timedLyrics'];
      entryArgs = LyricsEntryArgs(
        title: (map['title'] ?? '').toString(),
        artist: (map['artist'] ?? '').toString(),
        lyrics: map['lyrics']?.toString(),
        lyricsLanguage: map['lyricsLanguage']?.toString(),
        translations: rawTranslations is Map
            ? rawTranslations.map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              )
            : null,
        timedLyrics: rawTimedLyrics is Map
            ? _parseTimedLyricsFromDynamic(rawTimedLyrics)
            : null,
      );
    }

    if (entryArgs == null) return;

    _titleController.text = entryArgs.title.trim();
    _artistController.text = entryArgs.artist.trim();
    _lyricsController.text = (entryArgs.lyrics ?? '').trim();

    final rawMainLang = (entryArgs.lyricsLanguage ?? '').trim().toLowerCase();
    if (_languageLabels.containsKey(rawMainLang)) {
      _lyricsLang = rawMainLang;
    }
    _targetLang = _lyricsLang == 'es' ? 'en' : 'es';
    _activePreviewKey = _targetLang;

    final initialTranslations = entryArgs.translations ?? const {};
    for (final entry in initialTranslations.entries) {
      final key = entry.key.trim().toLowerCase();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      _translations[key] = value;
    }

    final initialTimedLyrics = entryArgs.timedLyrics ?? const {};
    for (final entry in initialTimedLyrics.entries) {
      final key = entry.key.trim().toLowerCase();
      if (key.isEmpty || entry.value.isEmpty) continue;
      _timedLyrics[key] = _sortedCues(entry.value);
    }
    _translationPreviewController.text = _translations[_activePreviewKey] ?? '';
    _ensureLanguageStateSanity();
  }

  List<DropdownMenuItem<String>> _languageItems() {
    return _languageLabels.entries
        .map(
          (entry) =>
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        )
        .toList(growable: false);
  }

  void _applyPreviewAsPrimaryLyrics() {
    final preview = _translationPreviewController.text.trim();
    if (preview.isEmpty) return;
    setState(() {
      _lyricsController.text = preview;
      _lyricsLang = _targetLang;
      _targetLang = _lyricsLang == 'es' ? 'en' : 'es';
      _activePreviewKey = _targetLang;
      _translationPreviewController.text =
          _translations[_activePreviewKey] ?? '';
    });
  }

  void _removeTranslation(String lang) {
    setState(() {
      final key = lang.trim().toLowerCase();
      _translations.remove(key);
      if (key == 'ja' || key == 'ko') {
        final romanizedKey = _romanizationKeyForLang(key);
        if (romanizedKey != null) {
          _translations.remove(romanizedKey);
        }
      }
      if (_activePreviewKey == key) {
        _activePreviewKey = _targetLang;
        _translationPreviewController.text =
            _translations[_activePreviewKey] ?? '';
      }
    });
  }

  void _ensureLanguageStateSanity() {
    if (!_languageLabels.containsKey(_targetLang)) {
      _targetLang = _lyricsLang == 'es' ? 'en' : 'es';
    }
    if (_activePreviewKey.trim().isEmpty) {
      _activePreviewKey = _targetLang;
    }
  }

  String? _romanizationKeyForLang(String lang) {
    final key = lang.trim().toLowerCase();
    if (key == 'ja') return 'ja-romaji';
    if (key == 'ko') return 'ko-romaja';
    return null;
  }

  String _translationLabel(String key) {
    final normalized = key.trim().toLowerCase();
    return _extraTranslationLabels[normalized] ??
        _languageLabels[normalized] ??
        key;
  }

  void _save() {
    final lyrics = _lyricsController.text.trim();
    final cleanedTranslations = <String, String>{};
    for (final entry in _translations.entries) {
      final key = entry.key.trim().toLowerCase();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      if (key == _lyricsLang && value == lyrics) continue;
      cleanedTranslations[key] = value;
    }

    final cleanedTimedLyrics = <String, List<TimedLyricCue>>{};
    for (final entry in _timedLyrics.entries) {
      final key = entry.key.trim().toLowerCase();
      if (key.isEmpty) continue;
      var cues = _sortedCues(entry.value);
      if (key == _lyricsLang) {
        cues = _normalizeCuesAgainstLines(cues, _primaryLyricsLines());
      }
      cues = _closeCueEnds(
        cues,
      ).where((cue) => cue.text.trim().isNotEmpty).toList(growable: false);
      if (cues.isEmpty) continue;
      cleanedTimedLyrics[key] = cues;
    }

    Get.back(
      result: LyricsEntryResult(
        lyrics: lyrics,
        lyricsLanguage: _lyricsLang,
        translations: cleanedTranslations,
        timedLyrics: cleanedTimedLyrics,
      ),
    );
  }

  Widget _languageDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey('lang-$value'),
      initialValue: value,
      items: _languageItems(),
      onChanged: onChanged,
      decoration: const InputDecoration(border: OutlineInputBorder()),
    );
  }

  Widget _buildKaraokeSyncCard(ThemeData theme) {
    final lines = _primaryLyricsLines();
    final cues = _currentLangTimedCues();
    final canSync = _audioService != null;
    final isPlaying = _audioService?.isPlaying.value ?? false;
    final currentMs = _playbackPosition.inMilliseconds;
    final durationMs = _playbackDuration.inMilliseconds;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sincronizacion karaoke',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              canSync
                  ? 'Marca cada linea mientras suena la cancion.'
                  : 'Abre y reproduce la cancion en el player para sincronizar.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: canSync ? _togglePlayback : null,
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(isPlaying ? 'Pausar' : 'Reproducir'),
                ),
                OutlinedButton.icon(
                  onPressed: canSync ? _seekBackTwoSeconds : null,
                  icon: const Icon(Icons.replay_10_rounded),
                  label: const Text('-2s'),
                ),
                OutlinedButton.icon(
                  onPressed: canSync ? _seekToStart : null,
                  icon: const Icon(Icons.first_page_rounded),
                  label: const Text('Inicio'),
                ),
                FilledButton.icon(
                  onPressed: canSync ? _markNextCue : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Marcar linea'),
                ),
                OutlinedButton.icon(
                  onPressed: cues.isEmpty ? null : _undoLastCue,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Deshacer'),
                ),
                OutlinedButton.icon(
                  onPressed: cues.isEmpty ? null : _clearCurrentLanguageTiming,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Tiempo: ${_formatMs(currentMs)}'
              '${durationMs > 0 ? ' / ${_formatMs(durationMs)}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Idioma ${_lyricsLang.toUpperCase()}: ${cues.length}/${lines.length} lineas/pausas sincronizadas',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (cues.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...cues
                  .take(10)
                  .map(
                    (cue) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${_formatMs(cue.startMs)}  ${cue.text}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
              if (cues.length > 10)
                Text(
                  '+${cues.length - 10} lineas mas',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureLanguageStateSanity();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Letras')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Titulo'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Artista'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _loading ? null : _searchLyrics,
              icon: const Icon(Icons.search),
              label: const Text('Buscar letras en web'),
            ),
            const SizedBox(height: 12),
            Text(
              'Idioma de letra principal',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            _languageDropdown(
              value: _lyricsLang,
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  _lyricsLang = val;
                  if (_targetLang == _lyricsLang) {
                    _targetLang = _lyricsLang == 'es' ? 'en' : 'es';
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lyricsController,
              minLines: 8,
              maxLines: 14,
              decoration: const InputDecoration(
                labelText: 'Letra principal',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _buildKaraokeSyncCard(theme),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _languageDropdown(
                    value: _targetLang,
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _targetLang = val;
                        _activePreviewKey = val;
                        _translationPreviewController.text =
                            _translations[_activePreviewKey] ?? '';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _translateLyrics,
                  child: const Text('Traducir'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _translationPreviewController,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Vista previa de traduccion',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                final text = val.trim();
                final key = _activePreviewKey.trim().toLowerCase();
                if (key.isEmpty) return;
                if (text.isEmpty) {
                  _translations.remove(key);
                } else {
                  _translations[key] = text;
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _translations.entries
                  .map(
                    (entry) => InputChip(
                      label: Text(_translationLabel(entry.key)),
                      selected: entry.key == _activePreviewKey,
                      onPressed: () {
                        setState(() {
                          final key = entry.key.trim().toLowerCase();
                          _activePreviewKey = key;
                          if (_languageLabels.containsKey(key)) {
                            _targetLang = key;
                          }
                          _translationPreviewController.text = entry.value;
                        });
                      },
                      onDeleted: () => _removeTranslation(entry.key),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _applyPreviewAsPrimaryLyrics,
                    child: const Text('Usar traduccion como principal'),
                  ),
                ),
              ],
            ),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}
