import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

export '../domain/home_layout_models.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/services/local_media_metadata_service.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../../../app/utils/country_catalog.dart';
import '../../player/Video/controller/video_player_controller.dart';
import '../../artists/data/artist_store.dart';
import '../../artists/domain/artist_profile.dart';
import '../../playlists/data/playlist_store.dart';
import '../../playlists/domain/playlist.dart';
import '../../recommendations/domain/recommendation_collection.dart';
import '../../recommendations/domain/recommendation_models.dart';
import '../../recommendations/application/usecases/build_recommendation_collections_use_case.dart';
import '../../recommendations/application/usecases/get_or_build_daily_recommendations_use_case.dart';
import '../../recommendations/application/recommendation_feedback_service.dart';
import '../../sources/data/source_theme_topic_store.dart';
import '../../sources/data/source_theme_topic_playlist_store.dart';
import '../../sources/domain/source_theme_topic.dart';
import '../../sources/domain/source_theme_topic_playlist.dart';
import '../domain/home_layout_models.dart';

class HomeController extends GetxController {
  final GetStorage _layoutStorage = GetStorage();
  final MediaRepository _repo = Get.find<MediaRepository>();
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();
  final LocalMediaMetadataService _metadata =
      Get.find<LocalMediaMetadataService>();
  final BuildRecommendationCollectionsUseCase _buildCollections =
      Get.find<BuildRecommendationCollectionsUseCase>();
  final GetOrBuildDailyRecommendationsUseCase _getRecommendationsForDay =
      Get.find<GetOrBuildDailyRecommendationsUseCase>();
  final RecommendationFeedbackService? _feedbackService =
      Get.isRegistered<RecommendationFeedbackService>()
      ? Get.find<RecommendationFeedbackService>()
      : null;
  final ArtistStore? _artistStore = Get.isRegistered<ArtistStore>()
      ? Get.find<ArtistStore>()
      : null;
  final PlaylistStore? _playlistStore = Get.isRegistered<PlaylistStore>()
      ? Get.find<PlaylistStore>()
      : null;
  final SourceThemeTopicPlaylistStore? _topicPlaylistStore =
      Get.isRegistered<SourceThemeTopicPlaylistStore>()
      ? Get.find<SourceThemeTopicPlaylistStore>()
      : null;
  final SourceThemeTopicStore? _topicStore =
      Get.isRegistered<SourceThemeTopicStore>()
      ? Get.find<SourceThemeTopicStore>()
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
  final RxMap<String, String> recommendationReasonsById =
      <String, String>{}.obs;
  final RxList<RecommendationCollection> recommendationCollections =
      <RecommendationCollection>[].obs;
  final RxBool isHomeEditing = false.obs;
  final RxList<HomeWidgetId> homeWidgetOrder = <HomeWidgetId>[].obs;
  final RxList<HomeWidgetId> enabledHomeWidgets = <HomeWidgetId>[].obs;
  final RxList<HomeWidgetId> videoHomeWidgetOrder = <HomeWidgetId>[].obs;
  final RxList<HomeWidgetId> enabledVideoHomeWidgets = <HomeWidgetId>[].obs;
  final RxMap<String, HomeCustomSectionLayout> homeWidgetLayouts =
      <String, HomeCustomSectionLayout>{}.obs;
  final RxMap<String, HomeMediaSort> homeWidgetSorts =
      <String, HomeMediaSort>{}.obs;
  final RxMap<String, bool> homeWidgetSortAscending = <String, bool>{}.obs;
  final RxList<HomeCustomSection> customHomeSections =
      <HomeCustomSection>[].obs;
  final RxList<HomeCustomSection> videoCustomHomeSections =
      <HomeCustomSection>[].obs;

  final RxList<MediaItem> _allItems = <MediaItem>[].obs;
  final RxList<MediaItem> randomMix = <MediaItem>[].obs;
  static const _homeWidgetOrderKey = 'home_widget_order';
  static const _homeWidgetEnabledKey = 'home_widget_enabled';
  static const _homeWidgetLayoutsKey = 'home_widget_layouts';
  static const _homeWidgetSortsKey = 'home_widget_sorts';
  static const _homeWidgetSortAscendingKey = 'home_widget_sort_ascending';
  static const _homeCustomSectionsKey = 'home_custom_sections';
  static const _videoHomeWidgetOrderKey = 'video_home_widget_order';
  static const _videoHomeWidgetEnabledKey = 'video_home_widget_enabled';
  static const _videoHomeCustomSectionsKey = 'video_home_custom_sections';
  static const _defaultHomeWidgets = <HomeWidgetId>[
    HomeWidgetId.favorites,
    HomeWidgetId.recommendations,
    HomeWidgetId.mostPlayed,
    HomeWidgetId.recentlyPlayed,
    HomeWidgetId.featured,
    HomeWidgetId.latestDownloads,
    HomeWidgetId.notPlayed,
    HomeWidgetId.randomMix,
  ];
  static const _defaultVideoHomeWidgets = <HomeWidgetId>[
    HomeWidgetId.favorites,
    HomeWidgetId.continueWatching,
    HomeWidgetId.latestDownloads,
    HomeWidgetId.featured,
  ];
  static const int _recommendedPreviewLimit = 12;
  static const int _recommendedFullLimit = 80;
  Map<String, _ArtistLocaleEntry> _artistLocaleByKey =
      const <String, _ArtistLocaleEntry>{};
  Timer? _recommendationCycleTimer;

  @override
  void onInit() {
    super.onInit();
    _restoreHomeLayout();
    loadHome();
  }

