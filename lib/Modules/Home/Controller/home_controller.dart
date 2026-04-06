import 'dart:io';

import 'package:get/get.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../../../app/utils/country_catalog.dart';
import '../../artists/data/artist_store.dart';
import '../../artists/domain/artist_profile.dart';
import '../../recommendations/domain/recommendation_collection.dart';
import '../../recommendations/domain/recommendation_models.dart';
import '../../recommendations/application/usecases/build_recommendation_collections_use_case.dart';
import '../../recommendations/application/usecases/get_or_build_daily_recommendations_use_case.dart';
import '../../recommendations/application/usecases/refresh_daily_recommendations_use_case.dart';
import '../../recommendations/application/usecases/recommendation_refresh_policy_use_case.dart';
import '../../recommendations/application/recommendation_feedback_service.dart';

enum HomeMode { audio, video }

class HomeController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final BuildRecommendationCollectionsUseCase _buildCollections =
      Get.find<BuildRecommendationCollectionsUseCase>();
  final GetOrBuildDailyRecommendationsUseCase _getRecommendationsForDay =
      Get.find<GetOrBuildDailyRecommendationsUseCase>();
  final RefreshDailyRecommendationsUseCase _refreshRecommendations =
      Get.find<RefreshDailyRecommendationsUseCase>();
  final RecommendationRefreshPolicyUseCase _refreshPolicy =
      Get.find<RecommendationRefreshPolicyUseCase>();
  final RecommendationFeedbackService? _feedbackService =
      Get.isRegistered<RecommendationFeedbackService>()
      ? Get.find<RecommendationFeedbackService>()
      : null;
  final ArtistStore? _artistStore = Get.isRegistered<ArtistStore>()
      ? Get.find<ArtistStore>()
      : null;

  final Rx<HomeMode> mode = HomeMode.audio.obs;
  final RxBool isLoading = false.obs;

  final RxList<MediaItem> recentlyPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> latestDownloads = <MediaItem>[].obs;
  final RxList<MediaItem> favorites = <MediaItem>[].obs;
  final RxList<MediaItem> mostPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> featured = <MediaItem>[].obs;
  final RxList<MediaItem> fullRecentlyPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> fullFavorites = <MediaItem>[].obs;
  final RxList<MediaItem> fullMostPlayed = <MediaItem>[].obs;
  final RxList<MediaItem> fullLatestDownloads = <MediaItem>[].obs;
  final RxList<MediaItem> fullFeatured = <MediaItem>[].obs;
  final RxList<MediaItem> recommended = <MediaItem>[].obs;
  final RxList<MediaItem> fullRecommended = <MediaItem>[].obs;
  final RxBool isRecommendationsLoading = false.obs;
  final RxBool canRecommendationRefresh = true.obs;
  final RxnString recommendationRefreshHint = RxnString();
  final RxMap<String, String> recommendationReasonsById =
      <String, String>{}.obs;
  final RxList<RecommendationCollection> recommendationCollections =
      <RecommendationCollection>[].obs;

  final RxList<MediaItem> _allItems = <MediaItem>[].obs;
  static const int _recommendedPreviewLimit = 12;
  static const int _recommendedFullLimit = 80;
  bool _hasArtistLocaleMetadata = false;
  Map<String, _ArtistLocaleEntry> _artistLocaleByKey =
      const <String, _ArtistLocaleEntry>{};

  @override
  void onInit() {
    super.onInit();
    loadHome();
  }

  Future<void> loadHome() async {
    isLoading.value = true;
    try {
      final items = await _repo.getLibrary();
      _allItems.assignAll(items);
      _splitHomeSections(_allItems);
      if (mode.value == HomeMode.audio) {
        await _loadRecommendationsForCurrentMode();
      } else {
        _clearRecommendations();
        _syncRecommendationRefreshAvailability();
      }
    } catch (e) {
      print('Error loading home: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _splitHomeSections(List<MediaItem> items) {
    final isAudioMode = mode.value == HomeMode.audio;

    bool matchesMode(MediaItem item) =>
        isAudioMode ? item.hasAudioLocal : item.hasVideoLocal;

    final filtered = items.where(matchesMode).toList();

    final recentAll = filtered.where((e) => (e.lastPlayedAt ?? 0) > 0).toList()
      ..sort((a, b) => (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0));
    fullRecentlyPlayed.assignAll(recentAll);
    recentlyPlayed.assignAll(recentAll.take(10));

    final downloadsAll = filtered.where((e) => e.isOfflineStored).toList()
      ..sort(
        (a, b) =>
            _latestVariantCreatedAt(b).compareTo(_latestVariantCreatedAt(a)),
      );
    fullLatestDownloads.assignAll(downloadsAll);
    latestDownloads.assignAll(downloadsAll.take(10));

    final favoritesAll = filtered.where((e) => e.isFavorite).toList();
    fullFavorites.assignAll(favoritesAll);
    favorites.assignAll(favoritesAll.take(10));

    final mostAll = filtered.where((e) => e.playCount > 0).toList()
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    fullMostPlayed.assignAll(mostAll);
    mostPlayed.assignAll(mostAll.take(12));

    fullFeatured.assignAll(
      _buildFeatured(
        favorites: favoritesAll,
        mostPlayed: mostAll,
        recent: recentAll,
        maxItems: filtered.length,
      ),
    );

    featured.assignAll(
      _buildFeatured(
        favorites: favoritesAll,
        mostPlayed: mostAll,
        recent: recentAll,
        maxItems: 12,
      ),
    );
  }

  List<MediaItem> _buildFeatured({
    required List<MediaItem> favorites,
    required List<MediaItem> mostPlayed,
    required List<MediaItem> recent,
    int maxItems = 12,
  }) {
    final result = <MediaItem>[];
    final seen = <String>{};

    void addItems(List<MediaItem> items, int limit) {
      var added = 0;
      for (final item in items) {
        if (added >= limit || result.length >= maxItems) return;
        final key = item.publicId.trim().isNotEmpty
            ? item.publicId.trim()
            : item.id.trim();
        if (seen.contains(key)) continue;
        result.add(item);
        seen.add(key);
        added++;
      }
    }

    final favLimit = (maxItems * 0.4).round();
    final mostLimit = (maxItems * 0.3).round();
    final recentLimit = maxItems - favLimit - mostLimit;

    addItems(favorites, favLimit);
    addItems(mostPlayed, mostLimit);
    addItems(recent, recentLimit);

    if (result.length < maxItems) {
      addItems(favorites, maxItems - result.length);
    }
    if (result.length < maxItems) {
      addItems(mostPlayed, maxItems - result.length);
    }
    if (result.length < maxItems) {
      addItems(recent, maxItems - result.length);
    }

    return result;
  }

  int _latestVariantCreatedAt(MediaItem item) {
    var maxTs = 0;
    for (final v in item.variants) {
      if (v.localPath?.trim().isNotEmpty != true) continue;
      if (v.createdAt > maxTs) maxTs = v.createdAt;
    }
    return maxTs;
  }

  void toggleMode() {
    mode.value = mode.value == HomeMode.audio ? HomeMode.video : HomeMode.audio;
    _splitHomeSections(_allItems);
    if (mode.value == HomeMode.audio) {
      _loadRecommendationsForCurrentMode();
    } else {
      _clearRecommendations();
      _syncRecommendationRefreshAvailability();
    }
  }

  Future<void> refreshRecommendations() async {
    if (mode.value == HomeMode.video) {
      _clearRecommendations();
      _syncRecommendationRefreshAvailability();
      return;
    }

    final recommendationMode = _currentRecommendationMode();
    if (!_refreshPolicy.canRefresh(mode: recommendationMode)) {
      final hint =
          _refreshPolicy.nextHint(mode: recommendationMode) ??
          'Ya usaste el refresh manual de hoy';
      recommendationRefreshHint.value = hint;
      canRecommendationRefresh.value = false;
      Get.snackbar('Para ti hoy', hint, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isRecommendationsLoading.value = true;
    try {
      _artistLocaleByKey = await _loadArtistLocaleMap();
      _hasArtistLocaleMetadata = _artistLocaleByKey.isNotEmpty;
      final set = await _refreshRecommendations.call(mode: recommendationMode);
      _applyRecommendationSet(set);
    } catch (e) {
      print('Error refreshing recommendations: $e');
      Get.snackbar(
        'Para ti hoy',
        'No se pudieron actualizar las recomendaciones',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _syncRecommendationRefreshAvailability();
      isRecommendationsLoading.value = false;
    }
  }

  String? recommendationHintFor(MediaItem item, int index) {
    final byId = recommendationReasonsById[item.id];
    if (byId != null && byId.trim().isNotEmpty) return byId;
    final publicId = item.publicId.trim();
    if (publicId.isNotEmpty) {
      final byPublic = recommendationReasonsById['p:$publicId'];
      if (byPublic != null && byPublic.trim().isNotEmpty) return byPublic;
    }
    return 'Por tu actividad reciente';
  }

  Future<void> markRecommendationInterested(MediaItem item) async {
    final service = _feedbackService;
    if (service == null) return;
    await service.markTrackInterested(_itemStableKey(item));
    await _loadRecommendationsForCurrentMode();
  }

  Future<void> hideRecommendationTrack(MediaItem item) async {
    final service = _feedbackService;
    if (service == null) return;
    await service.hideTrack(_itemStableKey(item));
    await _loadRecommendationsForCurrentMode();
  }

  Future<void> hideRecommendationArtist(MediaItem item) async {
    final service = _feedbackService;
    if (service == null) return;
    final parsed = ArtistCreditParser.parse(item.displaySubtitle);
    final artistName = ArtistCreditParser.cleanName(parsed.primaryArtist);
    final artistKey = ArtistCreditParser.normalizeKey(artistName);
    if (artistKey.isEmpty || artistKey == 'unknown') return;
    await service.hideArtist(artistKey);
    await _loadRecommendationsForCurrentMode();
  }

  void onSearch() {
    Get.toNamed(AppRoutes.homeSearch);
  }

  Future<void> openMedia(
    MediaItem item,
    int index,
    List<MediaItem> list,
  ) async {
    final route = mode.value == HomeMode.audio
        ? AppRoutes.audioPlayer
        : AppRoutes.videoPlayer;

    await Get.toNamed(route, arguments: {'queue': list, 'index': index});
    await loadHome();
  }

  Future<void> deleteLocalItem(MediaItem item) async {
    try {
      print(
        'Home delete requested id=${item.id} variants=${item.variants.length}',
      );

      _allItems.removeWhere((e) => e.id == item.id);
      recentlyPlayed.removeWhere((e) => e.id == item.id);
      latestDownloads.removeWhere((e) => e.id == item.id);
      favorites.removeWhere((e) => e.id == item.id);

      final all = await _store.readAll();
      final related = all.where((e) {
        if (e.id == item.id) return true;
        final pid = item.publicId.trim();
        return pid.isNotEmpty && e.publicId.trim() == pid;
      }).toList();

      if (related.isEmpty) {
        await _deleteItemFiles(item);
        await _store.remove(item.id);
      } else {
        for (final entry in related) {
          await _deleteItemFiles(entry);
          await _store.remove(entry.id);
        }
      }

      await loadHome();
    } catch (e) {
      print('Error deleting local item: $e');
      Get.snackbar(
        'Downloads',
        'Error al eliminar',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> toggleFavorite(MediaItem item) async {
    try {
      final next = !item.isFavorite;
      final all = await _store.readAll();
      final pid = item.publicId.trim();

      final matches = all.where((e) {
        if (e.id == item.id) return true;
        return pid.isNotEmpty && e.publicId.trim() == pid;
      }).toList();

      if (matches.isEmpty) {
        await _store.upsert(item.copyWith(isFavorite: next));
      } else {
        for (final entry in matches) {
          await _store.upsert(entry.copyWith(isFavorite: next));
        }
      }

      await loadHome();
    } catch (e) {
      print('Error toggling favorite: $e');
      Get.snackbar(
        'Favoritos',
        'No se pudo actualizar',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _deleteItemFiles(MediaItem item) async {
    for (final v in item.variants) {
      await _deleteFile(v.localPath);
    }
    await _deleteFile(item.thumbnailLocalPath);
  }

  Future<void> _deleteFile(String? path) async {
    final pth = path?.trim();
    if (pth == null || pth.isEmpty) return;
    final f = File(pth);
    if (await f.exists()) await f.delete();
  }

  void goToPlaylists() => Get.toNamed(AppRoutes.playlists);
  void goToArtists() => Get.toNamed(AppRoutes.artists);
  void goToDownloads() => Get.toNamed(AppRoutes.downloads);

  void goToSources() async {
    await Get.toNamed(AppRoutes.sources);
    loadHome();
  }

  void goToSettings() => Get.toNamed(AppRoutes.settings);

  void enterHome() => Get.offAllNamed(AppRoutes.home);

  List<MediaItem> get allItems => List<MediaItem>.from(_allItems);

  Future<void> _loadRecommendationsForCurrentMode() async {
    if (mode.value == HomeMode.video) {
      _clearRecommendations();
      _syncRecommendationRefreshAvailability();
      return;
    }

    if (_allItems.isEmpty) {
      _clearRecommendations();
      _syncRecommendationRefreshAvailability();
      return;
    }

    isRecommendationsLoading.value = true;
    try {
      _artistLocaleByKey = await _loadArtistLocaleMap();
      _hasArtistLocaleMetadata = _artistLocaleByKey.isNotEmpty;
      final set = await _getRecommendationsForDay.call(
        mode: _currentRecommendationMode(),
      );
      _applyRecommendationSet(set);
    } catch (e) {
      print('Error loading recommendations: $e');
    } finally {
      _syncRecommendationRefreshAvailability();
      isRecommendationsLoading.value = false;
    }
  }

  Future<Map<String, _ArtistLocaleEntry>> _loadArtistLocaleMap() async {
    final store = _artistStore;
    if (store == null) return const <String, _ArtistLocaleEntry>{};

    List<ArtistProfile> profiles;
    try {
      profiles = await store.readAll();
    } catch (_) {
      return const <String, _ArtistLocaleEntry>{};
    }

    final out = <String, _ArtistLocaleEntry>{};
    for (final profile in profiles) {
      final key = ArtistCreditParser.normalizeKey(profile.key);
      if (key.isEmpty || key == 'unknown') continue;

      final countryName = (profile.country ?? '').trim().isNotEmpty
          ? profile.country!.trim()
          : CountryCatalog.countryNameFromCode(profile.countryCode);
      final regionKey = _resolveRegionKeyForProfile(profile, countryName);
      final hasLocale =
          (countryName ?? '').isNotEmpty && (regionKey ?? '').isNotEmpty;
      if (!hasLocale) continue;

      out[key] = _ArtistLocaleEntry(
        countryName: countryName?.trim().isEmpty == true ? null : countryName,
        regionKey: regionKey?.trim().isEmpty == true ? null : regionKey,
      );
    }
    return out;
  }

  String? _resolveRegionKeyForProfile(ArtistProfile profile, String? country) {
    if (profile.mainRegion != ArtistMainRegion.none) {
      return profile.mainRegion.key;
    }

    final byCode = CountryCatalog.regionKeyFromCode(profile.countryCode);
    if ((byCode ?? '').isNotEmpty) return byCode;

    final byName = CountryCatalog.findByName(country)?.regionKey;
    if ((byName ?? '').isNotEmpty) return byName;

    return null;
  }

  RecommendationLocaleSignal? _resolveItemLocaleSignal(MediaItem item) {
    if (_artistLocaleByKey.isEmpty) return null;

    final parsed = ArtistCreditParser.parse(item.displaySubtitle);
    for (final artistName in parsed.allArtists) {
      final key = ArtistCreditParser.normalizeKey(artistName);
      final locale = _artistLocaleByKey[key];
      if (locale == null) continue;
      final countryName = (locale.countryName ?? '').trim();
      if (countryName.isEmpty) continue;
      final regionKey = (locale.regionKey ?? '').trim();
      if (regionKey.isEmpty) continue;
      return RecommendationLocaleSignal(
        regionKey: regionKey,
        countryName: countryName,
      );
    }

    final fallback = ArtistCreditParser.normalizeKey(item.displaySubtitle);
    final locale = _artistLocaleByKey[fallback];
    if (locale == null) return null;
    final countryName = (locale.countryName ?? '').trim();
    if (countryName.isEmpty) return null;
    final regionKey = (locale.regionKey ?? '').trim();
    if (regionKey.isEmpty) return null;
    return RecommendationLocaleSignal(
      regionKey: regionKey,
      countryName: countryName,
    );
  }

  String? _regionalReasonForItem(MediaItem item) {
    final signal = _resolveItemLocaleSignal(item);
    if (signal == null) return null;
    final country = (signal.countryName ?? '').trim();
    if (country.isEmpty) return null;
    return 'Porque escuchaste musica de $country';
  }

  void _applyRecommendationSet(RecommendationDailySet set) {
    final isAudioMode = mode.value == HomeMode.audio;
    bool matchesMode(MediaItem item) =>
        isAudioMode ? item.hasAudioLocal : item.hasVideoLocal;

    final filtered = _allItems.where(matchesMode).toList();
    final byPublicId = <String, MediaItem>{};
    final byId = <String, MediaItem>{};
    for (final item in filtered) {
      final pid = item.publicId.trim();
      final id = item.id.trim();
      if (pid.isNotEmpty) {
        byPublicId.putIfAbsent(pid, () => item);
      }
      if (id.isNotEmpty) {
        byId.putIfAbsent(id, () => item);
      }
    }

    final seen = <String>{};
    final resolved = <MediaItem>[];
    final reasons = <String, String>{};
    final resolvedEntries = <RecommendationCollectionSeed>[];

    for (final entry in set.entries) {
      final item =
          byPublicId[entry.publicId.trim()] ?? byId[entry.itemId.trim()];
      if (item == null) continue;
      final stableKey = _itemStableKey(item);
      if (seen.contains(stableKey)) continue;
      seen.add(stableKey);

      resolved.add(item);
      resolvedEntries.add(
        RecommendationCollectionSeed(item: item, entry: entry),
      );

      final reason = entry.reasonText.trim().isEmpty
          ? 'Por tu actividad reciente'
          : entry.reasonText.trim();
      reasons[item.id] = reason;
      final pid = item.publicId.trim();
      if (pid.isNotEmpty) {
        reasons['p:$pid'] = reason;
      }

      if (resolved.length >= _recommendedFullLimit) break;
    }

    fullRecommended.assignAll(resolved.take(_recommendedFullLimit));
    recommended.assignAll(resolved.take(_recommendedPreviewLimit));
    final collections = _buildCollections.call(
      BuildRecommendationCollectionsInput(
        entries: resolvedEntries,
        dateKey: set.dateKey,
        recommendationMode: set.mode,
        manualRefreshCount: set.manualRefreshCount,
        hasArtistLocaleMetadata: _hasArtistLocaleMetadata,
        resolveLocaleSignal: _resolveItemLocaleSignal,
        stableKeyOf: _itemStableKey,
      ),
    );
    for (final collection in collections) {
      if (!collection.id.startsWith('regional-')) continue;
      for (final item in collection.items) {
        final reason = _regionalReasonForItem(item);
        if ((reason ?? '').trim().isEmpty) continue;
        reasons[item.id] = reason!;
        final pid = item.publicId.trim();
        if (pid.isNotEmpty) {
          reasons['p:$pid'] = reason;
        }
      }
    }
    recommendationReasonsById.assignAll(reasons);
    recommendationCollections.assignAll(collections);
  }

  void _syncRecommendationRefreshAvailability() {
    if (mode.value == HomeMode.video) {
      canRecommendationRefresh.value = false;
      recommendationRefreshHint.value = null;
      return;
    }

    final recommendationMode = _currentRecommendationMode();
    canRecommendationRefresh.value = _refreshPolicy.canRefresh(
      mode: recommendationMode,
    );
    recommendationRefreshHint.value = _refreshPolicy.nextHint(
      mode: recommendationMode,
    );
  }

  void _clearRecommendations() {
    recommended.clear();
    fullRecommended.clear();
    recommendationReasonsById.clear();
    recommendationCollections.clear();
  }

  RecommendationMode _currentRecommendationMode() {
    return mode.value == HomeMode.audio
        ? RecommendationMode.audio
        : RecommendationMode.video;
  }

  String _itemStableKey(MediaItem item) {
    final publicId = item.publicId.trim();
    if (publicId.isNotEmpty) return 'p:$publicId';
    return 'i:${item.id.trim()}';
  }
}

class _ArtistLocaleEntry {
  const _ArtistLocaleEntry({this.countryName, this.regionKey});

  final String? countryName;
  final String? regionKey;
}
