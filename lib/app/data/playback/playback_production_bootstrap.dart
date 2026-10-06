import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../local/catalog_storage.dart';
import '../local/domain_storage.dart';
import 'legacy_restoration_snapshot.dart';
import 'playback_database_opener.dart';
import 'playback_repository.dart';
import 'playback_state_storage.dart';

class PlaybackProductionState {
  PlaybackProductionState(
    this.repository,
    this.restoration,
    this.catalog,
    this.domains,
    this.generation,
    this.installationScope,
  );
  final PlaybackRepository repository;
  final PlaybackStateStorage restoration;
  final CatalogStorage catalog;
  final DomainStorage domains;
  final String generation;
  final String installationScope;
}

/// Engines must remain stopped until this owner has been activated.
class PlaybackProductionBootstrap {
  static const enabledByDefault = bool.fromEnvironment(
    'LISTENFY_SQLITE_RELEASE_MIGRATION',
    defaultValue: true,
  );

  static Future<bool> shouldUseProduction({
    bool enabled = enabledByDefault,
    Directory? supportDirectory,
  }) async => enabled || await hasActive(supportDirectory: supportDirectory);

  static Future<bool> hasActive({Directory? supportDirectory}) async {
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    return File('${support.path}/playback/active.json').exists();
  }

  static Future<PlaybackProductionState> open(
    GetStorage legacy, {
    Directory? supportDirectory,
    Directory? capturesDirectory,
    void Function(String)? onProgress,
    Future<void> Function(String)? faultInjector,
  }) async {
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    final root = Directory('${support.path}/playback');
    await root.create(recursive: true);
    final lock = await File(
      '${root.path}/activation.lock',
    ).open(mode: FileMode.append);
    await lock.lock(FileLock.exclusive);
    try {
      final active = File('${root.path}/active.json');
      if (await active.exists()) {
        onProgress?.call('opening');
        return await _loadActive(active, support, legacy);
      }
      onProgress?.call('capturing');
      final planFile = File('${root.path}/migration_plan.json');
      Map<String, dynamic> plan;
      if (await planFile.exists()) {
        plan =
            jsonDecode(await planFile.readAsString()) as Map<String, dynamic>;
      } else {
        final generation = 'production-${const Uuid().v4()}';
        final keys = <String>{
          ...catalogKeys,
          ...durableDomainKeys.keys,
          ...LegacyRestorationSnapshot.keys,
          'listening_events_v1',
          'appBackgroundImagePath',
        };
        final values = <String, dynamic>{
          for (final key in keys) key: legacy.read(key),
        };
        final debugScope = legacy.read<String>('playback_staging_installation');
        if (debugScope != null) {
          if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(debugScope)) {
            throw StateError('Invalid previous SQLite installation scope');
          }
          final debugFile = File('${root.path}/staging/debug-$debugScope.db');
          if (!await debugFile.exists()) {
            throw StateError(
              'Previous SQLite debug database is missing; refusing stale legacy import',
            );
          }
          final previous = PlaybackRepository(
            await PlaybackDatabaseOpener.openStaging(
              generation: 'debug-$debugScope',
              supportDirectory: support,
              temporaryDirectory: support,
            ),
          );
          try {
            values['_previousSqlite'] = await previous.exportCompleteDatabase();
          } finally {
            await previous.close();
          }
        }
        final snapshot = jsonEncode(values);
        final source = File('${root.path}/$generation.source.json');
        await _publish(source, snapshot);
        plan = {
          'version': 1,
          'generation': generation,
          'installationScope': debugScope ?? generation,
          'sourceHash': sha256.convert(utf8.encode(snapshot)).toString(),
        };
        await _publish(planFile, jsonEncode(plan));
      }
      final generation = _generation(plan);
      final installationScope = plan['installationScope'] as String;
      if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(installationScope)) {
        throw FormatException('Invalid active installation scope');
      }
      final source = File('${root.path}/$generation.source.json');
      final bytes = await source.readAsString();
      if (sha256.convert(utf8.encode(bytes)).toString() != plan['sourceHash']) {
        throw StateError('Frozen migration source checksum mismatch');
      }
      final frozen = _FrozenStorage(jsonDecode(bytes) as Map<String, dynamic>);
      final promoted = File('${root.path}/generations/$generation.db');
      final receipt = File('${root.path}/$generation.verified.json');
      if (!await promoted.exists()) {
        onProgress?.call('importing');
        final database = await PlaybackDatabaseOpener.openStaging(
          generation: generation,
          supportDirectory: support,
          temporaryDirectory: support,
        );
        final repository = PlaybackRepository(database);
        try {
          final previousSqlite = frozen.read<Map<String, dynamic>>(
            '_previousSqlite',
          );
          if (previousSqlite != null) {
            await repository.restoreCompleteDatabase(previousSqlite);
          } else {
            final restoration = LegacyRestorationSnapshot.capture(frozen.read);
            await repository.importLegacyHistory(
              library: (frozen.read<List>('local_library_items') ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
              events: (frozen.read<List>('listening_events_v1') ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
              scope: installationScope,
              sourceHash: plan['sourceHash'] as String,
              nowUtcMs: DateTime.now().millisecondsSinceEpoch,
            );
            await faultInjector?.call('afterHistory');
            await repository.importRestoration(
              sourceId: 'production-restoration-$generation',
              sourceHash: restoration.hash,
              importedAtUtcMs: DateTime.now().millisecondsSinceEpoch,
              states: restoration.states,
              resumePoints: restoration.resumePoints,
            );
            await CatalogStorage.open(
              repository,
              frozen,
              generation,
              supportDirectory: support,
            );
            await DomainStorage.open(
              repository,
              frozen,
              generation,
              supportDirectory: support,
              capturesDirectory: capturesDirectory,
            );
          }
          onProgress?.call('verifying');
          await database.verify();
          if (previousSqlite == null) {
            final sessions = await database
                .customSelect(
                  "SELECT count(*) AS total FROM playback_session WHERE status='legacy'",
                )
                .getSingle();
            if (sessions.read<int>('total') !=
                (frozen.read<List>('listening_events_v1') ?? []).length) {
              throw StateError('Playback migration count mismatch');
            }
          }
          final catalog = await repository.readCatalog();
          for (final key in previousSqlite == null ? catalogKeys : <String>[]) {
            if (catalog[key]!.length != (frozen.read<List>(key) ?? []).length) {
              throw StateError('Catalog migration count mismatch: $key');
            }
          }
          final checkpoint = await database
              .customSelect('PRAGMA wal_checkpoint(TRUNCATE)')
              .getSingle();
          if (checkpoint.data.values.first != 0) {
            throw StateError('Migration checkpoint is busy');
          }
        } finally {
          await repository.close();
        }
        final staging = File('${root.path}/staging/$generation.db');
        final digest = (await sha256.bind(staging.openRead()).first).toString();
        await _publish(
          receipt,
          jsonEncode({...plan, 'schemaVersion': 6, 'databaseHash': digest}),
        );
        await promoted.parent.create(recursive: true);
        await staging.rename(promoted.path);
      }
      final verifiedBytes = await receipt.readAsString();
      final verified = jsonDecode(verifiedBytes) as Map<String, dynamic>;
      if (verified['sourceHash'] != plan['sourceHash'] ||
          _generation(verified) != generation ||
          verified['databaseHash'] !=
              (await sha256.bind(promoted.openRead()).first).toString()) {
        throw StateError('Candidate generation checksum mismatch');
      }
      onProgress?.call('activating');
      await faultInjector?.call('beforeManifest');
      await _publish(
        active,
        jsonEncode({
          ...verified,
          'receiptHash': sha256.convert(utf8.encode(verifiedBytes)).toString(),
        }),
      );
      await faultInjector?.call('afterManifest');
      return await _loadActive(active, support, legacy);
    } finally {
      await lock.unlock();
      await lock.close();
    }
  }