  void _restoreHomeLayout() {
    final rawOrder = _layoutStorage.read<List>(_homeWidgetOrderKey);
    final parsedOrder = rawOrder
        ?.map((e) => HomeWidgetIdX.fromKey(e.toString()))
        .whereType<HomeWidgetId>()
        .toList(growable: false);
    final order = <HomeWidgetId>[
      ...(parsedOrder ?? const <HomeWidgetId>[]),
      ..._defaultHomeWidgets.where((id) => parsedOrder?.contains(id) != true),
    ];
    homeWidgetOrder.assignAll(order);

    final rawEnabled = _layoutStorage.read<List>(_homeWidgetEnabledKey);
    final parsedEnabled = rawEnabled
        ?.map((e) => HomeWidgetIdX.fromKey(e.toString()))
        .whereType<HomeWidgetId>()
        .toList(growable: false);
    enabledHomeWidgets.assignAll(parsedEnabled ?? _defaultHomeWidgets);

    final rawVideoOrder = _layoutStorage.read<List>(_videoHomeWidgetOrderKey);
    final parsedVideoOrder = rawVideoOrder
        ?.map((e) => HomeWidgetIdX.fromKey(e.toString()))
        .whereType<HomeWidgetId>()
        .where((id) => id.videoHomeSupported)
        .toList(growable: false);
    videoHomeWidgetOrder.assignAll(<HomeWidgetId>[
      ...(parsedVideoOrder ?? const <HomeWidgetId>[]),
      ..._defaultVideoHomeWidgets.where(
        (id) => parsedVideoOrder?.contains(id) != true,
      ),
    ]);

    final rawVideoEnabled = _layoutStorage.read<List>(
      _videoHomeWidgetEnabledKey,
    );
    final parsedVideoEnabled = rawVideoEnabled
        ?.map((e) => HomeWidgetIdX.fromKey(e.toString()))
        .whereType<HomeWidgetId>()
        .where((id) => id.videoHomeSupported)
        .toList(growable: false);
    enabledVideoHomeWidgets.assignAll(
      parsedVideoEnabled ?? _defaultVideoHomeWidgets,
    );

    final rawLayouts = _layoutStorage.read<Map>(_homeWidgetLayoutsKey);
    homeWidgetLayouts.value = <String, HomeCustomSectionLayout>{
      ...?rawLayouts?.map(
        (key, value) =>
            MapEntry(key.toString(), HomeCustomSectionLayoutX.fromRaw(value)),
      ),
    };

    final rawSorts = _layoutStorage.read<Map>(_homeWidgetSortsKey);
    homeWidgetSorts.value = <String, HomeMediaSort>{
      ...?rawSorts?.map((key, value) {
        final sort = HomeMediaSortX.fromKey(value.toString());
        return MapEntry(
          key.toString(),
          sort ?? defaultSortForHomeWidgetKey(key.toString()),
        );
      }),
    };

    final rawSortAscending = _layoutStorage.read<Map>(
      _homeWidgetSortAscendingKey,
    );
    homeWidgetSortAscending.value = <String, bool>{
      ...?rawSortAscending?.map(
        (key, value) => MapEntry(key.toString(), value == true),
      ),
    };

    final rawCustom = _layoutStorage.read<List>(_homeCustomSectionsKey);
    final parsedCustom =
        rawCustom
            ?.whereType<Map>()
            .map(
              (e) => HomeCustomSection.fromJson(Map<String, dynamic>.from(e)),
            )
            .where((e) => e.id.isNotEmpty && e.targetId.isNotEmpty)
            .toList(growable: false) ??
        const <HomeCustomSection>[];
    final normalizedCustom = _normalizeCustomHomeSections(parsedCustom);
    customHomeSections.assignAll(normalizedCustom);
    final rawVideoCustom = _layoutStorage.read<List>(
      _videoHomeCustomSectionsKey,
    );
    final parsedVideoCustom =
        rawVideoCustom
            ?.whereType<Map>()
            .map(
              (e) => HomeCustomSection.fromJson(Map<String, dynamic>.from(e)),
            )
            .where((e) => e.id.isNotEmpty && e.targetId.isNotEmpty)
            .toList(growable: false) ??
        const <HomeCustomSection>[];
    final normalizedVideoCustom = _normalizeVideoCustomHomeSections(
      parsedVideoCustom,
    );
    videoCustomHomeSections.assignAll(normalizedVideoCustom);
    if (!_sameCustomSections(parsedCustom, normalizedCustom) ||
        !_sameCustomSections(parsedVideoCustom, normalizedVideoCustom)) {
      _persistHomeLayout();
    }
  }

  List<HomeCustomSection> _normalizeCustomHomeSections(
    List<HomeCustomSection> sections,
  ) {
    const artistSectionId = 'artists_custom';
    const playlistSectionId = 'playlists_custom';
    final artistKeys = <String>{};
    final playlistIds = <String>{};
    HomeCustomSectionLayout artistLayout = HomeCustomSectionLayout.cards;
    HomeCustomSectionLayout playlistLayout = HomeCustomSectionLayout.cards;
    var foundArtist = false;
    var foundPlaylist = false;
    var insertedArtistSection = false;
    var insertedPlaylistSection = false;
    final normalized = <HomeCustomSection>[];

    for (final section in sections) {
      if (section.kind == HomeCustomSectionKind.artist) {
        if (!foundArtist) {
          artistLayout = section.layout;
        }
        foundArtist = true;
        artistKeys.addAll(
          section.targetId
              .split('|')
              .map(ArtistCreditParser.normalizeKey)
              .where((e) => e.isNotEmpty && e != 'unknown'),
        );

        if (!insertedArtistSection) {
          normalized.add(
            HomeCustomSection(
              id: artistSectionId,
              kind: HomeCustomSectionKind.artist,
              targetId: '',
              title: tr('home.custom.artists'),
              layout: artistLayout,
            ),
          );
          insertedArtistSection = true;
        }
        continue;
      }

      if (section.kind == HomeCustomSectionKind.playlist) {
        if (!foundPlaylist) {
          playlistLayout = section.layout;
        }
        foundPlaylist = true;
        playlistIds.addAll(
          section.targetId
              .split('|')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );

        if (!insertedPlaylistSection) {
          normalized.add(
            HomeCustomSection(
              id: playlistSectionId,
              kind: HomeCustomSectionKind.playlist,
              targetId: '',
              title: tr('home.custom.playlists'),
              layout: playlistLayout,
            ),
          );
          insertedPlaylistSection = true;
        }
        continue;
      }

      if (section.kind != HomeCustomSectionKind.artist) {
        normalized.add(section);
      }
    }

    return normalized
        .map((section) {
          if (section.id == artistSectionId) {
            if (!foundArtist || artistKeys.isEmpty) return null;
            return HomeCustomSection(
              id: artistSectionId,
              kind: HomeCustomSectionKind.artist,
              targetId: artistKeys.join('|'),
              title: tr('home.custom.artists'),
              layout: section.layout,
            );
          }
          if (section.id == playlistSectionId) {
            if (!foundPlaylist || playlistIds.isEmpty) return null;
            return HomeCustomSection(
              id: playlistSectionId,
              kind: HomeCustomSectionKind.playlist,
              targetId: playlistIds.join('|'),
              title: tr('home.custom.playlists'),
              layout: section.layout,
            );
          }
          return section;
        })
        .whereType<HomeCustomSection>()
        .where((section) => section.targetId.isNotEmpty)
        .toList(growable: false);
  }

