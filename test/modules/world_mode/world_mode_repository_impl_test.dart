import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/Modules/artists/data/artist_store.dart';
import 'package:listenfy/Modules/artists/domain/artist_profile.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/Modules/world_mode/agent/local_affinity_engine.dart';
import 'package:listenfy/Modules/world_mode/agent/radio_station_planner.dart';
import 'package:listenfy/Modules/world_mode/agent/sync_manager.dart';
import 'package:listenfy/Modules/world_mode/data/datasources/world_local_datasource.dart';
import 'package:listenfy/Modules/world_mode/data/datasources/world_remote_datasource.dart';
import 'package:listenfy/Modules/world_mode/data/repositories/world_mode_repository_impl.dart';
import 'package:listenfy/Modules/world_mode/domain/entities/country_entity.dart';
import 'package:listenfy/Modules/world_mode/domain/entities/world_explore_options.dart';
import 'package:listenfy/Modules/world_mode/domain/entities/world_region_catalog.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/app/data/network/dio_client.dart';
import 'package:listenfy/app/data/repo/media_repository.dart';
import 'package:listenfy/app/models/media_item.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Get.testMode = true;
    Get.reset();

    Get.put<DioClient>(DioClient(), permanent: true);
    Get.put<LocalLibraryStore>(_MemoryLocalLibraryStore(), permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  group('WorldModeRepositoryImpl (region flow)', () {
    test(
      'filtra por región y permite colaboración en regiones del principal/feat',
      () async {
        final repository = _buildRepository(
          library: <MediaItem>[
            _track(
              id: 'ar-1',
              title: 'De Música Ligera',
              artist: 'Soda Stereo',
            ),
            _track(id: 'co-1', title: 'Antología', artist: 'Shakira'),
            _track(
              id: 'collab-1',
              title: 'Bam Bam',
              artist: 'Camila Cabello feat. Ed Sheeran',
            ),
            _track(id: 'gb-1', title: 'Shape of You', artist: 'Ed Sheeran'),
          ],
          profiles: <ArtistProfile>[
            _profile(name: 'Soda Stereo', countryCode: 'AR'),
            _profile(name: 'Shakira', countryCode: 'CO'),
            _profile(name: 'Camila Cabello', countryCode: 'US'),
            _profile(name: 'Ed Sheeran', countryCode: 'GB'),
          ],
        );
        final availableRegions = await repository.getCountries();
        final availableCodes = availableRegions.map((e) => e.code).toSet();

        expect(availableCodes.contains('rio_plata'), isTrue);
        expect(availableCodes.contains('gran_colombia'), isTrue);
        expect(availableCodes.contains('norteamerica_anglosajona'), isTrue);
        expect(availableCodes.contains('islas_britanicas'), isTrue);

        final rioStations = await repository.exploreCountry(
          country: _regionEntity('rio_plata'),
          options: const WorldExploreOptions(preferOnline: false),
        );
        final rioIds = rioStations
            .expand((s) => s.tracks)
            .map((t) => t.publicId)
            .toSet();

        expect(rioIds.contains('ar-1'), isTrue);
        expect(rioIds.contains('co-1'), isFalse);
        expect(rioIds.contains('gb-1'), isFalse);
        expect(rioIds.contains('collab-1'), isFalse);

        final naStations = await repository.exploreCountry(
          country: _regionEntity('norteamerica_anglosajona'),
          options: const WorldExploreOptions(preferOnline: false),
        );
        final naIds = naStations
            .expand((s) => s.tracks)
            .map((t) => t.publicId)
            .toSet();

        final ukStations = await repository.exploreCountry(
          country: _regionEntity('islas_britanicas'),
          options: const WorldExploreOptions(preferOnline: false),
        );
        final ukIds = ukStations
            .expand((s) => s.tracks)
            .map((t) => t.publicId)
            .toSet();

        expect(naIds.contains('collab-1'), isTrue);
        expect(ukIds.contains('collab-1'), isTrue);
      },
    );

    test(
      'particiona 66 canciones en estaciones 30/30/6 sin duplicados',
      () async {
        final library = <MediaItem>[];
        for (var i = 1; i <= 66; i += 1) {
          library.add(
            _track(id: 'rio-$i', title: 'Track $i', artist: 'Artista Río'),
          );
        }

        final repository = _buildRepository(
          library: library,
          profiles: <ArtistProfile>[
            _profile(name: 'Artista Río', countryCode: 'AR'),
          ],
        );
        final stations = await repository.exploreCountry(
          country: _regionEntity('rio_plata'),
          options: const WorldExploreOptions(preferOnline: false),
        );

        expect(stations.length, 3);
        expect(stations[0].tracks.length, 30);
        expect(stations[1].tracks.length, 30);
        expect(stations[2].tracks.length, 6);

        final allTrackIds = stations
            .expand((station) => station.tracks)
            .map((track) => track.publicId)
            .toList(growable: false);
        expect(allTrackIds.toSet().length, allTrackIds.length);
      },
    );
  });
}

