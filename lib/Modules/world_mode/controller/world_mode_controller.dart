import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import '../domain/entities/country_entity.dart';
import '../domain/entities/country_station_entity.dart';
import '../domain/entities/world_explore_options.dart';
import '../domain/repositories/world_mode_repository.dart';
import '../services/world_mode_playback_facade.dart';

enum WorldViewMode { map, globe }

class WorldModeController extends GetxController {
  WorldModeController({
    required WorldModeRepository repository,
    required WorldModePlaybackFacade playbackFacade,
  }) : _repository = repository,
       _playbackFacade = playbackFacade;

  final WorldModeRepository _repository;
  final WorldModePlaybackFacade _playbackFacade;
  final math.Random _rng = math.Random();

  final RxBool isLoadingCountries = false.obs;
  final RxBool isLoadingStations = false.obs;
  final RxBool preferOnline = true.obs;
  final RxBool isMapExpanded = false.obs;
  final Rx<WorldViewMode> worldViewMode = WorldViewMode.globe.obs;
  final RxString errorMessage = ''.obs;
  final RxString searchQuery = ''.obs;

  final RxList<CountryEntity> countries = <CountryEntity>[].obs;
  final RxList<CountryEntity> filteredCountries = <CountryEntity>[].obs;
  final Rxn<CountryEntity> selectedCountry = Rxn<CountryEntity>();
  final RxList<CountryStationEntity> stations = <CountryStationEntity>[].obs;

  /// Seed aleatorio que cambia en cada selectCountry / refreshStations.
  /// Garantiza que el orden de canciones sea distinto en cada petición.
  int _shuffleSeed = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

  @override
  void onInit() {
    super.onInit();
    loadCountries();
  }

  Future<void> loadCountries() async {
    isLoadingCountries.value = true;
    errorMessage.value = '';
    try {
      final result = await _repository.getCountries();
      countries.assignAll(result);
      _applyFilter();
      if (selectedCountry.value == null && result.isNotEmpty) {
        await selectCountry(result.first, forceRefresh: false);
      }
    } catch (e) {
      errorMessage.value = tr('world_mode.load_regions_error');
    } finally {
      isLoadingCountries.value = false;
    }
  }

  void setSearchQuery(String value) {
    searchQuery.value = value;
    _applyFilter();
  }

  void toggleOnlinePreference(bool value) {
    preferOnline.value = value;
  }

  void setMapExpanded(bool value) {
    isMapExpanded.value = value;
  }

  void setWorldViewMode(WorldViewMode mode) {
    worldViewMode.value = mode;
  }

  Future<void> selectCountry(
    CountryEntity country, {
    bool forceRefresh = false,
  }) async {
    selectedCountry.value = country;
    _shuffleSeed = _rng.nextInt(0x7FFFFFFF);
    await _loadStations(country, forceRefresh: forceRefresh);
  }

  Future<void> refreshStations() async {
    final country = selectedCountry.value;
    if (country == null) return;
    // Genera un seed nuevo → orden completamente diferente cada vez
    _shuffleSeed = _rng.nextInt(0x7FFFFFFF);
    await _loadStations(country, forceRefresh: true);
  }

  Future<void> playStation(CountryStationEntity station) async {
    if (!station.hasPlayableTracks) {
      Get.snackbar(
        tr('world_mode.title'),
        tr('world_mode.no_playable_tracks'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    await _playbackFacade.playStation(station, startIndex: 0);
    final playable = station.tracks.where((item) => item.hasAudioLocal);
    if (playable.isEmpty) return;
    final first = playable.first;
    await _repository.registerPlayback(
      station: station,
      item: first,
      positionMs: 0,
    );
  }

  Future<void> playTrack(CountryStationEntity station, MediaItem item) async {
    final queue = station.tracks.where((track) => track.hasAudioLocal).toList();
    final index = queue.indexWhere((track) => track.id == item.id);
    if (queue.isEmpty || index < 0) return;
    await _playbackFacade.playQueue(queue, startIndex: index);
    await _repository.registerPlayback(
      station: station,
      item: item,
      positionMs: 0,
    );
  }

  Future<void> continueStation(CountryStationEntity station) async {
    final resumed = await _playbackFacade.resumeActiveStation(station);
    if (resumed) return;

    final next = await _repository.continueStation(station: station, limit: 20);
    if (next.isEmpty) {
      Get.snackbar(
        tr('world_mode.title'),
        tr('world_mode.no_more_songs'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    await _playbackFacade.playQueue(next, startIndex: 0);
  }

  Future<void> _loadStations(
    CountryEntity country, {
    required bool forceRefresh,
  }) async {
    isLoadingStations.value = true;
    errorMessage.value = '';
    try {
      final result = await _repository.exploreCountry(
        country: country,
        options: WorldExploreOptions(
          preferOnline: preferOnline.value,
          forceRefresh: forceRefresh,
          shuffleSeed: _shuffleSeed,
        ),
      );
      stations.assignAll(result);
    } catch (_) {
      errorMessage.value = tr('world_mode.generation_error');
    } finally {
      isLoadingStations.value = false;
    }
  }

  void _applyFilter() {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) {
      filteredCountries.assignAll(countries);
      return;
    }
    filteredCountries.assignAll(
      countries.where((country) {
        final code = country.code.toLowerCase();
        final name = country.localizedName.toLowerCase();
        return code.contains(query) || name.contains(query);
      }),
    );
  }
}