  List<HomeCustomSection> _normalizeVideoCustomHomeSections(
    List<HomeCustomSection> sections,
  ) {
    const collectionSectionId = 'collections_custom';
    final collectionIds = <String>{};
    HomeCustomSectionLayout collectionLayout = HomeCustomSectionLayout.cards;
    var foundCollection = false;

    for (final section in sections) {
      if (section.kind != HomeCustomSectionKind.collection) continue;
      if (!foundCollection) {
        collectionLayout = section.layout;
      }
      foundCollection = true;
      collectionIds.addAll(
        section.targetId
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    if (!foundCollection || collectionIds.isEmpty) {
      return const <HomeCustomSection>[];
    }
    return <HomeCustomSection>[
      HomeCustomSection(
        id: collectionSectionId,
        kind: HomeCustomSectionKind.collection,
        targetId: collectionIds.join('|'),
        title: tr('home.custom.collections'),
        layout: collectionLayout,
      ),
    ];
  }

  bool _sameCustomSections(
    List<HomeCustomSection> a,
    List<HomeCustomSection> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.kind != right.kind ||
          left.targetId != right.targetId ||
          left.title != right.title ||
          left.layout != right.layout) {
        return false;
      }
    }
    return true;
  }

  List<HomeWidgetId> visibleHomeWidgetIdsForMode(HomeMode currentMode) {
    if (currentMode == HomeMode.video) {
      return videoHomeWidgetOrder
          .where((id) => id.videoHomeSupported)
          .where((id) => enabledVideoHomeWidgets.contains(id))
          .toList(growable: false);
    }
    return homeWidgetOrder
        .where((id) => !id.videoOnly)
        .where((id) => enabledHomeWidgets.contains(id))
        .toList(growable: false);
  }

  List<HomeWidgetId> editableHomeWidgetOrderForMode(HomeMode currentMode) {
    return currentMode == HomeMode.video
        ? videoHomeWidgetOrder.toList(growable: false)
        : homeWidgetOrder.where((id) => !id.videoOnly).toList(growable: false);
  }

  List<HomeWidgetId> enabledHomeWidgetIdsForMode(HomeMode currentMode) {
    return currentMode == HomeMode.video
        ? enabledVideoHomeWidgets.toList(growable: false)
        : enabledHomeWidgets
              .where((id) => !id.videoOnly)
              .toList(growable: false);
  }

  bool get usesDefaultHomeWidgetOrder {
    return false;
  }

  HomeCustomSectionLayout layoutForHomeWidget(HomeWidgetId id) {
    if (id.hasFixedLayout) return HomeCustomSectionLayout.cards;
    return homeWidgetLayouts[id.key] ?? HomeCustomSectionLayout.cards;
  }

  HomeCustomSectionLayout layoutForHomeWidgetInMode(
    HomeWidgetId id,
    HomeMode currentMode,
  ) {
    if (currentMode == HomeMode.video) return HomeCustomSectionLayout.cards;
    return layoutForHomeWidget(id);
  }

  HomeMediaSort defaultSortForHomeWidget(HomeWidgetId id) {
    return switch (id) {
      HomeWidgetId.latestDownloads => HomeMediaSort.importedAt,
      HomeWidgetId.mostPlayed => HomeMediaSort.plays,
      HomeWidgetId.recentlyPlayed => HomeMediaSort.recent,
      HomeWidgetId.continueWatching => HomeMediaSort.recent,
      HomeWidgetId.randomMix => HomeMediaSort.title,
      HomeWidgetId.favorites ||
      HomeWidgetId.recommendations ||
      HomeWidgetId.featured ||
      HomeWidgetId.notPlayed => HomeMediaSort.title,
    };
  }

  HomeMediaSort defaultSortForHomeWidgetKey(String key) {
    final id = HomeWidgetIdX.fromKey(key);
    return id == null ? HomeMediaSort.title : defaultSortForHomeWidget(id);
  }

  bool defaultSortAscendingForHomeWidget(HomeWidgetId id) {
    return switch (id) {
      HomeWidgetId.latestDownloads ||
      HomeWidgetId.mostPlayed ||
      HomeWidgetId.recentlyPlayed ||
      HomeWidgetId.continueWatching => false,
      _ => true,
    };
  }

  List<HomeMediaSort> sortOptionsForHomeWidget(HomeWidgetId id) {
    return switch (id) {
      HomeWidgetId.latestDownloads => const [HomeMediaSort.importedAt],
      HomeWidgetId.mostPlayed => const [HomeMediaSort.plays],
      HomeWidgetId.recentlyPlayed => const [HomeMediaSort.recent],
      HomeWidgetId.continueWatching => const [HomeMediaSort.recent],
      HomeWidgetId.randomMix => const <HomeMediaSort>[],
      HomeWidgetId.favorites ||
      HomeWidgetId.recommendations ||
      HomeWidgetId.featured => const [
        HomeMediaSort.title,
        HomeMediaSort.artist,
        HomeMediaSort.importedAt,
        HomeMediaSort.size,
        HomeMediaSort.plays,
        HomeMediaSort.duration,
        HomeMediaSort.recent,
      ],
      HomeWidgetId.notPlayed => const [
        HomeMediaSort.title,
        HomeMediaSort.artist,
        HomeMediaSort.importedAt,
        HomeMediaSort.size,
        HomeMediaSort.duration,
      ],
    };
  }

  HomeMediaSort sortForHomeWidget(HomeWidgetId id) {
    final options = sortOptionsForHomeWidget(id);
    final selected = homeWidgetSorts[id.key] ?? defaultSortForHomeWidget(id);
    if (options.isEmpty || options.contains(selected)) return selected;
    return options.first;
  }

  bool sortAscendingForHomeWidget(HomeWidgetId id) {
    return homeWidgetSortAscending[id.key] ??
        defaultSortAscendingForHomeWidget(id);
  }