  static String _generation(Map<String, dynamic> data) {
    final generation = data['generation'];
    if (data['version'] != 1 ||
        generation is! String ||
        !RegExp(r'^production-[a-zA-Z0-9-]{1,60}$').hasMatch(generation)) {
      throw FormatException('Invalid playback activation manifest');
    }
    return generation;
  }

  static Future<PlaybackProductionState> _loadActive(
    File manifest,
    Directory support,
    GetStorage legacy,
  ) async {
    final data =
        jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    final generation = _generation(data);
    final installationScope = data['installationScope'];
    if (installationScope is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(installationScope)) {
      throw FormatException('Invalid active installation scope');
    }
    if (data['schemaVersion'] != 6) {
      throw StateError('Unsupported active manifest schema');
    }
    final receipt = await File(
      '${support.path}/playback/$generation.verified.json',
    ).readAsString();
    if (sha256.convert(utf8.encode(receipt)).toString() !=
        data['receiptHash']) {
      throw StateError('Activation receipt checksum mismatch');
    }
    final verified = jsonDecode(receipt) as Map<String, dynamic>;
    if (_generation(verified) != generation ||
        verified['installationScope'] != installationScope ||
        verified['sourceHash'] != data['sourceHash'] ||
        verified['databaseHash'] != data['databaseHash']) {
      throw StateError('Activation receipt mismatch');
    }
    // The database hash seals the candidate, not the mutable active database.
    final database = await PlaybackDatabaseOpener.openActive(
      generation: generation,
      supportDirectory: support,
      temporaryDirectory: support,
    );
    final repository = PlaybackRepository(database);
    try {
      await repository.recoverInterruptedSessions();
      return PlaybackProductionState(
        repository,
        await PlaybackStateStorage.load(repository, legacy),
        await CatalogStorage.loadExisting(repository),
        await DomainStorage.loadExisting(repository, legacy),
        generation,
        installationScope,
      );
    } catch (_) {
      await repository.close();
      rethrow;
    }
  }

  static Future<void> _publish(File target, String bytes) async {
    final pending = File('${target.path}.pending');
    await pending.writeAsString(bytes, flush: true);
    await pending.rename(target.path);
  }
}

class _FrozenStorage implements GetStorage {
  _FrozenStorage(this.values);
  final Map<String, dynamic> values;
  @override
  T? read<T>(String key) => values[key] as T?;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Frozen source is read-only');
}
