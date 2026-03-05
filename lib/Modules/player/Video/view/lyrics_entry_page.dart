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
    'pt': 'Portugués',
    'fr': 'Francés',
    'it': 'Italiano',
    'de': 'Alemán',
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
      setState(() => _loading = true);
      final fetched = await LyricsService.fetchLyricsFromUrl(result);
      if (mounted) {
        if (fetched != null && fetched.trim().isNotEmpty) {
          _lyricsController.text = fetched;
        } else {
          Get.snackbar(
            'Letras',
            'No se pudo extraer texto util desde esa pagina.',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        setState(() => _loading = false);
      }
    }
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
    final translated = await LyricsService.translateLyrics(
      _lyricsController.text,
      _targetLang,
      sourceLang: _lyricsLang,
    );
    if (mounted) {
      if (translated != null && translated.trim().isNotEmpty) {
        final clean = translated.trim();
        _translationPreviewController.text = clean;
        _translations[_targetLang] = clean;
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

    final initialTranslations = entryArgs.translations ?? const {};
    for (final entry in initialTranslations.entries) {
      final key = entry.key.trim().toLowerCase();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      _translations[key] = value;
    }
    _translationPreviewController.text = _translations[_targetLang] ?? '';
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
      _translationPreviewController.text = _translations[_targetLang] ?? '';
    });
  }

  void _removeTranslation(String lang) {
    setState(() {
      _translations.remove(lang);
      if (_targetLang == lang) {
        _translationPreviewController.text = '';
      }
    });
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
                        _translationPreviewController.text =
                            _translations[_targetLang] ?? '';
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
                if (text.isEmpty) {
                  _translations.remove(_targetLang);
                } else {
                  _translations[_targetLang] = text;
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
                      label: Text(_languageLabels[entry.key] ?? entry.key),
                      selected: entry.key == _targetLang,
                      onPressed: () {
                        setState(() {
                          _targetLang = entry.key;
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