  void setHomeWidgetSort(HomeWidgetId id, HomeMediaSort sort) {
    if (!sortOptionsForHomeWidget(id).contains(sort)) return;
    homeWidgetSorts[id.key] = sort;
    _persistHomeLayout();
  }

  void setHomeWidgetSortAscending(HomeWidgetId id, bool ascending) {
    homeWidgetSortAscending[id.key] = ascending;
    _persistHomeLayout();
  }

  void toggleHomeWidgetLayout(HomeWidgetId id) {
    if (id.hasFixedLayout) return;
    final current = layoutForHomeWidget(id);
    homeWidgetLayouts[id.key] = current == HomeCustomSectionLayout.cards
        ? HomeCustomSectionLayout.list
        : HomeCustomSectionLayout.cards;
    _persistHomeLayout();
  }

  void toggleHomeEditing() {
    isHomeEditing.value = !isHomeEditing.value;
  }

  void toggleHomeWidget(HomeWidgetId id) {
    if (enabledHomeWidgets.contains(id)) {
      enabledHomeWidgets.remove(id);
    } else {
      enabledHomeWidgets.add(id);
    }
    _persistHomeLayout();
  }

  void moveHomeWidget(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= homeWidgetOrder.length) return;
    if (newIndex < 0 || newIndex > homeWidgetOrder.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final item = homeWidgetOrder.removeAt(oldIndex);
    homeWidgetOrder.insert(newIndex, item);
    _persistHomeLayout();
  }

  void moveHomeWidgetForMode(HomeMode currentMode, int oldIndex, int newIndex) {
    if (currentMode == HomeMode.video) {
      if (oldIndex < 0 || oldIndex >= videoHomeWidgetOrder.length) return;
      if (newIndex < 0 || newIndex > videoHomeWidgetOrder.length) return;
      if (newIndex > oldIndex) newIndex -= 1;
      final item = videoHomeWidgetOrder.removeAt(oldIndex);
      videoHomeWidgetOrder.insert(newIndex, item);
      _persistHomeLayout();
      return;
    }

    final modeItems = homeWidgetOrder
        .where((id) => !id.videoOnly)
        .toList(growable: true);
    if (oldIndex < 0 || oldIndex >= modeItems.length) return;
    if (newIndex < 0 || newIndex > modeItems.length) return;
    if (newIndex > oldIndex) newIndex -= 1;

    final moved = modeItems.removeAt(oldIndex);
    modeItems.insert(newIndex, moved);

    var modeIndex = 0;
    final nextOrder = <HomeWidgetId>[];
    for (final id in homeWidgetOrder) {
      final belongsToMode = currentMode == HomeMode.video
          ? id.videoHomeSupported
          : !id.videoOnly;
      if (!belongsToMode) {
        nextOrder.add(id);
      } else if (modeIndex < modeItems.length) {
        nextOrder.add(modeItems[modeIndex]);
        modeIndex++;
      }
    }

    homeWidgetOrder.assignAll(nextOrder);
    _persistHomeLayout();
  }

  void resetHomeLayout() {
    homeWidgetOrder.assignAll(_defaultHomeWidgets);
    enabledHomeWidgets.assignAll(_defaultHomeWidgets);
    homeWidgetLayouts.value = <String, HomeCustomSectionLayout>{};
    homeWidgetSorts.clear();
    homeWidgetSortAscending.clear();
    customHomeSections.clear();
    videoHomeWidgetOrder.assignAll(_defaultVideoHomeWidgets);
    enabledVideoHomeWidgets.assignAll(_defaultVideoHomeWidgets);
    videoCustomHomeSections.clear();
    _persistHomeLayout();
  }

  /// Vuelve a leer la configuraci\u00f3n de widgets desde GetStorage y la aplica
  /// a los observables reactivos. \u00datil tras restaurar un respaldo (backup),
  /// donde el storage fue actualizado pero el controller ya estaba en memoria.
  void reloadLayoutFromStorage() {
    _restoreHomeLayout();
  }

  void applyHomeLayoutSnapshot({
    HomeMode mode = HomeMode.audio,
    required List<HomeWidgetId> order,
    required List<HomeWidgetId> enabled,
    required Map<String, HomeCustomSectionLayout> layouts,
    required List<HomeCustomSection> customSections,
  }) {
    if (mode == HomeMode.video) {
      videoHomeWidgetOrder.assignAll(
        order.where((id) => id.videoHomeSupported),
      );
      enabledVideoHomeWidgets.assignAll(
        enabled.where((id) => id.videoHomeSupported),
      );
      videoCustomHomeSections.assignAll(
        _normalizeVideoCustomHomeSections(customSections),
      );
      isHomeEditing.value = false;
      _persistHomeLayout();
      return;
    }

    homeWidgetOrder.assignAll(order.where((id) => !id.videoOnly));
    enabledHomeWidgets.assignAll(enabled.where((id) => !id.videoOnly));
    homeWidgetLayouts.value = Map<String, HomeCustomSectionLayout>.from(
      layouts,
    );
    customHomeSections.assignAll(_normalizeCustomHomeSections(customSections));
    isHomeEditing.value = false;
    _persistHomeLayout();
  }

  void addCustomPlaylistSection({
    required String playlistId,
    required String title,
  }) {
    final cleanId = playlistId.trim();
    if (cleanId.isEmpty) return;
    customHomeSections.assignAll(
      _normalizeCustomHomeSections(customHomeSections.toList(growable: false)),
    );
    const sectionId = 'playlists_custom';
    final index = customHomeSections.indexWhere((e) => e.id == sectionId);
    if (index >= 0) {
      final current = customHomeSections[index];
      final ids = current.targetId
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      ids.add(cleanId);
      customHomeSections[index] = HomeCustomSection(
        id: current.id,
        kind: HomeCustomSectionKind.playlist,
        targetId: ids.join('|'),
        title: tr('home.custom.playlists'),
        layout: current.layout,
      );
      _persistHomeLayout();
      return;
    }

    customHomeSections.add(
      HomeCustomSection(
        id: sectionId,
        kind: HomeCustomSectionKind.playlist,
        targetId: cleanId,
        title: tr('home.custom.playlists'),
      ),
    );
    _persistHomeLayout();
  }

