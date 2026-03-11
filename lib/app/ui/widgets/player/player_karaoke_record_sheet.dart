import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../Modules/player/Video/view/lyrics_entry_page.dart';
import '../../../data/local/local_library_store.dart';
import '../../../models/media_item.dart';
import '../../../routes/app_routes.dart';
import '../../../services/karaoke_flow_coordinator_service.dart';
import '../../../services/karaoke_recording_service.dart';
import '../../../services/karaoke_remote_pipeline_service.dart';
import 'player_karaoke_sheet.dart';

void openPlayerKaraokeRecordSheet({
  required MediaItem item,
  required String sourcePath,
  double heightFactor = 0.78,
}) {
  if (Get.isBottomSheetOpen ?? false) return;

  Get.bottomSheet<void>(
    FractionallySizedBox(
      heightFactor: heightFactor,
      child: PlayerKaraokeRecordSheet(item: item, sourcePath: sourcePath),
    ),
    isScrollControlled: true,
    useRootNavigator: true,
    ignoreSafeArea: false,
    isDismissible: true,
    enableDrag: true,
  );
}

enum _LyricsDecision { add, continueWithoutLyrics, cancel }

class PlayerKaraokeRecordSheet extends StatefulWidget {
  const PlayerKaraokeRecordSheet({
    super.key,
    required this.item,
    required this.sourcePath,
  });

  final MediaItem item;
  final String sourcePath;

  @override
  State<PlayerKaraokeRecordSheet> createState() =>
      _PlayerKaraokeRecordSheetState();
}

class _PlayerKaraokeRecordSheetState extends State<PlayerKaraokeRecordSheet> {
  static const int _countdownFromSeconds = 5;

  final KaraokeRecordingService _recording = KaraokeRecordingService();
  final KaraokeRemotePipelineService _remote =
      Get.find<KaraokeRemotePipelineService>();
  final KaraokeFlowCoordinatorService _flow =
      Get.find<KaraokeFlowCoordinatorService>();

  late MediaItem _item;

  KaraokeRemoteSession? _remoteSession;
  String? _remoteInstrumentalPath;
  bool _remoteAvailable = false;
  bool _remotePreparing = false;
  bool _busy = false;
  bool _pausedByLyricsPrompt = false;
  double _remoteProgress = 0;
  String _remoteMessage = '';
  String? _error;
  int _countdownSeconds = 0;

