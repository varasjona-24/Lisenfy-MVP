import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/app/data/playback/playback_production_bootstrap.dart';
import 'package:listenfy/app/data/playback/playback_database_opener.dart';
import 'package:listenfy/app/data/playback/playback_repository.dart';

class _Legacy implements GetStorage {
  final values = <String, dynamic>{
    'local_library_items': [
      {
        'id': 'song',
        'title': 'Song',
        'subtitle': 'Artist',
        'variants': [],
        'playCount': 3,
      },
    ],
    'artist_profiles': [
      {
        'key': 'artist',
        'displayName': 'Artist',
        'kind': 'singer',
        'memberKeys': [],
      },
    ],
  };
  @override
  T? read<T>(String key) => values[key] as T?;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected legacy write');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Legacy legacy;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('production-activation-');
    legacy = _Legacy();
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  Future<PlaybackProductionState> open({
    Future<void> Function(String)? fault,
  }) => PlaybackProductionBootstrap.open(
    legacy,
    supportDirectory: directory,
    capturesDirectory: Directory('${directory.path}/captures'),
    faultInjector: fault,
  );

  test(
    'activation is verified and restart never reimports stale legacy data',
    () async {
      final state = await open();
      try {
        expect(
          await PlaybackProductionBootstrap.hasActive(
            supportDirectory: directory,
          ),
          isTrue,
        );
        expect(state.catalog.read<List>('local_library_items'), hasLength(1));
        expect(
          state.catalog.read<List>('artist_profiles')!.single['key'],
          startsWith('artist-'),
        );
        await state.catalog.write('local_library_items', []);
      } finally {
        await state.repository.close();
      }
      final reopened = await open();
      try {
        expect(reopened.catalog.read<List>('local_library_items'), isEmpty);
      } finally {
        await reopened.repository.close();
      }
      expect(legacy.values['local_library_items'], hasLength(1));
    },
  );

  test('adopts current debug SQLite instead of stale GetStorage', () async {
    legacy.values['playback_staging_installation'] = 'previous';
    final previous = PlaybackRepository(
      await PlaybackDatabaseOpener.openStaging(
        generation: 'debug-previous',
        supportDirectory: directory,
        temporaryDirectory: directory,
      ),
    );
    await previous.replaceCatalog('local_library_items', [
      {'id': 'newer', 'title': 'Newer', 'variants': []},
    ]);
    final before = await previous.exportCompleteDatabase();
    await previous.close();
    final state = await open();
    try {
      expect(
        state.catalog.read<List>('local_library_items')!.single['id'],
        'newer',
      );
      expect(state.installationScope, 'previous');
      expect(await state.repository.exportCompleteDatabase(), before);
    } finally {
      await state.repository.close();
    }
  });

  test(
    'interrupted import resumes frozen source without duplication',
    () async {
      await expectLater(
        open(
          fault: (stage) async {
            if (stage == 'afterHistory') throw StateError('simulated kill');
          },
        ),
        throwsStateError,
      );
      legacy.values['local_library_items'] = [];
      final state = await open();
      try {
        expect(state.catalog.read<List>('local_library_items'), hasLength(1));
        final before = await state.repository.exportCompleteDatabase();
        expect(
          ((before['tables'] as Map)['legacy_metrics'] as List),
          hasLength(1),
        );
      } finally {
        await state.repository.close();
      }
    },
  );

  test('opener rejects a generation not selected in the manifest', () async {
    await expectLater(
      PlaybackDatabaseOpener.openActive(
        generation: 'production-unselected',
        supportDirectory: directory,
        temporaryDirectory: directory,
      ),
      throwsA(anything),
    );
  });

  test(
    'normal builds use SQLite and active data cannot fall back to legacy',
    () async {
      expect(PlaybackProductionBootstrap.enabledByDefault, isTrue);
      expect(
        await PlaybackProductionBootstrap.shouldUseProduction(
          supportDirectory: directory,
        ),
        isTrue,
      );
      expect(
        await PlaybackProductionBootstrap.shouldUseProduction(
          enabled: false,
          supportDirectory: directory,
        ),
        isFalse,
      );
      final state = await open();
      await state.repository.close();
      expect(
        await PlaybackProductionBootstrap.shouldUseProduction(
          enabled: false,
          supportDirectory: directory,
        ),
        isTrue,
      );
    },
  );

  test('interruption before manifest retries the same candidate', () async {
    await expectLater(
      open(
        fault: (stage) async {
          if (stage == 'beforeManifest') throw StateError('simulated kill');
        },
      ),
      throwsStateError,
    );
    expect(
      await PlaybackProductionBootstrap.hasActive(supportDirectory: directory),
      isFalse,
    );
    final plan = await File(
      '${directory.path}/playback/migration_plan.json',
    ).readAsString();
    final recovered = await open();
    try {
      expect(recovered.generation, (jsonDecode(plan) as Map)['generation']);
      expect(recovered.catalog.read<List>('local_library_items'), hasLength(1));
    } finally {
      await recovered.repository.close();
    }
  });

  test(
    'interruption after manifest loads committed active generation',
    () async {
      await expectLater(
        open(
          fault: (stage) async {
            if (stage == 'afterManifest') throw StateError('simulated kill');
          },
        ),
        throwsStateError,
      );
      expect(
        await PlaybackProductionBootstrap.hasActive(
          supportDirectory: directory,
        ),
        isTrue,
      );
      final state = await open();
      await state.repository.close();
    },
  );

  test(
    'corrupt frozen source blocks activation and keeps legacy intact',
    () async {
      await expectLater(
        open(
          fault: (_) async {
            throw StateError('simulated kill');
          },
        ),
        throwsStateError,
      );
      final plan =
          jsonDecode(
                await File(
                  '${directory.path}/playback/migration_plan.json',
                ).readAsString(),
              )
              as Map;
      await File(
        '${directory.path}/playback/${plan['generation']}.source.json',
      ).writeAsString('{}');
      await expectLater(open(), throwsStateError);
      expect(
        await PlaybackProductionBootstrap.hasActive(
          supportDirectory: directory,
        ),
        isFalse,
      );
      expect(legacy.values['local_library_items'], hasLength(1));
    },
  );

  test(
    'missing active database never silently recreates an empty database',
    () async {
      final state = await open();
      final generation = state.generation;
      await state.repository.close();
      await File(
        '${directory.path}/playback/generations/$generation.db',
      ).rename('${directory.path}/saved.db');
      await expectLater(open(), throwsStateError);
      expect(
        await File(
          '${directory.path}/playback/generations/$generation.db',
        ).exists(),
        isFalse,
      );
    },
  );
}