  void addCustomArtistSection({
    required String artistKey,
    required String title,
  }) {
    final cleanKey = ArtistCreditParser.normalizeKey(artistKey);
    if (cleanKey.isEmpty || cleanKey == 'unknown') return;
    customHomeSections.assignAll(
      _normalizeCustomHomeSections(customHomeSections.toList(growable: false)),
    );
    const sectionId = 'artists_custom';
    final index = customHomeSections.indexWhere((e) => e.id == sectionId);
    if (index >= 0) {
      final current = customHomeSections[index];
      final keys = current.targetId
          .split('|')
          .map(ArtistCreditParser.normalizeKey)
          .where((e) => e.isNotEmpty && e != 'unknown')
          .toSet();
      keys.add(cleanKey);
      customHomeSections[index] = HomeCustomSection(
        id: current.id,
        kind: HomeCustomSectionKind.artist,
        targetId: keys.join('|'),
        title: tr('home.custom.artists'),
        layout: current.layout,
      );
      _persistHomeLayout();
      return;
    }

    customHomeSections.add(
      HomeCustomSection(
        id: sectionId,
        kind: HomeCustomSectionKind.artist,
        targetId: cleanKey,
        title: tr('home.custom.artists'),
      ),
    );
    _persistHomeLayout();
  }

  void addSmartHomeSection({required String targetId, required String title}) {
    final cleanId = targetId.trim();
    if (cleanId.isEmpty) return;
    customHomeSections.removeWhere(
      (section) =>
          section.kind == HomeCustomSectionKind.smart &&
          section.targetId == cleanId,
    );
    customHomeSections.add(
      HomeCustomSection(
        id: 'smart_$cleanId',
        kind: HomeCustomSectionKind.smart,
        targetId: cleanId,
        title: title.trim().isEmpty ? tr('home.custom.smart') : title.trim(),
      ),
    );
    _persistHomeLayout();
  }

  void toggleCustomSectionLayout(String id) {
    final index = customHomeSections.indexWhere((section) => section.id == id);
    if (index < 0) return;
    final current = customHomeSections[index];
    final nextLayout = current.layout == HomeCustomSectionLayout.cards
        ? HomeCustomSectionLayout.list
        : HomeCustomSectionLayout.cards;
    customHomeSections[index] = current.copyWith(layout: nextLayout);
    _persistHomeLayout();
  }

  void removeCustomHomeSection(String id) {
    customHomeSections.removeWhere((section) => section.id == id);
    _persistHomeLayout();
  }

  void removeTargetFromCustomHomeSection({
    required String sectionId,
    required String targetId,
    HomeMode mode = HomeMode.audio,
  }) {
    final sections = mode == HomeMode.video
        ? videoCustomHomeSections
        : customHomeSections;
    final index = sections.indexWhere((section) => section.id == sectionId);
    if (index < 0) return;

    final section = sections[index];
    final normalizedTarget = section.kind == HomeCustomSectionKind.artist
        ? ArtistCreditParser.normalizeKey(targetId)
        : targetId.trim();
    if (normalizedTarget.isEmpty || normalizedTarget == 'unknown') return;

    final nextTargets = section.targetId
        .split('|')
        .map(
          (entry) => section.kind == HomeCustomSectionKind.artist
              ? ArtistCreditParser.normalizeKey(entry)
              : entry.trim(),
        )
        .where(
          (entry) =>
              entry.isNotEmpty &&
              entry != 'unknown' &&
              entry != normalizedTarget,
        )
        .toList(growable: false);

    if (nextTargets.isEmpty) {
      sections.removeAt(index);
    } else {
      sections[index] = section.copyWith(targetId: nextTargets.join('|'));
    }
    _persistHomeLayout();
  }

  Future<List<Playlist>> loadPlaylistChoices() async {
    return await _playlistStore?.readAll() ?? const <Playlist>[];
  }

  List<HomePlaylistChoice> playlistChoices() {
    final playlists = _playlistStore?.readAllSync() ?? const <Playlist>[];
    return playlists
        .map(
          (playlist) => HomePlaylistChoice(
            id: playlist.id,
            name: playlist.name,
            count: playlist.itemIds.length,
            cover: _playlistCover(playlist),
          ),
        )
        .toList(growable: false);
  }

