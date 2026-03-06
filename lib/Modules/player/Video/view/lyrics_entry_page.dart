import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_listenfy/app/ui/widgets/dialogs/lyrics_search_dialog.dart';

import 'package:flutter_listenfy/app/services/lyrics_service.dart';

class LyricsEntryArgs {
  final String title;
  final String artist;
  final String? lyrics;
  final String? lyricsLanguage;
  final Map<String, String>? translations;

  const LyricsEntryArgs({
    required this.title,
    required this.artist,
    this.lyrics,
    this.lyricsLanguage,
    this.translations,
  });
}

class LyricsEntryResult {
  final String lyrics;
  final String lyricsLanguage;
  final Map<String, String> translations;

  const LyricsEntryResult({
    required this.lyrics,
    required this.lyricsLanguage,
    required this.translations,
  });
}

class LyricsEntryPage extends StatefulWidget {
  const LyricsEntryPage({super.key});

  @override
  State<LyricsEntryPage> createState() => _LyricsEntryPageState();
}

class _LyricsEntryPageState extends State<LyricsEntryPage> {
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

  bool _loading = false;
  String _lyricsLang = 'es';
  String _targetLang = 'en';
  String _activePreviewKey = 'en';

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
    _hydrateFromArgs(Get.arguments);
  }

  @override
  void dispose() {
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

    Get.back(
      result: LyricsEntryResult(
        lyrics: lyrics,
        lyricsLanguage: _lyricsLang,
        translations: cleanedTranslations,
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
