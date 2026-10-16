import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../data/playback/playback_repository.dart';
import '../data/playback/playback_session_command.dart';
import '../models/media_item.dart';
import 'sqlite_engine_history_recorder.dart';

/// History composition for the selected SQLite owner, after verified activation.
class SqliteEngineHistoryFactory {
  SqliteEngineHistoryFactory({
    required this.repository,
    required this.installationScope,
  });
  final PlaybackRepository repository;
  final String installationScope;
  static const _uuid = Uuid();
  static const _urlNamespace = '6ba7b811-9dad-11d1-80b4-00c04fd430c8';

  SqliteEngineHistoryRecorder create({
    DateTime Function()? clock,
    int Function()? monotonicClock,
  }) {
    final epoch = _uuid.v4();
    return SqliteEngineHistoryRecorder(
      repository: repository,
      commandIdFactory: _uuid.v4,
      clock: clock,
      monotonicClock: monotonicClock,
      sessionFactory: (item, variant, utc, mono, position, duration, speed) async {
        final alias = PlaybackAlias(
          namespace: 'local',
          scope: installationScope,
          value: item.id,
        );
        var mediaId = await repository.bindLibraryIdentity(item.id, alias);
        if (mediaId == null) {
          final candidate = _uuid.v4();
          try {
            await repository.registerIdentity(
              RegisterPlaybackIdentity(
                commandId: _uuid.v4(),
                mediaId: candidate,
                createdAtUtcMs: utc,
                alias: alias,
                libraryId: item.id,
              ),
            );
            mediaId = candidate;
          } catch (error) {
            // Only accept a concurrent registration if that exact scoped alias exists.
            mediaId = await repository.resolveAlias(alias);
            if (mediaId == null) {
              rethrow;
            }
          }
        }
        String contentKey;
        final local = variant.localPath?.trim();
        if (local != null && local.isNotEmpty) {
          contentKey =
              'sha256:${await sha256.bind(File(local).openRead()).first}';
        } else {
          // Remote bytes are not verified. Locator identity is explicitly weaker.
          contentKey = 'remote:${variant.fileName}:${item.playableUrl}';
        }
        final variantId = _uuid.v5(
          _urlNamespace,
          jsonEncode([
            'variant',
            1,
            mediaId,
            variant.kind.name,
            variant.format.toLowerCase().trim(),
            variant.roleKey,
            contentKey,
          ]),
        );
        final session = _uuid.v4();
        return OpenPlaybackSession(
          commandId: _uuid.v4(),
          sessionId: session,
          eventId: _uuid.v4(),
          mediaId: mediaId,
          variant: PlaybackVariant(
            id: variantId,
            mode: variant.kind == MediaVariantKind.audio
                ? PlaybackMode.audio
                : PlaybackMode.video,
            role: variant.roleKey,
            format: variant.format.toLowerCase().trim(),
          ),
          snapshot: PlaybackSnapshot(
            id: _uuid.v4(),
            title: item.title,
            artist: item.displaySubtitle,
            artworkRef: item.thumbnailLocalPath?.trim().isNotEmpty == true
                ? 'local:${item.thumbnailLocalPath}'
                : item.thumbnail?.trim().isNotEmpty == true
                ? 'remote:${item.thumbnail}'
                : null,
          ),
          startedAtUtcMs: utc,
          clockEpoch: epoch,
          monotonicMs: mono,
          context: PlaybackContext.unknown,
          positionMs: position.inMilliseconds,
          durationMs: duration > Duration.zero ? duration.inMilliseconds : null,
          speed: speed,
          utcOffsetMinutes: DateTime.fromMillisecondsSinceEpoch(
            utc,
          ).timeZoneOffset.inMinutes,
        );
      },
    );
  }
}