WorldModeRepositoryImpl _buildRepository({
  required List<MediaItem> library,
  required List<ArtistProfile> profiles,
}) {
  final artistStore = _StubArtistStore(profiles);
  final affinity = LocalAffinityEngine(artistStore: artistStore);
  return WorldModeRepositoryImpl(
    mediaRepository: _StubMediaRepository(library),
    localDatasource: WorldLocalDatasource.memory(),
    artistStore: artistStore,
    affinityEngine: affinity,
    radioPlanner: RadioStationPlanner(affinity),
    syncManager: SyncManager(WorldRemoteDatasource(DioClient())),
  );
}

class _StubMediaRepository extends MediaRepository {
  _StubMediaRepository(this._library);

  final List<MediaItem> _library;

  @override
  Future<List<MediaItem>> getLibrary({
    String? query,
    String? order,
    String? source,
  }) async {
    return _library;
  }
}

class _StubArtistStore extends ArtistStore {
  _StubArtistStore(this._profiles) : super(GetStorage('_stub_artist_store'));

  final List<ArtistProfile> _profiles;

  @override
  List<ArtistProfile> readAllSync() {
    return _profiles;
  }
}

class _MemoryLocalLibraryStore extends LocalLibraryStore {
  _MemoryLocalLibraryStore() : super(GetStorage('_memory_library_store'));

  final List<MediaItem> _items = <MediaItem>[];

  @override
  Future<List<MediaItem>> readAll() async => List<MediaItem>.from(_items);

  @override
  List<MediaItem> readAllSync() => List<MediaItem>.from(_items);

  @override
  Future<void> upsert(MediaItem item) async {
    final index = _items.indexWhere((entry) => entry.id == item.id);
    if (index < 0) {
      _items.add(item);
      return;
    }
    _items[index] = item;
  }
}

ArtistProfile _profile({required String name, required String countryCode}) {
  return ArtistProfile(
    key: ArtistProfile.normalizeKey(name),
    displayName: name,
    countryCode: countryCode,
  );
}

CountryEntity _regionEntity(String regionCode) {
  final def = WorldRegionCatalog.byCode(regionCode);
  if (def == null) {
    throw StateError('Region not found: $regionCode');
  }
  return CountryEntity(
    code: def.code,
    name: def.name,
    regionKey: def.continentKey,
    latitude: def.latitude,
    longitude: def.longitude,
    mapX: def.mapX,
    mapY: def.mapY,
  );
}

MediaItem _track({
  required String id,
  required String title,
  required String artist,
}) {
  return MediaItem(
    id: id,
    publicId: id,
    title: title,
    subtitle: artist,
    source: MediaSource.local,
    origin: SourceOrigin.device,
    variants: [
      MediaVariant(
        kind: MediaVariantKind.audio,
        format: 'mp3',
        fileName: '$id.mp3',
        localPath: '/tmp/$id.mp3',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    ],
  );
}
