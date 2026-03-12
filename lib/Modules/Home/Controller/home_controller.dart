import 'dart:math';
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
import '../domain/recommendation_models.dart';
import '../service/local_recommendation_service.dart';

enum HomeMode { audio, video }

class RecommendationCollection {
  const RecommendationCollection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<MediaItem> items;
}

class HomeController extends GetxController {
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final LocalRecommendationService _recommendationService =
      Get.find<LocalRecommendationService>();
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
  static const int _collectionMinItems = 15;
  static const int _collectionMaxCount = 4;
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
    if (!_recommendationService.canManualRefreshToday(
      mode: recommendationMode,
    )) {
      final hint =
          _recommendationService.nextRefreshHint(mode: recommendationMode) ??
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
      final set = await _recommendationService.refreshManually(
        mode: recommendationMode,
      );
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
      final set = await _recommendationService.getOrBuildForDay(
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

  _ItemLocaleSignal? _resolveItemLocaleSignal(MediaItem item) {
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
      return _ItemLocaleSignal(regionKey: regionKey, countryName: countryName);
    }

    final fallback = ArtistCreditParser.normalizeKey(item.displaySubtitle);
    final locale = _artistLocaleByKey[fallback];
    if (locale == null) return null;
    final countryName = (locale.countryName ?? '').trim();
    if (countryName.isEmpty) return null;
    final regionKey = (locale.regionKey ?? '').trim();
    if (regionKey.isEmpty) return null;
    return _ItemLocaleSignal(regionKey: regionKey, countryName: countryName);
  }

  String _regionMixLabel(String regionKey) {
    switch (regionKey.trim().toLowerCase()) {
      case 'latino':
        return 'latino';
      case 'asiatico':
        return 'asiatico';
      case 'anglo':
        return 'anglo';
      case 'europeo':
        return 'euro';
      case 'africano':
        return 'africano';
      case 'medio_oriente':
        return 'medio oriente';
      case 'oceania':
        return 'oceania';
      case 'global':
        return 'global';
      default:
        return regionKey;
    }
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
    final resolvedEntries = <_ResolvedRecommendation>[];

    for (final entry in set.entries) {
      final item =
          byPublicId[entry.publicId.trim()] ?? byId[entry.itemId.trim()];
      if (item == null) continue;
      final stableKey = _itemStableKey(item);
      if (seen.contains(stableKey)) continue;
      seen.add(stableKey);

      resolved.add(item);
      resolvedEntries.add(_ResolvedRecommendation(item: item, entry: entry));

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
    final collections = _buildRecommendationCollections(
      resolvedEntries,
      dateKey: set.dateKey,
      recommendationMode: set.mode,
      manualRefreshCount: set.manualRefreshCount,
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
    canRecommendationRefresh.value = _recommendationService
        .canManualRefreshToday(mode: recommendationMode);
    recommendationRefreshHint.value = _recommendationService.nextRefreshHint(
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

  List<RecommendationCollection> _buildRecommendationCollections(
    List<_ResolvedRecommendation> entries, {
    required String dateKey,
    required RecommendationMode recommendationMode,
    required int manualRefreshCount,
  }) {
    if (entries.isEmpty) return const <RecommendationCollection>[];

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final momentTemplate = _momentTemplate(now.hour);

    final templates = <_RecommendationCollectionTemplate>[
      _RecommendationCollectionTemplate(
        id: 'scene',
        title: 'Escena que te gusta',
        subtitle: 'Por género, región y artistas',
        matcher: (entry) {
          return entry.entry.reasonCode ==
                  RecommendationReasonCode.genreMatch ||
              entry.entry.reasonCode == RecommendationReasonCode.regionMatch ||
              entry.entry.reasonCode == RecommendationReasonCode.artistAffinity;
        },
      ),
      _RecommendationCollectionTemplate(
        id: momentTemplate.id,
        title: momentTemplate.title,
        subtitle: momentTemplate.subtitle,
        matcher: (entry) => _matchesMoment(entry.item, nowMs, now.hour),
      ),
      _RecommendationCollectionTemplate(
        id: 'rediscovery',
        title: 'Redescubiertas',
        subtitle: 'Lo que vale la pena retomar',
        matcher: (entry) => _isRediscovery(entry.item, nowMs),
      ),
      _RecommendationCollectionTemplate(
        id: 'discovery',
        title: 'Para descubrir',
        subtitle: 'Nuevas para rotar hoy',
        matcher: _isDiscoveryCandidate,
      ),
    ];

    final targetCollections = min(
      _collectionMaxCount,
      max(1, min(_collectionMaxCount, entries.length)),
    );
    final enoughForMinPerCollection =
        entries.length >= (targetCollections * _collectionMinItems);
    final perCollectionTarget = enoughForMinPerCollection
        ? max(_collectionMinItems, (entries.length / targetCollections).ceil())
        : max(1, (entries.length / targetCollections).ceil());
    final used = <String>{};
    final collections = <RecommendationCollection>[];

    if (_hasArtistLocaleMetadata) {
      final byRegion = <String, List<_ResolvedRecommendation>>{};
      for (final entry in entries) {
        final signal = _resolveItemLocaleSignal(entry.item);
        if (signal == null) continue;
        byRegion.putIfAbsent(
          signal.regionKey,
          () => <_ResolvedRecommendation>[],
        );
        byRegion[signal.regionKey]!.add(entry);
      }

      final orderedRegions = byRegion.entries.toList(growable: false)
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

      if (orderedRegions.isNotEmpty && collections.length < targetCollections) {
        final bucket = _pickRegionalBucket(
          orderedRegions,
          dateKey: dateKey,
          recommendationMode: recommendationMode,
          manualRefreshCount: manualRefreshCount,
        );
        final availableInBucket = bucket.value
            .where((entry) => !used.contains(_itemStableKey(entry.item)))
            .toList(growable: false);

        final picks = availableInBucket.take(perCollectionTarget).toList();
        if (picks.isNotEmpty) {
          for (final pick in picks) {
            used.add(_itemStableKey(pick.item));
          }

          final regionLabel = _regionMixLabel(bucket.key);
          collections.add(
            RecommendationCollection(
              id: 'regional-${bucket.key}-1',
              title: 'Mix regional $regionLabel',
              subtitle: 'Solo canciones de la region $regionLabel',
              items: picks.map((e) => e.item).toList(growable: false),
            ),
          );
        }
      }
    }

    List<_ResolvedRecommendation> available() => entries.where((entry) {
      return !used.contains(_itemStableKey(entry.item));
    }).toList();

    List<_ResolvedRecommendation> pickForTemplate(
      _RecommendationCollectionTemplate template,
    ) {
      final free = available();
      if (free.isEmpty) return const <_ResolvedRecommendation>[];
      final preferred = free.where(template.matcher).toList();

      final picks = <_ResolvedRecommendation>[];
      final pickedKeys = <String>{};

      for (final entry in preferred) {
        if (picks.length >= perCollectionTarget) break;
        picks.add(entry);
        pickedKeys.add(_itemStableKey(entry.item));
      }

      if (picks.length < perCollectionTarget) {
        for (final entry in free) {
          if (picks.length >= perCollectionTarget) break;
          if (pickedKeys.contains(_itemStableKey(entry.item))) continue;
          picks.add(entry);
          pickedKeys.add(_itemStableKey(entry.item));
        }
      }

      return picks;
    }

    for (final template in templates) {
      if (collections.length >= targetCollections) break;
      final picks = pickForTemplate(template);
      if (picks.isEmpty) continue;

      for (final pick in picks) {
        used.add(_itemStableKey(pick.item));
      }

      collections.add(
        RecommendationCollection(
          id: '${template.id}-${collections.length + 1}',
          title: template.title,
          subtitle: template.subtitle,
          items: picks.map((e) => e.item).toList(growable: false),
        ),
      );
    }

    while (collections.length < targetCollections && available().isNotEmpty) {
      final free = available();
      final chunk = free.take(perCollectionTarget).toList();
      for (final entry in chunk) {
        used.add(_itemStableKey(entry.item));
      }
      collections.add(
        RecommendationCollection(
          id: 'mix-${collections.length + 1}',
          title: 'Mix diario ${collections.length + 1}',
          subtitle: 'Selección variada de hoy',
          items: chunk.map((e) => e.item).toList(growable: false),
        ),
      );
    }

    if (collections.isEmpty) {
      final fallback = entries
          .take(perCollectionTarget)
          .map((e) => e.item)
          .toList(growable: false);
      collections.add(
        RecommendationCollection(
          id: 'mix-1',
          title: 'Mix diario',
          subtitle: 'Selección recomendada',
          items: fallback,
        ),
      );
    }

    return collections.take(_collectionMaxCount).toList(growable: false);
  }

  MapEntry<String, List<_ResolvedRecommendation>> _pickRegionalBucket(
    List<MapEntry<String, List<_ResolvedRecommendation>>> orderedRegions, {
    required String dateKey,
    required RecommendationMode recommendationMode,
    required int manualRefreshCount,
  }) {
    if (orderedRegions.length <= 1) return orderedRegions.first;

    final rotationWindow = min(orderedRegions.length, 3);
    final dayOrdinal = _dayOrdinalFromDateKey(dateKey);
    final modeOffset = recommendationMode == RecommendationMode.audio ? 0 : 1;
    final offset = dayOrdinal + modeOffset + manualRefreshCount;
    final index = offset % rotationWindow;
    return orderedRegions[index];
  }

  int _dayOrdinalFromDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null && month != null && day != null) {
        final date = DateTime(year, month, day);
        return date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
      }
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  _MomentTemplate _momentTemplate(int hour) {
    if (hour >= 22 || hour < 6) {
      return const _MomentTemplate(
        id: 'night',
        title: 'Mix nocturno',
        subtitle: 'Retención alta para esta hora',
      );
    }
    if (hour >= 6 && hour < 12) {
      return const _MomentTemplate(
        id: 'morning',
        title: 'Mix para arrancar',
        subtitle: 'Recientes con buena respuesta',
      );
    }
    if (hour >= 12 && hour < 18) {
      return const _MomentTemplate(
        id: 'afternoon',
        title: 'Mix en movimiento',
        subtitle: 'Lo más activo de tu biblioteca',
      );
    }
    return const _MomentTemplate(
      id: 'evening',
      title: 'Mix de tarde',
      subtitle: 'Favoritas y buen avance',
    );
  }

  bool _matchesMoment(MediaItem item, int nowMs, int hour) {
    final retention = _retentionSignal(item);
    final recentSignal = _recentSignal(item, nowMs);
    final playSignal = (item.playCount / 30).clamp(0.0, 1.0);
    final favoriteSignal = item.isFavorite ? 1.0 : 0.0;

    if (hour >= 22 || hour < 6) {
      return retention >= 0.58 && _skipRate(item) <= 0.6;
    }
    if (hour >= 6 && hour < 12) {
      return recentSignal >= 0.45 || (playSignal >= 0.2 && retention >= 0.45);
    }
    if (hour >= 12 && hour < 18) {
      return playSignal >= 0.35 || recentSignal >= 0.55;
    }
    return favoriteSignal >= 0.9 || (retention >= 0.52 && recentSignal >= 0.3);
  }

  bool _isRediscovery(MediaItem item, int nowMs) {
    final hasHistory = item.playCount > 0 || item.fullListenCount > 0;
    if (!hasHistory) return false;
    final ts = item.lastPlayedAt ?? 0;
    if (ts <= 0) return true;
    final ageDays = (nowMs - ts) / const Duration(days: 1).inMilliseconds;
    return ageDays >= 21;
  }

  bool _isDiscoveryCandidate(_ResolvedRecommendation entry) {
    final item = entry.item;
    final reason = entry.entry.reasonCode;
    final lowHistory = (item.playCount + item.fullListenCount) <= 2;
    final lowSkip = _skipRate(item) <= 0.7;
    final freshReason =
        reason == RecommendationReasonCode.freshPick ||
        reason == RecommendationReasonCode.coldStart;
    return freshReason || (lowHistory && lowSkip && !item.isFavorite);
  }

  double _recentSignal(MediaItem item, int nowMs) {
    final ts = item.lastPlayedAt ?? 0;
    if (ts <= 0) return 0;
    final ageHours = max(
      0,
      ((nowMs - ts) / const Duration(hours: 1).inMilliseconds).round(),
    );
    if (ageHours <= 24) return 1;
    if (ageHours <= 24 * 3) return 0.85;
    if (ageHours <= 24 * 7) return 0.65;
    if (ageHours <= 24 * 14) return 0.45;
    return 0.2;
  }

  double _skipRate(MediaItem item) {
    final denominator = item.fullListenCount + item.skipCount;
    if (denominator <= 0) return 0;
    return (item.skipCount / denominator).clamp(0.0, 1.0).toDouble();
  }

  double _retentionSignal(MediaItem item) {
    final progress = item.avgListenProgress.clamp(0.0, 1.0).toDouble();
    final completionRate = item.fullListenCount + item.skipCount <= 0
        ? progress
        : (item.fullListenCount / (item.fullListenCount + item.skipCount))
              .clamp(0.0, 1.0)
              .toDouble();
    return ((completionRate * 0.6) + (progress * 0.4)) *
        (1 - (_skipRate(item) * 0.55));
  }
}

class _ResolvedRecommendation {
  const _ResolvedRecommendation({required this.item, required this.entry});

  final MediaItem item;
  final RecommendationEntry entry;
}

class _RecommendationCollectionTemplate {
  _RecommendationCollectionTemplate({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.matcher,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool Function(_ResolvedRecommendation entry) matcher;
}

class _MomentTemplate {
  const _MomentTemplate({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}

class _ArtistLocaleEntry {
  const _ArtistLocaleEntry({this.countryName, this.regionKey});

  final String? countryName;
  final String? regionKey;
}

class _ItemLocaleSignal {
  const _ItemLocaleSignal({required this.regionKey, this.countryName});

  final String regionKey;
  final String? countryName;
}
