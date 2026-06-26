import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/audio_cleanup.dart';
import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../../../app/utils/country_catalog.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/controllers/navigation_controller.dart';
import '../../player/Video/view/lyrics_entry_page.dart';
import '../../artists/controller/artists_controller.dart';
import '../../artists/domain/artist_profile.dart';
import '../../captures/controller/capture_gallery_controller.dart';
import '../../captures/domain/capture_item.dart';
import '../../captures/domain/capture_tag_folder.dart';
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
  late final TextEditingController _countryCtrl;
  late final TextEditingController _memberSearchCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _thumbCtrl;
  late final TextEditingController _captureTagsCtrl;

  String? _localThumbPath;
  String? _remoteThumbUrl;
  bool _thumbTouched = false;
  bool _thumbCleared = false;
  int? _colorValue;
  bool _audioCleanupBusy = false;
  bool _dataTransferBusy = false;
  MediaItem? _mediaDraft;
  ArtistProfileKind _artistKind = ArtistProfileKind.singer;
  ArtistMainRegion _artistMainRegion = ArtistMainRegion.none;
  String? _artistCountryCode;
  final Set<String> _artistMemberKeys = <String>{};

  MediaItem? get _media => _mediaDraft;
  bool get _isAudioMedia => _media?.hasAudioLocal ?? false;
  ArtistGroup? get _artist => _args.artist;
  Playlist? get _playlist => _args.playlist;
  SourceThemeTopic? get _topic => _args.topic;
  SourceThemeTopicPlaylist? get _topicPlaylist => _args.topicPlaylist;
  CaptureItem? get _capture => _args.capture;
  CaptureTagFolder? get _captureTag => _args.captureTag;

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
      _countryCtrl = TextEditingController(text: '');
      _durationCtrl = TextEditingController(
        text: item.durationSeconds?.toString() ?? '',
      );
      _thumbCtrl = TextEditingController(text: item.thumbnail ?? '');
      _localThumbPath = item.thumbnailLocalPath;
      _remoteThumbUrl = item.thumbnail;
      _colorValue = null;
      _artistCountryCode = null;
    } else if (_args.type == EditEntityType.artist) {
      final artist = _artist!;
      _titleCtrl = TextEditingController(text: artist.name);
      _subtitleCtrl = TextEditingController(text: '');
      _countryCtrl = TextEditingController(text: artist.country ?? '');
      _durationCtrl = TextEditingController(text: '');
      _thumbCtrl = TextEditingController(text: artist.thumbnail ?? '');
      _localThumbPath = artist.thumbnailLocalPath;
      _remoteThumbUrl = artist.thumbnail;
      _colorValue = null;
      _artistKind = artist.kind;
      _artistMainRegion = artist.mainRegion;
      _artistCountryCode = artist.countryCode;
      if (_countryCtrl.text.trim().isEmpty &&
          (_artistCountryCode ?? '').isNotEmpty) {
        _countryCtrl.text =
            CountryCatalog.countryNameFromCode(_artistCountryCode) ?? '';
      }
      if ((_artistCountryCode ?? '').isEmpty) {
        _artistCountryCode = CountryCatalog.findByName(artist.country)?.code;
      }
      if (_artistMainRegion == ArtistMainRegion.none) {
        final inferred = CountryCatalog.regionKeyFromCode(_artistCountryCode);
        if (inferred != null) {
          _artistMainRegion = ArtistMainRegionX.fromRaw(inferred);
        }
      }
      _artistMemberKeys
        ..clear()
        ..addAll(artist.memberKeys);
    } else {
      if (_args.type == EditEntityType.playlist) {
        final playlist = _playlist!;
        _titleCtrl = TextEditingController(text: playlist.name);
        _subtitleCtrl = TextEditingController(text: '');
        _countryCtrl = TextEditingController(text: '');
        _durationCtrl = TextEditingController(text: '');
        _thumbCtrl = TextEditingController(text: playlist.coverUrl ?? '');
        _localThumbPath = playlist.coverLocalPath;
        _remoteThumbUrl = playlist.coverUrl;
        _thumbCleared = playlist.coverCleared;
        _colorValue = null;
        _artistCountryCode = null;
      } else if (_args.type == EditEntityType.topic) {
        final topic = _topic!;
        _titleCtrl = TextEditingController(text: topic.title);
        _subtitleCtrl = TextEditingController(text: '');
        _countryCtrl = TextEditingController(text: '');
        _durationCtrl = TextEditingController(text: '');
        _thumbCtrl = TextEditingController(text: topic.coverUrl ?? '');
        _localThumbPath = topic.coverLocalPath;
        _remoteThumbUrl = topic.coverUrl;
        _colorValue = topic.colorValue;
        _artistCountryCode = null;
      } else if (_args.type == EditEntityType.capture) {
        final capture = _capture!;
        _titleCtrl = TextEditingController(text: capture.name);
        _subtitleCtrl = TextEditingController(text: capture.sourceTitle ?? '');
        _countryCtrl = TextEditingController(text: '');
        _durationCtrl = TextEditingController(text: '');
        _thumbCtrl = TextEditingController(text: '');
        _localThumbPath = capture.path;
        _remoteThumbUrl = '';
        _colorValue = null;
        _artistCountryCode = null;
      } else if (_args.type == EditEntityType.captureTag) {
        final folder = _captureTag!;
        _titleCtrl = TextEditingController(text: folder.tag);
        _subtitleCtrl = TextEditingController(text: '');
        _countryCtrl = TextEditingController(text: '');
        _durationCtrl = TextEditingController(text: '');
        _thumbCtrl = TextEditingController(text: '');
        _localThumbPath =
            folder.thumbnailPath ??
            (folder.captures.isEmpty ? null : folder.captures.first.path);
        _remoteThumbUrl = '';
        _colorValue = folder.colorValue;
        _artistCountryCode = null;
      } else {
        final pl = _topicPlaylist!;
        _titleCtrl = TextEditingController(text: pl.name);
        _subtitleCtrl = TextEditingController(text: '');
        _countryCtrl = TextEditingController(text: '');
        _durationCtrl = TextEditingController(text: '');
        _thumbCtrl = TextEditingController(text: pl.coverUrl ?? '');
        _localThumbPath = pl.coverLocalPath;
        _remoteThumbUrl = pl.coverUrl;
        _colorValue = pl.colorValue;
        _artistCountryCode = null;
      }
    }

    _memberSearchCtrl = TextEditingController();
    _captureTagsCtrl = TextEditingController(
      text: _capture?.tags.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _countryCtrl.dispose();
    _memberSearchCtrl.dispose();
    _durationCtrl.dispose();
    _thumbCtrl.dispose();
    _captureTagsCtrl.dispose();
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
    if (_args.type == EditEntityType.capture) return _capture!.path;
    if (_args.type == EditEntityType.captureTag) return _captureTag!.key;
    return _topicPlaylist!.id;
  }

  String _entityTitle() {
    if (_args.type == EditEntityType.media) return tr('edit.title.metadata');
    if (_args.type == EditEntityType.artist) return tr('edit.title.artist');
    if (_args.type == EditEntityType.playlist) return tr('edit.title.playlist');
    if (_args.type == EditEntityType.topic) return tr('edit.title.collection');
    if (_args.type == EditEntityType.capture) return tr('edit.title.capture');
    if (_args.type == EditEntityType.captureTag) return tr('edit.title.tag');
    return tr('edit.title.collection');
  }

  bool get _isMedia => _args.type == EditEntityType.media;
  bool get _isArtist => _args.type == EditEntityType.artist;
  bool get _isTopic => _args.type == EditEntityType.topic;
  bool get _isTopicPlaylist => _args.type == EditEntityType.topicPlaylist;
  bool get _isCapture => _args.type == EditEntityType.capture;
  bool get _isCaptureTag => _args.type == EditEntityType.captureTag;
  bool get _isVideoMedia => _media?.hasVideoLocal ?? false;
  bool get _usesWideCover =>
      _isVideoMedia ||
      _isTopic ||
      _isTopicPlaylist ||
      _isCapture ||
      _isCaptureTag;

  Future<void> _pickLocalThumbnail() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );

    final file = (res != null && res.files.isNotEmpty) ? res.files.first : null;
    final path = file?.path;
    if (path == null || path.trim().isEmpty) return;

    final prevLocal = _localThumbPath;
    final cropped = _usesWideCover
        ? await _controller.cropToVideoThumbnail(path)
        : await _controller.cropToSquare(path);
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

    final cropped = _usesWideCover
        ? await _controller.cropToVideoThumbnail(baseLocal)
        : await _controller.cropToSquare(baseLocal);
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

  String _countryLabelWithFlag() {
    final country = _countryCtrl.text.trim();
    if (country.isEmpty) return '';
    final flag = CountryCatalog.flagFromIso(_artistCountryCode);
    if (flag.isEmpty) return country;
    return '$flag $country';
  }

  String _artistRegionLabel() {
    if (_artistMainRegion == ArtistMainRegion.none) {
      return 'Se define al elegir pais';
    }
    return _artistMainRegion.simpleLabel;
  }

  Future<void> _pickArtistCountry() async {
    if (!_isArtist) return;

    final selected = await showModalBottomSheet<CountryOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CountryPickerSheet(selectedCode: _artistCountryCode),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _artistCountryCode = selected.code;
      _countryCtrl.text = selected.name;
      final nextRegion = ArtistMainRegionX.fromRaw(selected.regionKey);
      if (nextRegion != ArtistMainRegion.none) {
        _artistMainRegion = nextRegion;
      }
    });
  }

  void _clearArtistCountry() {
    setState(() {
      _countryCtrl.clear();
      _artistCountryCode = null;
      _artistMainRegion = ArtistMainRegion.none;
    });
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

  String _formatCaptureBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final decimals = unit == 0 || value >= 100 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
  }

  String _formatCaptureDate(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
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
        final scheme = theme.colorScheme;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedCount = selected.where((v) => v).length;
            final selectedDurationMs = <int>[
              for (int i = 0; i < segments.length; i++)
                if (selected[i]) segments[i].durationMs,
            ].fold<int>(0, (sum, value) => sum + value);

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
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.auto_fix_high_rounded,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sonido limpio',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Elige que silencios recortar.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(
                            Icons.graphic_eq_rounded,
                            size: 18,
                          ),
                          label: Text('${segments.length} detectados'),
                        ),
                        Chip(
                          avatar: const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                          ),
                          label: Text('$selectedCount seleccionados'),
                        ),
                        Chip(
                          avatar: const Icon(Icons.cut_rounded, size: 18),
                          label: Text(
                            '${_formatSecondsFromMs(selectedDurationMs)} a recortar',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              for (var i = 0; i < selected.length; i++) {
                                selected[i] = true;
                              }
                            });
                          },
                          icon: const Icon(Icons.select_all_rounded),
                          label: const Text('Todo'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              for (var i = 0; i < selected.length; i++) {
                                selected[i] = false;
                              }
                            });
                          },
                          icon: const Icon(Icons.deselect_rounded),
                          label: const Text('Nada'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.separated(
                        itemCount: segments.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final segment = segments[index];
                          final checked = selected[index];
                          return Material(
                            color: checked
                                ? scheme.primaryContainer.withValues(
                                    alpha: 0.45,
                                  )
                                : scheme.surfaceContainerHighest.withValues(
                                    alpha: 0.42,
                                  ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: checked
                                    ? scheme.primary.withValues(alpha: 0.65)
                                    : scheme.outlineVariant,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CheckboxListTile(
                              value: checked,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (v) {
                                setModalState(() {
                                  selected[index] = v ?? false;
                                });
                              },
                              title: Text(
                                '${_formatClockFromMs(segment.startMs)} - ${_formatClockFromMs(segment.endMs)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'Duracion: ${_formatSecondsFromMs(segment.durationMs)} - Nivel medio: ${segment.meanDb.toStringAsFixed(1)} dB',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
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
                          child: FilledButton.icon(
                            onPressed: selectedCount == 0
                                ? null
                                : () {
                                    final picked = <AudioSilenceSegment>[];
                                    for (int i = 0; i < segments.length; i++) {
                                      if (selected[i]) picked.add(segments[i]);
                                    }
                                    Navigator.of(context).pop(picked);
                                  },
                            icon: const Icon(Icons.content_cut_rounded),
                            label: const Text('Crear version limpia'),
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

  Future<void> _runDataTransferFlow() async {
    if (!_isMedia || _media == null || _dataTransferBusy) return;
    setState(() => _dataTransferBusy = true);
    try {
      final candidates = await _controller.transferCandidateMedia(_media!);
      if (!mounted) return;
      if (candidates.isEmpty) {
        Get.snackbar(
          'Transferencia de datos',
          'No hay otra cancion disponible para recibir los datos.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final target = await _showTransferTargetSheet(candidates);
      if (!mounted || target == null) return;

      final confirmed = await _confirmDataTransfer(target);
      if (!mounted || confirmed != true) return;

      final source = _media!;
      final result = await _controller.transferMediaData(
        source: source,
        target: target,
      );
      if (!mounted || result == null) return;

      Get.snackbar(
        'Transferencia completada',
        'Datos movidos a "${result.updatedTarget.title}". Playlists actualizadas: ${result.playlistsUpdated}.',
        snackPosition: SnackPosition.BOTTOM,
      );

      final deleteSource = await _confirmDeleteTransferredSource(source);
      if (!mounted) return;
      if (deleteSource == true) {
        await _controller.deleteMediaFromLibrary(source);
        if (mounted) {
          Get.back(result: true);
          Get.snackbar(
            'Biblioteca',
            'Version anterior eliminada de la biblioteca.',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      } else if (mounted) {
        Get.back(result: true);
      }
    } finally {
      if (mounted) setState(() => _dataTransferBusy = false);
    }
  }

  Future<MediaItem?> _showTransferTargetSheet(List<MediaItem> candidates) {
    return showModalBottomSheet<MediaItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TransferTargetSheet(candidates: candidates),
    );
  }

  Future<bool?> _confirmDataTransfer(MediaItem target) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Transferir datos'),
          content: Text(
            'Se copiara titulo, artista, portada, letras, favoritos, estadisticas y playlists a "${target.title}". El archivo de destino se mantiene.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Transferir'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmDeleteTransferredSource(MediaItem source) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(tr('edit.delete_previous_title')),
          content: Text(tr('edit.delete_previous_body', args: [source.title])),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr('edit.delete_previous_confirm')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    final canContinue = await _confirmTitleCollaborationWarning();
    if (!canContinue) return;

    final ok = await switch (_args.type) {
      EditEntityType.media => _controller.saveMedia(
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
      ),
      EditEntityType.artist => _controller.saveArtist(
        artist: _artist!,
        name: _titleCtrl.text,
        country: _countryCtrl.text,
        countryCode: _artistCountryCode,
        mainRegion: _artistMainRegion,
        kind: _artistKind,
        memberKeys: _artistMemberKeys.toList(growable: false),
        thumbTouched: _thumbTouched,
        localThumbPath: _localThumbPath,
      ),
      EditEntityType.playlist => _controller.savePlaylist(
        playlist: _playlist!,
        name: _titleCtrl.text,
        thumbTouched: _thumbTouched,
        localThumbPath: _localThumbPath,
      ),
      EditEntityType.topic => _controller.saveTopic(
        topic: _topic!,
        name: _titleCtrl.text,
        thumbTouched: _thumbTouched,
        localThumbPath: _localThumbPath,
        colorValue: _colorValue,
      ),
      EditEntityType.topicPlaylist => _controller.saveTopicPlaylist(
        playlist: _topicPlaylist!,
        name: _titleCtrl.text,
        thumbTouched: _thumbTouched,
        localThumbPath: _localThumbPath,
        colorValue: _colorValue,
      ),
      EditEntityType.capture => _controller.saveCapture(
        capture: _capture!,
        name: _titleCtrl.text,
        tags: _captureTagsCtrl.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      ),
      EditEntityType.captureTag => _controller.saveCaptureTag(
        folder: _captureTag!,
        name: _titleCtrl.text,
        colorValue: _colorValue,
        thumbnailPath: _localThumbPath,
      ),
    };

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
    final isCollection = _isTopic || _isTopicPlaylist;
    return Center(
      child: Icon(
        _isCapture
            ? Icons.image_rounded
            : _isCaptureTag
            ? Icons.folder_special_rounded
            : isCollection
            ? Icons.folder_rounded
            : (isVideo ? Icons.videocam_rounded : Icons.music_note_rounded),
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
    final query = _memberSearchCtrl.text.trim().toLowerCase();
    final filteredCandidates = query.isEmpty
        ? const <ArtistGroup>[]
        : candidates
              .where((artist) => artist.name.toLowerCase().contains(query))
              .toList(growable: false);
    final selectedMembers = candidates
        .where((artist) => _artistMemberKeys.contains(artist.key))
        .toList(growable: false);

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
                  items: [
                    DropdownMenuItem(
                      value: ArtistProfileKind.singer,
                      child: Text(ArtistProfileKind.singer.label),
                    ),
                    DropdownMenuItem(
                      value: ArtistProfileKind.band,
                      child: Text(ArtistProfileKind.band.label),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _artistKind = value;
                      if (_artistKind != ArtistProfileKind.band) {
                        _artistMemberKeys.clear();
                        _memberSearchCtrl.clear();
                      }
                    });
                  },
                ),
                if (_artistKind == ArtistProfileKind.band) ...[
                  const SizedBox(height: 12),
                  Text(
                    tr('edit.members'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('edit.members_hint'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _memberSearchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: tr('edit.search_member'),
                      hintText: tr('edit.type_name'),
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  if (selectedMembers.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      tr('edit.selected'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedMembers
                          .map(
                            (entry) => _selectedArtistMemberPill(theme, entry),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (candidates.isEmpty)
                    Text(
                      'No hay artistas disponibles para agregar.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else if (query.isEmpty)
                    Text(
                      'Escribe en el buscador para ver resultados.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else if (filteredCandidates.isEmpty)
                    Text(
                      'No se encontraron artistas con ese nombre.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredCandidates.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final entry = filteredCandidates[index];
                          final isSelected = _artistMemberKeys.contains(
                            entry.key,
                          );
                          return _artistMemberCandidateTile(
                            theme,
                            entry,
                            isSelected,
                          );
                        },
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _selectedArtistMemberPill(ThemeData theme, ArtistGroup entry) {
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          setState(() => _artistMemberKeys.remove(entry.key));
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 8, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _artistAvatar(theme, entry, size: 28),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.close_rounded,
                size: 18,
                color: scheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _artistMemberCandidateTile(
    ThemeData theme,
    ArtistGroup entry,
    bool isSelected,
  ) {
    final scheme = theme.colorScheme;
    return Material(
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.48)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.54),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          setState(() {
            if (isSelected) {
              _artistMemberKeys.remove(entry.key);
            } else {
              _artistMemberKeys.add(entry.key);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              _artistAvatar(theme, entry, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.kind.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _artistAvatar(
    ThemeData theme,
    ArtistGroup entry, {
    required double size,
  }) {
    final scheme = theme.colorScheme;
    final image = _artistImageProvider(entry);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.34),
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        child: image != null
            ? Image(image: image, fit: BoxFit.cover)
            : Icon(
                Icons.person_rounded,
                size: size * 0.58,
                color: scheme.primary,
              ),
      ),
    );
  }

  ImageProvider? _artistImageProvider(ArtistGroup entry) {
    final local = entry.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) {
      return FileImage(File(local));
    }
    final remote = entry.thumbnail?.trim();
    if (remote != null && remote.isNotEmpty) {
      return remote.startsWith('http')
          ? NetworkImage(remote)
          : FileImage(File(remote)) as ImageProvider;
    }
    return null;
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

  Widget _captureTagThumbnailPicker(ThemeData theme) {
    final scheme = theme.colorScheme;
    final captures = _captureTag?.captures ?? const <CaptureItem>[];
    if (captures.isEmpty) {
      return Text(
        'No hay capturas disponibles para usar como thumbnail.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: captures.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final capture = captures[index];
          final selected = _localThumbPath == capture.path;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _localThumbPath = capture.path;
                _thumbTouched = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(capture.path),
                  width: 104,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: const SizedBox(
                      width: 104,
                      height: 70,
                      child: Icon(Icons.image_not_supported_rounded),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<String> _captureSelectedTags() {
    return _captureTagsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  List<CaptureTagFolder> _captureAvailableTags() {
    if (!Get.isRegistered<CaptureGalleryController>()) {
      return const <CaptureTagFolder>[];
    }
    final folders = Get.find<CaptureGalleryController>().tagFolders.toList();
    folders.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.tag.toLowerCase().compareTo(b.tag.toLowerCase());
    });
    return folders;
  }

  void _setCaptureTags(Iterable<String> tags) {
    final normalized = <String>[];
    final seen = <String>{};
    for (final raw in tags) {
      final tag = raw.trim();
      if (tag.isEmpty) continue;
      if (!seen.add(tag.toLowerCase())) continue;
      normalized.add(tag);
    }
    setState(() {
      _captureTagsCtrl.text = normalized.join(', ');
    });
  }

  void _toggleCaptureTag(String tag) {
    final selected = _captureSelectedTags();
    final key = tag.trim().toLowerCase();
    if (selected.any((entry) => entry.toLowerCase() == key)) {
      _setCaptureTags(selected.where((entry) => entry.toLowerCase() != key));
      return;
    }
    _setCaptureTags([...selected, tag.trim()]);
  }

  Widget _captureTagsSection(ThemeData theme) {
    final scheme = theme.colorScheme;
    final selected = _captureSelectedTags();
    final available = _captureAvailableTags();
    final selectedKeys = selected.map((tag) => tag.toLowerCase()).toSet();
    final highlighted = available
        .where((folder) => !selectedKeys.contains(folder.tag.toLowerCase()))
        .take(5)
        .toList(growable: false);

    return Card(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sell_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Etiquetas',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Buscar etiquetas',
                  onPressed: _showCaptureTagSearch,
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (selected.isEmpty)
              Text(
                'Sin etiquetas asignadas.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              for (final tag in selected)
                _CaptureEditTagRow(
                  label: tag,
                  color: Color(_captureTagColor(tag)),
                  selected: true,
                  onTap: () => _toggleCaptureTag(tag),
                ),
            if (highlighted.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 6),
              for (final folder in highlighted)
                _CaptureEditTagRow(
                  label: folder.tag,
                  color: Color(folder.colorValue),
                  subtitle: '${folder.count} capturas',
                  selected: false,
                  onTap: () => _toggleCaptureTag(folder.tag),
                ),
            ],
          ],
        ),
      ),
    );
  }

  int _captureTagColor(String tag) {
    if (Get.isRegistered<CaptureGalleryController>()) {
      return Get.find<CaptureGalleryController>().colorForTag(tag);
    }
    return CaptureGalleryController.defaultTagColor;
  }

  Future<void> _showCaptureTagSearch() async {
    final selected = _captureSelectedTags();
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _CaptureTagSearchSheet(
          folders: _captureAvailableTags(),
          selected: selected,
        );
      },
    );
    if (picked != null) {
      _setCaptureTags(picked);
    }
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
                        width: _usesWideCover ? 126 : 88,
                        height: _usesWideCover ? 71 : 88,
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
                          if (_isCapture) ...[
                            const SizedBox(height: 6),
                            Text(
                              _formatCaptureBytes(_capture!.size),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _capture!.sourceTitle?.isNotEmpty == true
                                  ? 'Fuente: ${_capture!.sourceTitle}'
                                  : 'Fuente no registrada',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (_isCaptureTag) ...[
                            const SizedBox(height: 6),
                            Text(
                              '${_captureTag!.count} capturas',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Etiqueta de capturas',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (_isArtist &&
                              _countryCtrl.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Pais: ${_countryLabelWithFlag()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (_isArtist &&
                              _artistMainRegion != ArtistMainRegion.none) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Region: ${_artistMainRegion.simpleLabel}',
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
                            ? tr('common.title')
                            : tr('sources.name'),
                        prefixIcon: Icon(
                          _args.type == EditEntityType.media
                              ? Icons.music_note_rounded
                              : (_args.type == EditEntityType.capture
                                    ? Icons.image_rounded
                                    : _args.type == EditEntityType.captureTag
                                    ? Icons.folder_special_rounded
                                    : (_args.type == EditEntityType.artist
                                          ? Icons.person_rounded
                                          : Icons.folder_rounded)),
                        ),
                      ),
                    ),
                    if (_isMedia) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _subtitleCtrl,
                        decoration: InputDecoration(
                          labelText: tr('edit.entity_type.artist'),
                          prefixIcon: const Icon(Icons.person_rounded),
                        ),
                      ),
                    ],
                    if (_isArtist) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        key: ValueKey(_artistMainRegion.key),
                        initialValue: _artistRegionLabel(),
                        readOnly: true,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Region principal',
                          prefixIcon: Icon(Icons.language_rounded),
                          suffixIcon: Icon(Icons.lock_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _countryCtrl,
                        readOnly: true,
                        onTap: _pickArtistCountry,
                        decoration: InputDecoration(
                          labelText: 'Pais (opcional)',
                          prefixIcon: const Icon(Icons.public_rounded),
                          hintText: 'Selecciona pais',
                          suffixIcon: IconButton(
                            tooltip: _countryCtrl.text.trim().isNotEmpty
                                ? 'Limpiar pais'
                                : 'Seleccionar pais',
                            onPressed: _countryCtrl.text.trim().isNotEmpty
                                ? _clearArtistCountry
                                : _pickArtistCountry,
                            icon: Icon(
                              _countryCtrl.text.trim().isNotEmpty
                                  ? Icons.close_rounded
                                  : Icons.arrow_drop_down_rounded,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_isCapture) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _formatCaptureBytes(_capture!.size),
                        readOnly: true,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Peso',
                          prefixIcon: Icon(Icons.storage_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _formatCaptureDate(_capture!.modifiedAt),
                        readOnly: true,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Fecha de captura',
                          prefixIcon: Icon(Icons.calendar_month_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _capture!.sourceTitle?.isNotEmpty == true
                            ? _capture!.sourceTitle!
                            : 'Fuente no registrada',
                        readOnly: true,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Fuente',
                          prefixIcon: Icon(Icons.movie_filter_rounded),
                        ),
                      ),
                    ],
                    if (_isCaptureTag) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: '${_captureTag!.count} capturas',
                        readOnly: true,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Contenido',
                          prefixIcon: Icon(Icons.photo_library_rounded),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isCapture) ...[
              const SizedBox(height: 12),
              _captureTagsSection(theme),
            ],
            if (!_isCapture && !_isCaptureTag) ...[
              _artistClassificationSection(theme),
              const SizedBox(height: 12),
              Text(
                (_isTopic || _isTopicPlaylist)
                    ? tr('edit.cover_color')
                    : tr('edit.cover'),
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
                              label: Text(tr('edit.choose_image')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _searchWebThumbnail,
                              icon: const Icon(Icons.public_rounded),
                              label: Text(tr('edit.search_web')),
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
                              decoration: InputDecoration(
                                labelText: tr('edit.selected_web_image'),
                                prefixIcon: const Icon(Icons.image_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _clearThumbnail,
                            child: Text(tr('sources.clear')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _deleteCurrentThumbnail,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text(tr('edit.clear_cover')),
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
            ],
            if (_isCaptureTag) ...[
              const SizedBox(height: 12),
              Text(
                tr('edit.cover_color'),
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
                      SourceColorPickerField(
                        color: _colorValue != null
                            ? Color(_colorValue!)
                            : theme.colorScheme.primary,
                        onChanged: (c) => setState(() {
                          _colorValue = c.toARGB32();
                        }),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Thumbnail',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _captureTagThumbnailPicker(theme),
                    ],
                  ),
                ),
              ),
            ],
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
                      if (_isAudioMedia) ...[
                        const SizedBox(height: 12),
                        _ExtraActionCard(
                          icon: Icons.auto_fix_high_rounded,
                          title: 'Sonido limpio',
                          subtitle:
                              'Detecta silencios largos y crea una variante limpia sin tocar el archivo original.',
                          busy: _audioCleanupBusy,
                          busyLabel: 'Procesando...',
                          actionLabel: 'Analizar silencios',
                          onPressed: _runAudioCleanupFlow,
                        ),
                        const SizedBox(height: 14),
                        Divider(color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 10),
                      ],
                      _ExtraActionCard(
                        icon: Icons.compare_arrows_rounded,
                        title: 'Transferencia de datos',
                        subtitle:
                            'Pasa metadata, portada, playlists y estadisticas de esta version a otra cancion.',
                        busy: _dataTransferBusy,
                        busyLabel: 'Transfiriendo...',
                        actionLabel: 'Transferir a otra cancion',
                        onPressed: _runDataTransferFlow,
                      ),
                      if (_isAudioMedia) ...[
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

class _CaptureEditTagRow extends StatelessWidget {
  const _CaptureEditTagRow({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
              child: const SizedBox(width: 14, height: 14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureTagSearchSheet extends StatefulWidget {
  const _CaptureTagSearchSheet({required this.folders, required this.selected});

  final List<CaptureTagFolder> folders;
  final List<String> selected;

  @override
  State<_CaptureTagSearchSheet> createState() => _CaptureTagSearchSheetState();
}

class _CaptureTagSearchSheetState extends State<_CaptureTagSearchSheet> {
  final TextEditingController _queryCtrl = TextEditingController();
  late final Set<String> _selectedKeys = widget.selected
      .map((tag) => tag.toLowerCase())
      .toSet();
  late final List<String> _selectedLabels = List<String>.from(widget.selected);
  String _query = '';

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  List<CaptureTagFolder> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.folders;
    return widget.folders
        .where((folder) => folder.tag.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filtered = _filtered;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sell_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Asignar etiquetas',
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
                    controller: _queryCtrl,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _queryCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                      hintText: 'Buscar etiquetas',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No hay etiquetas disponibles.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final folder = filtered[index];
                        final selected = _selectedKeys.contains(folder.key);
                        return _CaptureEditTagRow(
                          label: folder.tag,
                          color: Color(folder.colorValue),
                          subtitle: '${folder.count} capturas',
                          selected: selected,
                          onTap: () => _toggle(folder),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_selectedLabels),
                  icon: const Icon(Icons.check_rounded),
                  label: Text('Aplicar ${_selectedLabels.length} etiquetas'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(CaptureTagFolder folder) {
    setState(() {
      if (_selectedKeys.contains(folder.key)) {
        _selectedKeys.remove(folder.key);
        _selectedLabels.removeWhere(
          (tag) => tag.toLowerCase() == folder.tag.toLowerCase(),
        );
      } else {
        _selectedKeys.add(folder.key);
        _selectedLabels.add(folder.tag);
      }
    });
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

class _ExtraActionCard extends StatelessWidget {
  const _ExtraActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.busyLabel,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final String busyLabel;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: busy ? null : onPressed,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon),
              label: Text(busy ? busyLabel : actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferTargetSheet extends StatefulWidget {
  const _TransferTargetSheet({required this.candidates});

  final List<MediaItem> candidates;

  @override
  State<_TransferTargetSheet> createState() => _TransferTargetSheetState();
}

class _TransferTargetSheetState extends State<_TransferTargetSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<MediaItem> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.candidates;
    return widget.candidates
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
    final items = _filtered;
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
                      const Icon(Icons.compare_arrows_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Elegir cancion destino',
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
                      hintText: 'Buscar por cancion o artista',
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
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Chip(
                    avatar: const Icon(Icons.library_music_rounded, size: 18),
                    label: Text('${widget.candidates.length} disponibles'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron canciones.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final thumb = item.effectiveThumbnail?.trim() ?? '';
                        final provider = thumb.isEmpty
                            ? null
                            : (thumb.startsWith('http')
                                  ? NetworkImage(thumb)
                                  : FileImage(File(thumb)) as ImageProvider);
                        return Material(
                          color: scheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: scheme.outlineVariant),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            onTap: () => Navigator.of(context).pop(item),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: provider == null
                                    ? ColoredBox(
                                        color: scheme.surfaceContainerHighest,
                                        child: const Icon(
                                          Icons.music_note_rounded,
                                        ),
                                      )
                                    : Image(image: provider, fit: BoxFit.cover),
                              ),
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item.displaySubtitle.isEmpty
                                  ? 'Artista desconocido'
                                  : item.displaySubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.selectedCode});

  final String? selectedCode;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _normalize(String value) {
    var text = value.trim().toLowerCase();
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    accents.forEach((raw, clean) {
      text = text.replaceAll(raw, clean);
    });
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _normalize(_searchCtrl.text);
    final countries = CountryCatalog.all
        .where((entry) {
          if (query.isEmpty) return true;
          final name = _normalize(entry.name);
          final code = entry.code.toLowerCase();
          return name.contains(query) || code.contains(query);
        })
        .toList(growable: false);
    countries.sort((a, b) {
      final regionCompare = ArtistMainRegionX.fromRaw(a.regionKey).simpleLabel
          .toLowerCase()
          .compareTo(
            ArtistMainRegionX.fromRaw(b.regionKey).simpleLabel.toLowerCase(),
          );
      if (regionCompare != 0) return regionCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return SafeArea(
      child: Padding(
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
                'Seleccionar pais',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Busca y elige un pais. La region se define automaticamente.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Buscar pais',
                  hintText: 'Nombre o codigo ISO',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar',
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: countries.isEmpty
                    ? Center(
                        child: Text(
                          'No hay paises para esa busqueda.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: countries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final country = countries[index];
                          final flag = CountryCatalog.flagFromIso(country.code);
                          final selected =
                              country.code == (widget.selectedCode ?? '');

                          return Material(
                            color: selected
                                ? theme.colorScheme.primaryContainer.withValues(
                                    alpha: 0.52,
                                  )
                                : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.56),
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              leading: Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface.withValues(
                                    alpha: 0.7,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  flag.isEmpty ? '•' : flag,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              title: Text(
                                country.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${country.code} · ${ArtistMainRegionX.fromRaw(country.regionKey).simpleLabel}',
                              ),
                              trailing: selected
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: theme.colorScheme.primary,
                                    )
                                  : const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.of(context).pop(country),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
