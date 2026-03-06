import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/audio_cleanup.dart';
import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../player/Video/view/lyrics_entry_page.dart';
import '../../artists/controller/artists_controller.dart';
import '../../artists/domain/artist_profile.dart';
import '../../playlists/domain/playlist.dart';
import '../../sources/domain/source_theme_topic.dart';
import '../../sources/domain/source_theme_topic_playlist.dart';
import '../../sources/domain/source_origin.dart';
import '../../sources/ui/source_color_picker_field.dart';
import '../controller/edit_entity_controller.dart';
import '../../../app/ui/widgets/dialogs/image_search_dialog.dart';

class EditEntityPage extends StatefulWidget {
  const EditEntityPage({super.key});

  @override
  State<EditEntityPage> createState() => _EditEntityPageState();
}

class _EditEntityPageState extends State<EditEntityPage> {
  final EditEntityController _controller = Get.find<EditEntityController>();
  final ArtistsController _artistsController = Get.find<ArtistsController>();

  late final EditEntityArgs _args;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _subtitleCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _thumbCtrl;

  String? _localThumbPath;
  String? _remoteThumbUrl;
  bool _thumbTouched = false;
  bool _thumbCleared = false;
  int? _colorValue;
  bool _audioCleanupBusy = false;
  MediaItem? _mediaDraft;
  ArtistProfileKind _artistKind = ArtistProfileKind.singer;
  final Set<String> _artistMemberKeys = <String>{};

  MediaItem? get _media => _mediaDraft;
  ArtistGroup? get _artist => _args.artist;
  Playlist? get _playlist => _args.playlist;
  SourceThemeTopic? get _topic => _args.topic;
  SourceThemeTopicPlaylist? get _topicPlaylist => _args.topicPlaylist;