  double _instrumentalGainStart = 1.0;
  double _voiceGainMix = 1.0;
  double _instrumentalGainMix = 0.8;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    // Wait an extra microtask so the bottom-sheet route is fully attached
    // before opening any modal dialog.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final canContinue = await _askLyricsBeforeRemote();
    if (!canContinue) {
      if (!mounted) return;
      setState(() {
        _pausedByLyricsPrompt = true;
        _remoteMessage = 'Proceso en pausa hasta que confirmes continuar.';
      });
      return;
    }
    await _prepareRemoteSession();
  }

  bool _hasLyrics(MediaItem item) {
    final main = (item.lyrics ?? '').trim().isNotEmpty;
    final translations = (item.translations ?? const <String, String>{}).values
        .any((v) => v.trim().isNotEmpty);
    final timed = (item.timedLyrics ?? const <String, List<TimedLyricCue>>{})
        .values
        .any((list) => list.isNotEmpty);
    return main || translations || timed;
  }

  Future<bool> _askLyricsBeforeRemote() async {
    if (_hasLyrics(_item)) return true;
    if (!mounted) return false;

    final choice = await showDialog<_LyricsDecision>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Letras no disponibles'),
        content: const Text(
          'Esta canción no tiene letras guardadas. ¿Deseas agregar letras antes de enviar la petición al backend?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LyricsDecision.cancel),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_LyricsDecision.continueWithoutLyrics),
            child: const Text('Continuar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LyricsDecision.add),
            child: const Text('Agregar letra'),
          ),
        ],
      ),
    );

    if (choice == null || choice == _LyricsDecision.cancel) return false;

    if (choice == _LyricsDecision.add) {
      await _openLyricsEditor();
    }

    return true;
  }

  Future<void> _openLyricsEditor() async {
    final result = await Get.toNamed(
      AppRoutes.lyricsEntry,
      arguments: LyricsEntryArgs(
        title: _item.title,
        artist: _item.displaySubtitle,
        lyrics: _item.lyrics,
        lyricsLanguage: _item.lyricsLanguage,
        translations: _item.translations,
        timedLyrics: _item.timedLyrics,
      ),
    );

    if (result is! LyricsEntryResult) return;

    final updated = _item.copyWith(
      lyrics: result.lyrics,
      lyricsLanguage: result.lyricsLanguage,
      translations: result.translations,
      timedLyrics: result.timedLyrics,
    );

    if (Get.isRegistered<LocalLibraryStore>()) {
      await Get.find<LocalLibraryStore>().upsert(updated);
    }

    if (!mounted) return;
    setState(() {
      _item = updated;
    });
  }

  Future<void> _prepareRemoteSession() async {
    if (_busy || _remotePreparing) return;
    setState(() {
      _pausedByLyricsPrompt = false;
      _remotePreparing = true;
      _error = null;
      _remoteAvailable = false;
      _remoteSession = null;
      _remoteInstrumentalPath = null;
      _remoteProgress = 0.02;
      _remoteMessage = 'Validando conexión con servidor...';
    });

    try {
      final reachable = await _remote.isBackendReachable();
      if (!reachable) {
        throw Exception(
          'No hay conexión con backend. El modo karaoke remoto requiere internet.',
        );
      }
      if (!mounted) return;
      setState(() {
        _remoteAvailable = true;
        _remoteProgress = 0.08;
        _remoteMessage = 'Subiendo audio fuente al servidor...';
      });

      final created = await _remote.createSessionFromSource(
        item: _item,
        sourcePath: widget.sourcePath,
      );

      if (!mounted) return;
      setState(() {
        _remoteSession = created;
        _remoteProgress = 0.14;
        _remoteMessage = 'Separando instrumental en backend...';
      });

      final ready = await _remote.waitUntilReady(
        sessionId: created.id,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _remoteProgress = (0.14 + progress.progress * 0.72).clamp(
              0.14,
              0.9,
            );
            _remoteMessage = progress.message;
          });
        },
      );

      final instrumentalPath = await _remote.downloadInstrumentalToLocal(
        session: ready,
        item: _item,
      );

      if (!mounted) return;
      setState(() {
        _remoteSession = ready;
        _remoteInstrumentalPath = instrumentalPath;
        _remoteProgress = 1;
        _remoteMessage = 'Instrumental listo. Puedes iniciar grabación.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _remoteProgress = 0;
        _remoteMessage = 'No se pudo preparar la sesión remota.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _remotePreparing = false;
        });
      }
    }
  }

  Future<void> _startKaraoke() async {
    if (_busy || _remotePreparing) return;

    if (!_remoteAvailable) {
      setState(() {
        _error = 'No hay conexión activa con backend.';
      });
      return;
    }

    final session = _remoteSession;
    final instrumentalPath = _remoteInstrumentalPath?.trim() ?? '';
    if (session == null || instrumentalPath.isEmpty) {
      setState(() {
        _error = 'El instrumental remoto aún no está listo.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final countdownOk = await _runCountdown();
      if (!countdownOk) return;

      if (!mounted) return;
      setState(() {
        _remoteMessage = 'Iniciando grabación...';
      });

      final start = await _recording.startSession(
        sourcePath: widget.sourcePath,
        instrumentalGain: _instrumentalGainStart,
        instrumentalPath: instrumentalPath,
      );
      if (start == null) {
        throw Exception('Esta función solo está disponible en Android.');
      }

      await _flow.startAutoFlow(
        item: _item,
        sessionId: session.id,
        estimatedDurationMs: start.estimatedDurationMs,
        voiceGain: _voiceGainMix,
        instrumentalGain: _instrumentalGainMix,
      );

      if (!mounted) return;
      if (Get.isBottomSheetOpen ?? false) {
        Get.back<void>();
      }

      await Future<void>.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;
      openPlayerKaraokeSheet(
        _item,
        topActionLabel: 'Cancelar',
        onTopAction: _cancelOrCloseFromLyrics,
        showFlowStatus: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _countdownSeconds = 0;
        });
      }
    }
  }

  Future<bool> _runCountdown() async {
    for (int second = _countdownFromSeconds; second >= 1; second -= 1) {
      if (!mounted) return false;
      setState(() {
        _countdownSeconds = second;
        _remoteMessage = 'Comenzando grabación en $second...';
      });
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return false;
    setState(() {
      _countdownSeconds = 0;
    });
    return true;
  }

  Future<void> _cancelOrCloseFromLyrics() async {
    final snapshot = _flow.activeFlow.value;
    if (snapshot == null || snapshot.isTerminal) {
      if (Get.isBottomSheetOpen ?? false) {
        Get.back<void>();
      }
      return;
    }

    await _flow.cancelCurrent();
    if (Get.isBottomSheetOpen ?? false) {
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grabadora karaoke (backend)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Al iniciar, se abrirá la pantalla de letras con opción de cancelar.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: [
                  Text('Estado remoto', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _remotePreparing && _remoteProgress <= 0
                        ? null
                        : _remoteProgress.clamp(0.0, 1.0),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _remoteMessage.isEmpty
                        ? 'Esperando preparación remota.'
                        : _remoteMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: (_busy || _remotePreparing)
                            ? null
                            : _prepareRemoteSession,
                        icon: _remotePreparing
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_sync_rounded),
                        label: Text(
                          _remotePreparing
                              ? 'Preparando...'
                              : (_pausedByLyricsPrompt
                                    ? 'Continuar proceso'
                                    : 'Reintentar remoto'),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: (_busy || _remotePreparing)
                            ? null
                            : _openLyricsEditor,
                        icon: const Icon(Icons.lyrics_rounded),
                        label: const Text('Agregar/editar letra'),
                      ),
                      if (_remoteSession != null)
                        OutlinedButton.icon(
                          onPressed: () {
                            final id = _remoteSession!.id;
                            Clipboard.setData(ClipboardData(text: id));
                            Get.snackbar(
                              'Karaoke',
                              'Session ID copiado.',
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 2),
                            );
                          },
                          icon: const Icon(Icons.tag_rounded),
                          label: const Text('Copiar session ID'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Ganancias', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Nivel instrumental (reproducción)',
                    style: theme.textTheme.bodySmall,
                  ),
                  Slider(
                    value: _instrumentalGainStart,
                    min: 0.2,
                    max: 1.6,
                    divisions: 14,
                    label: _instrumentalGainStart.toStringAsFixed(2),
                    onChanged: _busy
                        ? null
                        : (v) {
                            setState(() {
                              _instrumentalGainStart = v;
                            });
                          },
                  ),
                  Text(
                    'Ganancia de voz (mezcla backend)',
                    style: theme.textTheme.bodySmall,
                  ),
                  Slider(
                    value: _voiceGainMix,
                    min: 0.0,
                    max: 1.8,
                    divisions: 18,
                    label: _voiceGainMix.toStringAsFixed(2),
                    onChanged: _busy
                        ? null
                        : (v) {
                            setState(() {
                              _voiceGainMix = v;
                            });
                          },
                  ),
                  Text(
                    'Ganancia instrumental (mezcla backend)',
                    style: theme.textTheme.bodySmall,
                  ),
                  Slider(
                    value: _instrumentalGainMix,
                    min: 0.0,
                    max: 1.8,
                    divisions: 18,
                    label: _instrumentalGainMix.toStringAsFixed(2),
                    onChanged: _busy
                        ? null
                        : (v) {
                            setState(() {
                              _instrumentalGainMix = v;
                            });
                          },
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed:
                        (_busy ||
                            _remotePreparing ||
                            !_remoteAvailable ||
                            _remoteInstrumentalPath == null)
                        ? null
                        : _startKaraoke,
                    icon: const Icon(Icons.fiber_manual_record_rounded),
                    label: Text(
                      _countdownSeconds > 0
                          ? 'Inicia en ${_countdownSeconds}s...'
                          : (_busy
                                ? 'Iniciando...'
                                : 'Comenzar grabación y abrir letras'),
                    ),
                  ),
                  if (_countdownSeconds > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Cuenta regresiva: ${_countdownSeconds}s',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (_remoteInstrumentalPath != null) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      'Instrumental local: $_remoteInstrumentalPath',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