  List<HomeCollectionChoice> collectionChoices() {
    final playlists =
        _topicPlaylistStore?.readAllSync() ??
        const <SourceThemeTopicPlaylist>[];
    final topics = <String, SourceThemeTopic>{
      for (final topic
          in _topicStore?.readAllSync() ?? const <SourceThemeTopic>[])
        topic.id: topic,
    };
    return playlists
        .map(
          (playlist) => HomeCollectionChoice(
            id: playlist.id,
            themeId: topics[playlist.topicId]?.themeId ?? '',
            name: playlist.name,
            count: playlist.itemIds.length,
            cover: _collectionCover(playlist),
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<HomeArtistChoice> artistChoices() {
    final buckets = <String, ({String name, int count, String? thumbnail})>{};
    final profiles = <String, ArtistProfile>{
      for (final profile
          in _artistStore?.readAllSync() ?? const <ArtistProfile>[])
        ArtistCreditParser.normalizeKey(profile.key): profile,
    };
    for (final item in _allItems) {
      if (!item.variants.any((v) => v.kind == MediaVariantKind.audio)) {
        continue;
      }
      for (final name in ArtistCreditParser.parse(item.subtitle).allArtists) {
        final key = ArtistCreditParser.normalizeKey(name);
        if (key.isEmpty || key == 'unknown') continue;
        final current = buckets[key];
        buckets[key] = (
          name: current?.name ?? name,
          count: (current?.count ?? 0) + 1,
          thumbnail: current?.thumbnail ?? item.effectiveThumbnail,
        );
      }
    }
    final list = buckets.entries
        .map((entry) {
          final profile = profiles[entry.key];
          return HomeArtistChoice(
            key: entry.key,
            name: profile?.displayName ?? entry.value.name,
            count: entry.value.count,
            thumbnail: _artistProfileThumbnail(profile),
            kindKey: profile?.kind.key,
            country: profile?.country,
            countryCode: profile?.countryCode,
          );
        })
        .toList(growable: false);
    return list..sort((a, b) => a.name.compareTo(b.name));
  }

  String? _artistProfileThumbnail(ArtistProfile? profile) {
    final local = profile?.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) return local;
    final remote = profile?.thumbnail?.trim();
    if (remote != null && remote.isNotEmpty) return remote;
    return null;
  }

  String? _playlistCover(Playlist playlist) {
    if (playlist.coverCleared) return null;
    final local = playlist.coverLocalPath?.trim();
    if (local != null && local.isNotEmpty) return local;
    final remote = playlist.coverUrl?.trim();
    if (remote != null && remote.isNotEmpty) return remote;
    return null;
  }

  String? _collectionCover(SourceThemeTopicPlaylist playlist) {
    final local = playlist.coverLocalPath?.trim();
    if (local != null && local.isNotEmpty) return local;
    final remote = playlist.coverUrl?.trim();
    if (remote != null && remote.isNotEmpty) return remote;
    return null;
  }

  List<MediaItem> resolveCustomSectionItems(HomeCustomSection section) {
    if (section.kind == HomeCustomSectionKind.collection) {
      return _resolveCollectionItems(section.targetId);
    }
    if (section.kind == HomeCustomSectionKind.playlist) {
      return _resolvePlaylistItems(section.targetId);
    }
    if (section.kind == HomeCustomSectionKind.smart) {
      return _resolveSmartSectionItems(section.targetId);
    }
    final target = ArtistCreditParser.normalizeKey(section.targetId);
    return _allItems
        .where((item) {
          if (!item.variants.any((v) => v.kind == MediaVariantKind.audio)) {
            return false;
          }
          return ArtistCreditParser.parse(item.subtitle).allArtists.any(
            (name) => ArtistCreditParser.normalizeKey(name) == target,
          );
        })
        .toList(growable: false);
  }

  List<HomeArtistChoice> resolveArtistsForCustomSection(
    HomeCustomSection section,
  ) {
    if (section.kind != HomeCustomSectionKind.artist) {
      return const <HomeArtistChoice>[];
    }
    final keys = section.targetId
        .split('|')
        .map(ArtistCreditParser.normalizeKey)
        .where((e) => e.isNotEmpty && e != 'unknown')
        .toSet();
    if (keys.isEmpty) return const <HomeArtistChoice>[];
    return artistChoices()
        .where((artist) => keys.contains(artist.key))
        .toList(growable: false);
  }

  List<HomePlaylistChoice> resolvePlaylistsForCustomSection(
    HomeCustomSection section,
  ) {
    if (section.kind != HomeCustomSectionKind.playlist) {
      return const <HomePlaylistChoice>[];
    }
    final ids = section.targetId
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return const <HomePlaylistChoice>[];
    return playlistChoices()
        .where((playlist) => ids.contains(playlist.id))
        .toList(growable: false);
  }

  List<HomeCollectionChoice> resolveCollectionsForCustomSection(
    HomeCustomSection section,
  ) {
    if (section.kind != HomeCustomSectionKind.collection) {
      return const <HomeCollectionChoice>[];
    }
    final ids = section.targetId
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return const <HomeCollectionChoice>[];
    return collectionChoices()
        .where((collection) => ids.contains(collection.id))
        .toList(growable: false);
  }

  List<MediaItem> previewItemsForHomeWidget(HomeWidgetId id) {
    return fullItemsForHomeWidget(id).take(12).toList(growable: false);
  }

  List<MediaItem> fullItemsForHomeWidget(HomeWidgetId id) {
    final items = switch (id) {
      HomeWidgetId.favorites => fullFavorites,
      HomeWidgetId.continueWatching => _continueWatchingItems(),
      HomeWidgetId.mostPlayed => fullMostPlayed,
      HomeWidgetId.recentlyPlayed => fullRecentlyPlayed,
      HomeWidgetId.featured => fullFeatured,
      HomeWidgetId.latestDownloads => fullLatestDownloads,
      HomeWidgetId.notPlayed => _resolveSmartSectionItems('not_played'),
      HomeWidgetId.randomMix => randomMix,
      HomeWidgetId.recommendations => fullRecommended,
    };
    return _applyHomeWidgetSort(id, items);
  }

  List<MediaItem> _continueWatchingItems() {
    final raw = _layoutStorage.read<Map>(
      VideoPlayerController.resumePosStorageKey,
    );
    if (raw == null || raw.isEmpty) return const <MediaItem>[];
    final rawWatch = _layoutStorage.read<Map>(
      VideoPlayerController.resumeWatchStorageKey,
    );
    if (rawWatch == null || rawWatch.isEmpty) return const <MediaItem>[];

    final positions = <String, int>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim();
      final value = entry.value;
      final ms = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
      if (key.isEmpty || ms <= 1500) continue;
      positions[key] = ms;
    }
    final trustedWatch = <String, int>{};
    for (final entry in rawWatch.entries) {
      final key = entry.key.toString().trim();
      final value = entry.value;
      final ms = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
      if (key.isEmpty || ms < 8000) continue;
      trustedWatch[key] = ms;
    }
    if (positions.isEmpty) return const <MediaItem>[];
    if (trustedWatch.isEmpty) return const <MediaItem>[];

    final result = _allItems
        .where((item) {
          if (!item.hasVideoLocal) return false;
          final key = _resumeKeyFor(item);
          if ((trustedWatch[key] ?? 0) < 8000) return false;
          final positionMs = positions[key] ?? 0;
          if (positionMs <= 1500) return false;
          final durationMs = (item.effectiveDurationSeconds ?? 0) * 1000;
          if (durationMs < 150000) return false;
          final progress = positionMs / durationMs;
          return progress > 0.05 && progress < 0.90;
        })
        .toList(growable: true);

    result.sort((a, b) {
      final aPos = positions[_resumeKeyFor(a)] ?? 0;
      final bPos = positions[_resumeKeyFor(b)] ?? 0;
      final byLastPlayed = (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0);
      if (byLastPlayed != 0) return byLastPlayed;
      return bPos.compareTo(aPos);
    });
    return result;
  }

  String _resumeKeyFor(MediaItem item) {
    final publicId = item.publicId.trim();
    return publicId.isNotEmpty ? publicId : item.id.trim();
  }

  String? continueWatchingHintFor(MediaItem item) {
    final raw = _layoutStorage.read<Map>(
      VideoPlayerController.resumePosStorageKey,
    );
    if (raw == null || raw.isEmpty) return null;
    final rawWatch = _layoutStorage.read<Map>(
      VideoPlayerController.resumeWatchStorageKey,
    );
    final value = raw[_resumeKeyFor(item)];
    final watchValue = rawWatch?[_resumeKeyFor(item)];
    final watchMs = watchValue is num
        ? watchValue.toInt()
        : int.tryParse('$watchValue') ?? 0;
    if (watchMs < 8000) return null;
    final positionMs = value is num
        ? value.toInt()
        : int.tryParse('$value') ?? 0;
    if (positionMs <= 1500) return null;
    final durationMs = (item.effectiveDurationSeconds ?? 0) * 1000;
    if (durationMs <= 0) return 'Continuar';
    final progress = (positionMs / durationMs).clamp(0.0, 0.99);
    final remainingMs = (durationMs - positionMs).clamp(0, durationMs);
    final remainingMinutes = (remainingMs / 60000).ceil();
    final percent = (progress * 100).round();
    if (remainingMinutes <= 1) return '$percent% visto · queda <1 min';
    return '$percent% visto · quedan $remainingMinutes min';
  }

  List<MediaItem> _applyHomeWidgetSort(HomeWidgetId id, List<MediaItem> input) {
    final options = sortOptionsForHomeWidget(id);
    if (options.isEmpty) return input.toList(growable: false);

    final sort = sortForHomeWidget(id);
    final ascending = sortAscendingForHomeWidget(id);
    final list = input.toList(growable: true);
    int compareString(String a, String b) =>
        a.toLowerCase().compareTo(b.toLowerCase());

    list.sort((a, b) {
      final result = switch (sort) {
        HomeMediaSort.title => compareString(a.title, b.title),
        HomeMediaSort.artist => compareString(
          a.displaySubtitle,
          b.displaySubtitle,
        ),
        HomeMediaSort.importedAt => _latestVariantCreatedAt(
          a,
        ).compareTo(_latestVariantCreatedAt(b)),
        HomeMediaSort.size => _localSizeBytes(a).compareTo(_localSizeBytes(b)),
        HomeMediaSort.plays => a.playCount.compareTo(b.playCount),
        HomeMediaSort.duration => (a.effectiveDurationSeconds ?? 0).compareTo(
          b.effectiveDurationSeconds ?? 0,
        ),
        HomeMediaSort.recent => (a.lastPlayedAt ?? 0).compareTo(
          b.lastPlayedAt ?? 0,
        ),
      };
      if (result != 0) return ascending ? result : -result;
      return compareString(a.title, b.title);
    });
    return list;
  }

  List<MediaItem> _resolveSmartSectionItems(String targetId) {
    final audio = _allItems
        .where(
          (item) => item.variants.any((v) => v.kind == MediaVariantKind.audio),
        )
        .toList(growable: false);
    switch (targetId) {
      case 'not_played':
        return audio.where((item) => item.playCount == 0).take(80).toList();
      case 'rediscover':
        final items =
            audio
                .where((item) => (item.lastPlayedAt ?? 0) > 0)
                .toList(growable: true)
              ..sort(
                (a, b) => (a.lastPlayedAt ?? 0).compareTo(b.lastPlayedAt ?? 0),
              );
        return items.take(80).toList(growable: false);
      case 'random_mix':
        final items = audio.toList(growable: true)..shuffle();
        return items.take(80).toList(growable: false);
      default:
        return const <MediaItem>[];
    }
  }

  List<MediaItem> _resolvePlaylistItems(String playlistId) {
    final rawPlaylists = _layoutStorage.read<List>('playlists');
    Playlist? playlist;
    for (final raw in rawPlaylists ?? const <dynamic>[]) {
      if (raw is! Map) continue;
      final parsed = Playlist.fromJson(Map<String, dynamic>.from(raw));
      if (parsed.id == playlistId) {
        playlist = parsed;
        break;
      }
    }
    final ids = playlist?.itemIds.toSet() ?? const <String>{};
    if (ids.isEmpty) return const <MediaItem>[];
    return _allItems
        .where((item) {
          final publicId = item.publicId.trim();
          final key = publicId.isNotEmpty ? publicId : item.id.trim();
          return ids.contains(key);
        })
        .toList(growable: false);
  }

  List<MediaItem> _resolveCollectionItems(String collectionIds) {
    final ids = collectionIds
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return const <MediaItem>[];
    final playlists =
        _topicPlaylistStore?.readAllSync() ??
        const <SourceThemeTopicPlaylist>[];
    final itemKeys = <String>{};
    for (final playlist in playlists) {
      if (ids.contains(playlist.id)) {
        itemKeys.addAll(playlist.itemIds.map((e) => e.trim()));
      }
    }
    if (itemKeys.isEmpty) return const <MediaItem>[];
    return _allItems
        .where((item) {
          if (!item.hasVideoLocal) return false;
          final publicId = item.publicId.trim();
          final key = publicId.isNotEmpty ? publicId : item.id.trim();
          return itemKeys.contains(key);
        })
        .toList(growable: false);
  }

  void _persistHomeLayout() {
    _layoutStorage.write(
      _homeWidgetOrderKey,
      homeWidgetOrder.map((e) => e.key).toList(growable: false),
    );
    _layoutStorage.write(
      _homeWidgetEnabledKey,
      enabledHomeWidgets.map((e) => e.key).toList(growable: false),
    );
    _layoutStorage.write(
      _homeWidgetLayoutsKey,
      homeWidgetLayouts.map((key, value) => MapEntry(key, value.key)),
    );
    _layoutStorage.write(
      _homeWidgetSortsKey,
      homeWidgetSorts.map((key, value) => MapEntry(key, value.key)),
    );
    _layoutStorage.write(
      _homeWidgetSortAscendingKey,
      Map<String, bool>.from(homeWidgetSortAscending),
    );
    _layoutStorage.write(
      _videoHomeWidgetOrderKey,
      videoHomeWidgetOrder.map((e) => e.key).toList(growable: false),
    );
    _layoutStorage.write(
      _videoHomeWidgetEnabledKey,
      enabledVideoHomeWidgets.map((e) => e.key).toList(growable: false),
    );
    _layoutStorage.write(
      _homeCustomSectionsKey,
      customHomeSections.map((e) => e.toJson()).toList(growable: false),
    );
    _layoutStorage.write(
      _videoHomeCustomSectionsKey,
      videoCustomHomeSections.map((e) => e.toJson()).toList(growable: false),
    );
  }

  Future<void> loadHome() async {
    isLoading.value = true;
    try {
      final items = await _backfillVideoDurations(await _repo.getLibrary());
      _allItems.assignAll(items);
      _splitHomeSections(_allItems);
      if (mode.value == HomeMode.audio) {
        await _loadRecommendationsForCurrentMode();
      } else {
        _clearRecommendations();
      }
    } catch (e) {
      print('Error loading home: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<MediaItem>> _backfillVideoDurations(List<MediaItem> input) async {
    final output = <MediaItem>[];
    for (final item in input) {
      if (!item.hasVideoLocal || (item.effectiveDurationSeconds ?? 0) > 0) {
        output.add(item);
        continue;
      }

      final video = item.localVideoVariant;
      final path = video?.playablePath?.trim();
      if (video == null || path == null || path.isEmpty) {
        output.add(item);
        continue;
      }

      final metadata = await _metadata.readMediaMetadata(path);
      final seconds = metadata?.durationSeconds;
      if (seconds == null || seconds <= 0) {
        output.add(item);
        continue;
      }

      final variants = item.variants
          .map((variant) {
            if (!variant.sameIdentityAs(video)) return variant;
            return MediaVariant(
              kind: variant.kind,
              format: variant.format,
              fileName: variant.fileName,
              localPath: variant.localPath,
              createdAt: variant.createdAt,
              size: variant.size,
              durationSeconds: seconds,
              role: variant.role,
            );
          })
          .toList(growable: false);

      final updated = item.copyWith(
        variants: variants,
        durationSeconds: item.durationSeconds ?? seconds,
      );
      await _store.upsert(updated);
      output.add(updated);
    }
    return output;
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

    // Generate and cache random mix
    final audio =
        filtered
            .where(
              (item) =>
                  item.variants.any((v) => v.kind == MediaVariantKind.audio),
            )
            .toList(growable: true)
          ..shuffle();
    randomMix.assignAll(audio.take(80).toList(growable: false));
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

  int _localSizeBytes(MediaItem item) {
    var total = 0;
    for (final variant in item.variants) {
      if (variant.localPath?.trim().isNotEmpty != true) continue;
      total += variant.size ?? 0;
    }
    return total;
  }

  void toggleMode() {
    mode.value = mode.value == HomeMode.audio ? HomeMode.video : HomeMode.audio;
    _splitHomeSections(_allItems);
    if (mode.value == HomeMode.audio) {
      _loadRecommendationsForCurrentMode();
    } else {
      _clearRecommendations();
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
        tr('dialogs.downloads.title'),
        tr('dialogs.downloads.delete_error'),
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
        tr('dialogs.favorites.title'),
        tr('dialogs.favorites.update_error'),
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

  void goToAtlas() => Get.toNamed(AppRoutes.worldMode);

  void goToSettings() => Get.toNamed(AppRoutes.settings);

  void enterHome() => Get.offAllNamed(AppRoutes.home);

  List<MediaItem> get allItems => List<MediaItem>.from(_allItems);

  Future<void> _loadRecommendationsForCurrentMode() async {
    if (mode.value == HomeMode.video) {
      _clearRecommendations();
      return;
    }

    final audioCount = _allItems.where((item) => item.hasAudioLocal).length;
    if (audioCount < 60) {
      _clearRecommendations();
      return;
    }

    isRecommendationsLoading.value = true;
    try {
      _artistLocaleByKey = await _loadArtistLocaleMap();
      final set = await _getRecommendationsForDay.call(
        mode: _currentRecommendationMode(),
      );
      await _applyRecommendationSet(set);
    } catch (e) {
      print('Error loading recommendations: $e');
    } finally {
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

      final countryName =
          CountryCatalog.countryNameFromCodeForLocale(
            profile.countryCode,
            Get.context?.locale.languageCode ?? 'es',
          ) ??
          ((profile.country ?? '').trim().isNotEmpty
              ? profile.country!.trim()
              : null);
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
    return tr('recommendations.reasons.country_listened', args: [country]);
  }

  Future<void> _applyRecommendationSet(RecommendationDailySet set) async {
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

    final collections = await _buildCollections.call(
      BuildRecommendationCollectionsInput(
        entries: resolvedEntries,
        library: filtered,
        resolveLocaleSignal: _resolveItemLocaleSignal,
        stableKeyOf: _itemStableKey,
        now: DateTime.now(),
      ),
    );
    for (final collection in collections) {
      if (!collection.id.startsWith('region-')) continue;
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
    final mixedItems = <MediaItem>[];
    final mixedKeys = <String>{};
    for (final collection in collections) {
      for (final item in collection.items) {
        if (mixedKeys.add(_itemStableKey(item))) mixedItems.add(item);
      }
    }
    fullRecommended.assignAll(mixedItems.take(_recommendedFullLimit));
    recommended.assignAll(mixedItems.take(_recommendedPreviewLimit));
    recommendationReasonsById.assignAll(reasons);
    recommendationCollections.assignAll(collections);
    _scheduleRecommendationCycleRefresh(collections);
  }

  void _scheduleRecommendationCycleRefresh(
    List<RecommendationCollection> collections,
  ) {
    _recommendationCycleTimer?.cancel();
    if (collections.isEmpty) return;
    final expiresAt = collections.first.expiresAt;
    if (expiresAt == null) return;
    final delay = Duration(
      milliseconds: max(
        1000,
        expiresAt - DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _recommendationCycleTimer = Timer(delay, () {
      if (mode.value == HomeMode.audio && !isClosed) {
        _loadRecommendationsForCurrentMode();
      }
    });
  }

  Future<void> markRecommendationMixOpened(
    RecommendationCollection collection,
  ) {
    return _buildCollections.markOpened(collection.id);
  }

  String get recommendationCycleHint {
    if (recommendationCollections.isEmpty) return '';
    final expiresAt = recommendationCollections.first.expiresAt;
    if (expiresAt == null) return '';
    final remaining = Duration(
      milliseconds: expiresAt - DateTime.now().millisecondsSinceEpoch,
    );
    if (remaining <= Duration.zero) return 'Nuevo ciclo disponible';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return 'Nuevos mixes en ${hours}h ${minutes}m';
  }

  void _clearRecommendations() {
    _recommendationCycleTimer?.cancel();
    recommended.clear();
    fullRecommended.clear();
    recommendationReasonsById.clear();
    recommendationCollections.clear();
  }

  @override
  void onClose() {
    _recommendationCycleTimer?.cancel();
    super.onClose();
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