  @override
  void initState() {
    super.initState();

    _args = Get.arguments as EditEntityArgs;

    if (Get.isRegistered<NavigationController>()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<NavigationController>().setEditing(true);
      });
    }

    if (_args.type == EditEntityType.media) {
      final item = _args.media!;
      _mediaDraft = item;
      _titleCtrl = TextEditingController(text: item.title);
      _subtitleCtrl = TextEditingController(text: item.subtitle);
      _durationCtrl = TextEditingController(
        text: item.durationSeconds?.toString() ?? '',
      );
      _thumbCtrl = TextEditingController(text: item.thumbnail ?? '');
      _localThumbPath = item.thumbnailLocalPath;
      _remoteThumbUrl = item.thumbnail;
      _colorValue = null;
    } else if (_args.type == EditEntityType.artist) {
      final artist = _artist!;
      _titleCtrl = TextEditingController(text: artist.name);
      _subtitleCtrl = TextEditingController(text: '');
      _durationCtrl = TextEditingController(text: '');
      _thumbCtrl = TextEditingController(text: artist.thumbnail ?? '');
      _localThumbPath = artist.thumbnailLocalPath;
      _remoteThumbUrl = artist.thumbnail;
      _colorValue = null;
      _artistKind = artist.kind;
      _artistMemberKeys
        ..clear()
        ..addAll(artist.memberKeys);
    } else {
      if (_args.type == EditEntityType.playlist) {
        final playlist = _playlist!;
        _titleCtrl = TextEditingController(text: playlist.name);
        _subtitleCtrl = TextEditingController(text: '');
        _durationCtrl = TextEditingController(text: '');
        _thumbCtrl = TextEditingController(text: playlist.coverUrl ?? '');
        _localThumbPath = playlist.coverLocalPath;
        _remoteThumbUrl = playlist.coverUrl;
        _thumbCleared = playlist.coverCleared;
        _colorValue = null;
      } else if (_args.type == EditEntityType.topic) {
        final topic = _topic!;
        _titleCtrl = TextEditingController(text: topic.title);
        _subtitleCtrl = TextEditingController(text: '');
        _durationCtrl = TextEditingController(text: '');
        _thumbCtrl = TextEditingController(text: topic.coverUrl ?? '');
        _localThumbPath = topic.coverLocalPath;
        _remoteThumbUrl = topic.coverUrl;
        _colorValue = topic.colorValue;
      } else {
        final pl = _topicPlaylist!;
        _titleCtrl = TextEditingController(text: pl.name);
        _subtitleCtrl = TextEditingController(text: '');
        _durationCtrl = TextEditingController(text: '');
        _thumbCtrl = TextEditingController(text: pl.coverUrl ?? '');
        _localThumbPath = pl.coverLocalPath;
        _remoteThumbUrl = pl.coverUrl;
        _colorValue = pl.colorValue;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _durationCtrl.dispose();
    _thumbCtrl.dispose();
    if (Get.isRegistered<NavigationController>()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<NavigationController>().setEditing(false);
      });
    }
    super.dispose();
  }

  String _entityId() {
    if (_args.type == EditEntityType.media) return _media!.id;
    if (_args.type == EditEntityType.artist) return _artist!.key;
    if (_args.type == EditEntityType.playlist) return _playlist!.id;
    if (_args.type == EditEntityType.topic) return _topic!.id;
    return _topicPlaylist!.id;
  }

  String _entityTitle() {
    if (_args.type == EditEntityType.media) return 'Editar metadatos';
    if (_args.type == EditEntityType.artist) return 'Editar artista';
    if (_args.type == EditEntityType.playlist) return 'Editar playlist';
    if (_args.type == EditEntityType.topic) return 'Editar temática';
    return 'Editar lista';
  }

  bool get _isMedia => _args.type == EditEntityType.media;
  bool get _isArtist => _args.type == EditEntityType.artist;
  bool get _isTopic => _args.type == EditEntityType.topic;
  bool get _isTopicPlaylist => _args.type == EditEntityType.topicPlaylist;

  Future<void> _pickLocalThumbnail() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );

    final file = (res != null && res.files.isNotEmpty) ? res.files.first : null;
    final path = file?.path;
    if (path == null || path.trim().isEmpty) return;

    final prevLocal = _localThumbPath;
    final cropped = await _controller.cropToSquare(path);
    if (cropped == null || cropped.trim().isEmpty) return;

    final persisted = await _controller.persistCroppedImage(
      id: _entityId(),
      croppedPath: cropped,
    );
    if (!mounted || persisted == null || persisted.trim().isEmpty) return;

    setState(() {
      _localThumbPath = persisted;
      _remoteThumbUrl = '';
      _thumbCtrl.text = '';
      _thumbTouched = true;
      _thumbCleared = false;
    });
    _evictFileImage(persisted);

    if (prevLocal != null &&
        prevLocal.trim().isNotEmpty &&
        prevLocal.trim() != persisted.trim()) {
      _evictFileImage(prevLocal.trim());
      await _controller.deleteFile(prevLocal);
    }
  }

  Future<void> _searchWebThumbnail() async {
    final rawQuery = _titleCtrl.text.trim();
    final fallback = _args.type == EditEntityType.artist
        ? 'artist photo'
        : 'album cover';
    final query = rawQuery.isEmpty ? fallback : rawQuery;

    final pickedUrl = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ImageSearchDialog(initialQuery: query),
    );

    final cleaned = (pickedUrl ?? '').trim();
    if (!mounted || cleaned.isEmpty) return;

    final prevLocal = _localThumbPath;

    String? baseLocal;
    try {
      baseLocal = await _controller.cacheRemoteToLocal(
        id: '${_entityId()}-raw',
        url: cleaned,
      );
    } catch (_) {
      baseLocal = null;
    }
    if (!mounted || baseLocal == null || baseLocal.trim().isEmpty) return;

    final cropped = await _controller.cropToSquare(baseLocal);
    if (!mounted || cropped == null || cropped.trim().isEmpty) {
      await _controller.deleteFile(baseLocal);
      return;
    }

    final persisted = await _controller.persistCroppedImage(
      id: _entityId(),
      croppedPath: cropped,
    );
    if (!mounted || persisted == null || persisted.trim().isEmpty) return;

    if (baseLocal != persisted) {
      await _controller.deleteFile(baseLocal);
    }

    setState(() {
      _thumbCtrl.text = '';
      _localThumbPath = persisted;
      _remoteThumbUrl = '';
      _thumbTouched = true;
      _thumbCleared = false;
    });
    _evictFileImage(persisted);

    if (prevLocal != null &&
        prevLocal.trim().isNotEmpty &&
        prevLocal.trim() != persisted.trim()) {
      _evictFileImage(prevLocal.trim());
      await _controller.deleteFile(prevLocal);
    }
  }

  void _clearThumbnail() {
    setState(() {
      _localThumbPath = null;
      _remoteThumbUrl = '';
      _thumbCtrl.text = '';
      _thumbTouched = true;
      _thumbCleared = true;
    });
  }

  Future<void> _deleteCurrentThumbnail() async {
    final paths = <String>{if (_localThumbPath != null) _localThumbPath!.trim()}
      ..removeWhere((e) => e.isEmpty);

    for (final pth in paths) {
      _evictFileImage(pth);
      await _controller.deleteFile(pth);
    }

    if (!mounted) return;
    setState(() {
      _localThumbPath = null;
      _remoteThumbUrl = '';
      _thumbCtrl.text = '';
      _thumbTouched = true;
      _thumbCleared = true;
    });
  }

  bool _shouldWarnAboutTitleCollaboration() {
    if (!_isMedia) return false;

    final title = _titleCtrl.text.trim();
    final artistField = _subtitleCtrl.text.trim();

    if (!ArtistCreditParser.titleSuggestsCollaboration(title)) return false;
    return !ArtistCreditParser.artistFieldHasCollaborators(artistField);
  }

  Future<bool> _confirmTitleCollaborationWarning() async {
    if (!_shouldWarnAboutTitleCollaboration()) return true;

    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Posible colaboracion'),
        content: const Text(
          'Se detecto un posible feat/ft en el titulo. Si quieres que esta cancion aparezca como colaboracion entre artistas, mueve los invitados al campo Artista.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Get.back(result: true),
            child: const Text('Guardar igual'),
          ),
        ],
      ),
      barrierDismissible: true,
    );

    return result == true;
  }

  String _formatClockFromMs(int ms) {
    final safeMs = ms.clamp(0, 24 * 60 * 60 * 1000);
    final totalSeconds = (safeMs / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatSecondsFromMs(int ms) {
    final secs = (ms / 1000);
    return '${secs.toStringAsFixed(secs >= 10 ? 0 : 1)} s';
  }

  Future<List<AudioSilenceSegment>?> _showAudioCleanupSheet(
    AudioSilenceAnalysis analysis,
  ) async {
    final segments = analysis.segments;
    if (segments.isEmpty) return null;

    final selected = List<bool>.filled(segments.length, true);

    return showModalBottomSheet<List<AudioSilenceSegment>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final theme = Theme.of(context);

        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedCount = selected.where((v) => v).length;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sonido limpio',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Se detectaron silencios mayores a 4 segundos. Marca los que deseas recortar.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AudioSilenceTimeline(
                      durationMs: analysis.durationMs,
                      segments: segments,
                      selected: selected,
                      startLabel: _formatClockFromMs(0),
                      endLabel: _formatClockFromMs(analysis.durationMs),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Detectados: ${segments.length} - Seleccionados: $selectedCount',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.separated(
                        itemCount: segments.length,
                        separatorBuilder: (context, _) => Divider(
                          height: 1,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        itemBuilder: (context, index) {
                          final segment = segments[index];
                          return CheckboxListTile(
                            value: selected[index],
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) {
                              setModalState(() {
                                selected[index] = v ?? false;
                              });
                            },
                            title: Text(
                              '${_formatClockFromMs(segment.startMs)} - ${_formatClockFromMs(segment.endMs)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Duracion: ${_formatSecondsFromMs(segment.durationMs)} - Nivel medio: ${segment.meanDb.toStringAsFixed(1)} dB',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: selectedCount == 0
                                ? null
                                : () {
                                    final picked = <AudioSilenceSegment>[];
                                    for (int i = 0; i < segments.length; i++) {
                                      if (selected[i]) picked.add(segments[i]);
                                    }
                                    Navigator.of(context).pop(picked);
                                  },
                            child: const Text('Aplicar limpieza'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _runAudioCleanupFlow() async {
    if (!_isMedia || _media == null || _audioCleanupBusy) return;

    setState(() {
      _audioCleanupBusy = true;
    });

    try {
      final analysisBundle = await _controller.analyzeMediaSilences(
        item: _media!,
      );
      if (!mounted) return;

      if (analysisBundle == null) {
        Get.snackbar(
          'Sonido limpio',
          'Solo funciona con audio local disponible.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      if (analysisBundle.analysis.segments.isEmpty) {
        Get.snackbar(
          'Sonido limpio',
          'No se detectaron silencios mayores a 4 segundos.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final picked = await _showAudioCleanupSheet(analysisBundle.analysis);
      if (!mounted || picked == null) return;

      if (picked.isEmpty) {
        Get.snackbar(
          'Sonido limpio',
          'No seleccionaste silencios para recortar.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final updated = await _controller.applyMediaSilenceCleanup(
        item: analysisBundle.media,
        sourcePath: analysisBundle.sourcePath,
        removeSegments: picked,
      );
      if (!mounted) return;

      if (updated == null) {
        Get.snackbar(
          'Sonido limpio',
          'No se pudo generar el audio limpio.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      setState(() {
        _mediaDraft = updated;
        _durationCtrl.text = updated.durationSeconds?.toString() ?? '';
      });

      Get.snackbar(
        'Sonido limpio',
        'Se guardo una variante limpia del audio.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      Get.snackbar(
        'Sonido limpio',
        message.isEmpty ? 'Ocurrio un error al limpiar el audio.' : message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() {
          _audioCleanupBusy = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final canContinue = await _confirmTitleCollaborationWarning();
    if (!canContinue) return;

    final ok = _args.type == EditEntityType.media
        ? await _controller.saveMedia(
            item: _media!,
            title: _titleCtrl.text,
            subtitle: _subtitleCtrl.text,
            thumbTouched: _thumbTouched,
            localThumbPath: _localThumbPath,
            lyrics: _media?.lyrics ?? '',
            lyricsLanguage: _media?.lyricsLanguage ?? 'es',
            translations: _media?.translations ?? const <String, String>{},
            timedLyrics:
                _media?.timedLyrics ?? const <String, List<TimedLyricCue>>{},
          )
        : (_args.type == EditEntityType.artist
              ? await _controller.saveArtist(
                  artist: _artist!,
                  name: _titleCtrl.text,
                  kind: _artistKind,
                  memberKeys: _artistMemberKeys.toList(growable: false),
                  thumbTouched: _thumbTouched,
                  localThumbPath: _localThumbPath,
                )
              : (_args.type == EditEntityType.playlist
                    ? await _controller.savePlaylist(
                        playlist: _playlist!,
                        name: _titleCtrl.text,
                        thumbTouched: _thumbTouched,
                        localThumbPath: _localThumbPath,
                      )
                    : (_args.type == EditEntityType.topic
                          ? await _controller.saveTopic(
                              topic: _topic!,
                              name: _titleCtrl.text,
                              thumbTouched: _thumbTouched,
                              localThumbPath: _localThumbPath,
                              colorValue: _colorValue,
                            )
                          : await _controller.saveTopicPlaylist(
                              playlist: _topicPlaylist!,
                              name: _titleCtrl.text,
                              thumbTouched: _thumbTouched,
                              localThumbPath: _localThumbPath,
                              colorValue: _colorValue,
                            ))));

    if (ok && mounted) {
      Get.back(result: true);
    }
  }

  String _lyricsSummaryLabel() {
    final lyrics = _media?.lyrics?.trim() ?? '';
    final hasLyrics = lyrics.isNotEmpty;
    final translationsCount = _media?.translations?.length ?? 0;
    final lang = (_media?.lyricsLanguage ?? '').trim().toUpperCase();

    if (!hasLyrics && translationsCount == 0) {
      return 'Sin letras guardadas';
    }

    final base = hasLyrics
        ? 'Letra principal ${lang.isEmpty ? '' : '($lang)'}'
        : 'Sin letra principal';

    if (translationsCount <= 0) return base.trim();
    return '$base - $translationsCount traducciones';
  }

  Future<void> _openLyricsEditor() async {
    if (!_isMedia || _media == null) return;
    final item = _media!;

    final result = await Get.toNamed(
      AppRoutes.lyricsEntry,
      arguments: LyricsEntryArgs(
        title: _titleCtrl.text.trim().isNotEmpty
            ? _titleCtrl.text.trim()
            : item.title,
        artist: _subtitleCtrl.text.trim().isNotEmpty
            ? _subtitleCtrl.text.trim()
            : item.subtitle,
        lyrics: item.lyrics,
        lyricsLanguage: item.lyricsLanguage,
        translations: item.translations,
        timedLyrics: item.timedLyrics,
      ),
    );

    if (!mounted || result == null) return;
    if (result is! LyricsEntryResult) return;

    setState(() {
      _mediaDraft = item.copyWith(
        lyrics: result.lyrics.trim(),
        lyricsLanguage: result.lyricsLanguage.trim().toLowerCase(),
        translations: Map<String, String>.from(result.translations),
        timedLyrics: Map<String, List<TimedLyricCue>>.from(result.timedLyrics),
      );
    });
  }

  Widget _buildThumbnail(BuildContext context) {
    final theme = Theme.of(context);
    final local = _localThumbPath?.trim();
    final remote = _remoteThumbUrl?.trim() ?? '';
    final thumb = (local != null && local.isNotEmpty)
        ? local
        : (remote.isNotEmpty && !_thumbCleared ? remote : null);

    if (thumb != null && thumb.startsWith('http')) {
      return Image.network(
        thumb,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackThumb(theme),
      );
    }

    if (thumb != null && thumb.isNotEmpty) {
      return Image.file(
        File(thumb),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackThumb(theme),
      );
    }

    return _fallbackThumb(theme);
  }

  Widget _fallbackThumb(ThemeData theme) {
    final isVideo = _media?.hasVideoLocal ?? false;
    return Center(
      child: Icon(
        isVideo ? Icons.videocam_rounded : Icons.music_note_rounded,
        size: 44,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _evictFileImage(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      FileImage(file).evict();
    } catch (_) {}
  }

  MediaVariant? _preferredVariant(MediaItem item) {
    return item.localAudioVariant ??
        item.localVideoVariant ??
        (item.variants.isNotEmpty ? item.variants.first : null);
  }

  String _kindLabel(MediaVariant? variant) {
    if (variant == null) return 'Desconocido';
    return variant.kind == MediaVariantKind.video ? 'Video' : 'Audio';
  }

  String _formatLabel(MediaVariant? variant) {
    final fmt = variant?.format.trim() ?? '';
    return fmt.isEmpty ? 'N/A' : fmt.toUpperCase();
  }

  String _sizeMbLabel(MediaVariant? variant) {
    final bytes = variant?.size;
    if (bytes == null || bytes <= 0) return 'N/A';
    final mb = bytes / (1024 * 1024);
    final decimals = mb >= 100 ? 0 : (mb >= 10 ? 1 : 2);
    return '${mb.toStringAsFixed(decimals)} MB';
  }

  String _originLabel(MediaItem item) {
    final key = item.origin.key.trim();
    if (key.isEmpty) return 'Desconocido';
    if (key.toLowerCase() == 'local') return 'Device';
    return key;
  }

  String _mediaDetailsLine1(MediaItem item) {
    final variant = _preferredVariant(item);
    final size = _sizeMbLabel(variant);
    final fmt = _formatLabel(variant);
    return '$size - $fmt';
  }

  Widget _artistSongsSection(ThemeData theme) {
    final songs = _artist?.items ?? const <MediaItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Canciones del artista',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: songs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No hay canciones vinculadas a este artista.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < songs.length; i++) ...[
                      _artistSongTile(theme, songs[i]),
                      if (i != songs.length - 1)
                        Divider(
                          height: 1,
                          color: theme.colorScheme.outlineVariant,
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  List<ArtistGroup> _artistMemberCandidates() {
    final currentKey = _artist?.key ?? '';
    final typedKey = ArtistCreditParser.normalizeKey(_titleCtrl.text);
    final selfKeys = <String>{
      ArtistCreditParser.normalizeKey(currentKey),
      typedKey,
    };

    final list = _artistsController.artists
        .where((artist) => !selfKeys.contains(artist.key))
        .toList(growable: false);
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Widget _artistClassificationSection(ThemeData theme) {
    if (!_isArtist) return const SizedBox.shrink();
    final candidates = _artistMemberCandidates();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Tipo de artista',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<ArtistProfileKind>(
                  initialValue: _artistKind,
                  decoration: const InputDecoration(
                    labelText: 'Clasificacion',
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ArtistProfileKind.singer,
                      child: Text('Cantante'),
                    ),
                    DropdownMenuItem(
                      value: ArtistProfileKind.band,
                      child: Text('Banda'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _artistKind = value;
                      if (_artistKind != ArtistProfileKind.band) {
                        _artistMemberKeys.clear();
                      }
                    });
                  },
                ),
                if (_artistKind == ArtistProfileKind.band) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Integrantes',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Selecciona los cantantes/artistas que pertenecen a esta banda.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (candidates.isEmpty)
                    Text(
                      'No hay artistas disponibles para agregar.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: candidates
                          .map(
                            (entry) => FilterChip(
                              label: Text(entry.name),
                              selected: _artistMemberKeys.contains(entry.key),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _artistMemberKeys.add(entry.key);
                                  } else {
                                    _artistMemberKeys.remove(entry.key);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _artistSongTile(ThemeData theme, MediaItem item) {
    final variant = _preferredVariant(item);
    final kind = _kindLabel(variant);
    final fmt = _formatLabel(variant);
    final size = _sizeMbLabel(variant);

    return ListTile(
      dense: true,
      leading: Icon(
        variant?.kind == MediaVariantKind.video
            ? Icons.videocam_rounded
            : Icons.music_note_rounded,
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$kind · $fmt · $size',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_entityTitle()),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton(
            onPressed: _audioCleanupBusy ? null : _save,
            child: const Text('Guardar cambios'),
          ),
        ),
      ),
      body: AppGradientBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: _buildThumbnail(context),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleCtrl.text.isEmpty
                                ? (_args.type == EditEntityType.playlist
                                      ? 'Sin titulo'
                                      : 'Sin nombre')
                                : _titleCtrl.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_isMedia) ...[
                            const SizedBox(height: 6),
                            Text(
                              _subtitleCtrl.text.isEmpty
                                  ? _media!.displaySubtitle
                                  : _subtitleCtrl.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _mediaDetailsLine1(_media!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _originLabel(_media!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Informacion basica',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      decoration: InputDecoration(
                        labelText: _args.type == EditEntityType.media
                            ? 'Titulo'
                            : 'Nombre',
                        prefixIcon: Icon(
                          _args.type == EditEntityType.media
                              ? Icons.music_note_rounded
                              : (_args.type == EditEntityType.artist
                                    ? Icons.person_rounded
                                    : Icons.folder_rounded),
                        ),
                      ),
                    ),
                    if (_isMedia) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _subtitleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Artista',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _artistClassificationSection(theme),
            const SizedBox(height: 12),
            Text(
              (_isTopic || _isTopicPlaylist) ? 'Portada y color' : 'Portada',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _pickLocalThumbnail,
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Elegir imagen'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _searchWebThumbnail,
                            icon: const Icon(Icons.public_rounded),
                            label: const Text('Buscar en web'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _thumbCtrl,
                            readOnly: true,
                            onTap: _searchWebThumbnail,
                            decoration: const InputDecoration(
                              labelText: 'Imagen web seleccionada',
                              prefixIcon: Icon(Icons.image_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _clearThumbnail,
                          child: const Text('Limpiar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _deleteCurrentThumbnail,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Borrar portada actual'),
                      ),
                    ),
                    if (_isTopic || _isTopicPlaylist) ...[
                      const SizedBox(height: 12),
                      SourceColorPickerField(
                        color: _colorValue != null
                            ? Color(_colorValue!)
                            : theme.colorScheme.primary,
                        onChanged: (c) => setState(() {
                          _colorValue = c.toARGB32();
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isMedia) ...[
              const SizedBox(height: 12),
              Text(
                'Extras',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _durationCtrl,
                        readOnly: true,
                        enableInteractiveSelection: false,
                        decoration: const InputDecoration(
                          labelText: 'Duracion detectada automaticamente (s)',
                          prefixIcon: Icon(Icons.timer_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _audioCleanupBusy
                              ? null
                              : _runAudioCleanupFlow,
                          icon: _audioCleanupBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_fix_high_rounded),
                          label: Text(
                            _audioCleanupBusy
                                ? 'Procesando...'
                                : 'Sonido limpio',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Detecta silencios mayores a 4 segundos y te permite elegir cuales recortar.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Divider(color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _openLyricsEditor,
                          icon: const Icon(Icons.lyrics_rounded),
                          label: const Text('Editar letras'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _lyricsSummaryLabel(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_isArtist) ...[
              const SizedBox(height: 12),
              _artistSongsSection(theme),
            ],
          ],
        ),
      ),
    );
  }
}

class _AudioSilenceTimeline extends StatelessWidget {
  const _AudioSilenceTimeline({
    required this.durationMs,
    required this.segments,
    required this.selected,
    required this.startLabel,
    required this.endLabel,
  });

  final int durationMs;
  final List<AudioSilenceSegment> segments;
  final List<bool> selected;
  final String startLabel;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = durationMs > 0 ? durationMs : 1;

    return Column(
      children: [
        Container(
          height: 34,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                children: [
                  for (int i = 0; i < segments.length; i++)
                    Positioned(
                      left: width * (segments[i].startMs / totalMs),
                      width:
                          (width *
                                  ((segments[i].endMs - segments[i].startMs) /
                                      totalMs))
                              .clamp(2.0, width),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected[i]
                              ? theme.colorScheme.error.withValues(alpha: 0.72)
                              : theme.colorScheme.error.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              startLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              endLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
