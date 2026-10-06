import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'legacy_restoration_snapshot.dart';
import 'playback_database_opener.dart';
import 'playback_repository.dart';
import 'playback_state_storage.dart';

class PlaybackDebugBootstrap {
  static Future<(PlaybackRepository, PlaybackStateStorage)> open(
    GetStorage legacy,
    String scope, {
    Directory? supportDirectory,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(scope)) {
      throw ArgumentError('Invalid installation scope');
    }
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}/playback/debug-migration-$scope',
    );
    await directory.create(recursive: true);
    final source = File('${directory.path}/source.json');
    if (!await source.exists()) {
      final frozen = jsonEncode({
        'restoration': LegacyRestorationSnapshot.capture(legacy.read).bytes,
        'library': legacy.read<List>('local_library_items') ?? [],
        'events': legacy.read<List>('listening_events_v1') ?? [],
      });
      final temporary = File('${directory.path}/source.pending');
      await temporary.writeAsString(frozen, flush: true);
      await temporary.rename(source.path);
    }
    final bytes = await source.readAsString();
    final hash = sha256.convert(utf8.encode(bytes)).toString();
    final frozen = jsonDecode(bytes) as Map<String, dynamic>;
    final restoration = LegacyRestorationSnapshot.fromBytes(
      frozen['restoration'] as String,
    );
    final repository = PlaybackRepository(
      await PlaybackDatabaseOpener.openStaging(
        generation: 'debug-$scope',
        supportDirectory: support,
        temporaryDirectory: supportDirectory,
      ),
    );
    try {
      await repository.importLegacyHistory(
        library: (frozen['library'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        events: (frozen['events'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        scope: scope,
        sourceHash: hash,
        nowUtcMs: DateTime.now().millisecondsSinceEpoch,
      );
      await repository.importRestoration(
        sourceId: 'debug-restoration-$scope',
        sourceHash: restoration.hash,
        importedAtUtcMs: DateTime.now().millisecondsSinceEpoch,
        states: restoration.states,
        resumePoints: restoration.resumePoints,
      );
      await repository.recoverInterruptedSessions();
      final pending = File('${directory.path}/verified.pending');
      await pending.writeAsString(
        jsonEncode({
          'schemaVersion': 3,
          'sourceHash': hash,
          'generation': 'debug-$scope',
        }),
        flush: true,
      );
      await pending.rename('${directory.path}/verified.json');
      return (repository, await PlaybackStateStorage.load(repository, legacy));
    } catch (_) {
      await repository.close();
      rethrow;
    }
  }
}
