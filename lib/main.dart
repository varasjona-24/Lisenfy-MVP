import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'app/data/local/catalog_storage.dart';
import 'app/data/local/domain_storage.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart' as aud;
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/controllers/theme_controller.dart';
import 'app/controllers/navigation_controller.dart';
import 'app/controllers/media_actions_controller.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/ui/themes/app_theme_factory.dart';
import 'app/ui/widgets/player/mini_player_bar.dart';
import 'app/ui/widgets/download/download_progress_banner.dart';

import 'app/data/network/dio_client.dart';
import 'app/data/repo/media_repository.dart';
import 'app/data/local/local_library_store.dart';
import 'app/services/audio_service.dart';
import 'app/services/sqlite_engine_history_factory.dart';
import 'app/data/playback/playback_repository.dart';
import 'app/data/playback/playback_debug_bootstrap.dart';
import 'app/data/playback/playback_production_bootstrap.dart';
import 'app/data/playback/playback_state_storage.dart';
import 'package:uuid/uuid.dart';
import 'app/services/app_audio_handler.dart';
import 'app/services/instrumental_generation_service.dart';
import 'app/services/local_media_metadata_service.dart';
import 'app/services/spatial_audio_service.dart';
import 'app/services/spatial8d_generation_service.dart';
import 'app/services/video_service.dart';
import 'app/services/karaoke_remote_pipeline_service.dart';
import 'app/services/deep_link_service.dart';
import 'app/services/notification_service.dart';
import 'Modules/settings/controller/settings_controller.dart';
import 'Modules/settings/controller/playback_settings_controller.dart';
import 'Modules/settings/controller/sleep_timer_controller.dart';
import 'Modules/settings/controller/equalizer_controller.dart';
import 'Modules/settings/controller/notification_settings_controller.dart';
import 'Modules/downloads/controller/downloads_controller.dart';
import 'Modules/downloads/data/repositories/downloads_repository_impl.dart';
import 'Modules/downloads/domain/contracts/downloads_repository.dart';
import 'Modules/downloads/domain/usecases/load_download_items_usecase.dart';
import 'Modules/downloads/service/download_task_service.dart';
import 'Modules/artists/data/artist_store.dart';
import 'Modules/playlists/data/playlist_store.dart';
import 'Modules/sources/data/source_theme_topic_store.dart';
import 'Modules/sources/data/source_theme_topic_playlist_store.dart';
import 'Modules/recommendations/data/recommendation_store.dart';
import 'Modules/recommendations/data/recommendation_feedback_store.dart';
import 'Modules/recommendations/data/listening_event_store.dart';
import 'Modules/recommendations/data/recommendation_ml_store.dart';
import 'Modules/recommendations/application/local_recommendation_service.dart';
import 'Modules/recommendations/application/local_ml_recommendation_ranker.dart';
import 'Modules/recommendations/application/recommendation_feedback_service.dart';
import 'Modules/recommendations/domain/contracts/recommendation_engine.dart';
import 'Modules/stats/application/weekly_listening_summary.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await GetStorage.init();

  // Eliminado bloqueo de UI en main()
  // ...

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 🎨 Controller global de tema
  Get.put(ThemeController(), permanent: true);

  // 🧭 Controller global de navegación
  Get.put(NavigationController(), permanent: true);

  // 🔔 Notificaciones locales
  Get.put<NotificationService>(
    await NotificationService().init(),
    permanent: true,
  );

  // ⚙️ Controller global de configuración

  // 🎵 Audio global (CLAVE)
  Get.put<GetStorage>(GetStorage(), permanent: true);
  Get.put(LocalLibraryStore(Get.find<GetStorage>()), permanent: true);
  Get.put(ListeningEventStore(Get.find<GetStorage>()), permanent: true);
  SqliteEngineHistoryFactory? sqliteHistory;
  final productionStorage =
      await PlaybackProductionBootstrap.shouldUseProduction();
  if (productionStorage) {
    final progress = ValueNotifier<String>('capturing');
    final failed = ValueNotifier<bool>(false);
    Completer<void>? retry;
    runApp(
      EasyLocalization(
        supportedLocales: const [Locale('es'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('es'),
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: failed,
                    builder: (context, error, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!error) const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          tr(
                            error
                                ? 'storage_startup.failed'
                                : 'storage_startup.title',
                            context: context,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<String>(
                          valueListenable: progress,
                          builder: (context, stage, _) => Text(
                            tr('storage_startup.$stage', context: context),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (error)
                          TextButton(
                            onPressed: () {
                              if (retry != null && !retry.isCompleted) {
                                retry.complete();
                              }
                            },
                            child: Text(
                              tr('storage_startup.retry', context: context),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    PlaybackProductionState? active;
    while (active == null) {
      try {
        failed.value = false;
        active = await PlaybackProductionBootstrap.open(
          Get.find<GetStorage>(),
          onProgress: (stage) => progress.value = stage,
        );
      } catch (error, stack) {
        debugPrint('SQLite activation failed: $error\n$stack');
        retry = Completer<void>();
        progress.value = 'preserved';
        failed.value = true;
        await retry.future;
      }
    }
    Get.put(active.repository, permanent: true);
    Get.put<PlaybackStateStorage>(active.restoration, permanent: true);
    Get.put<CatalogStorage>(active.catalog, permanent: true);
    Get.put<DomainStorage>(active.domains, permanent: true);
    final library = LocalLibraryStore(
      Get.find<GetStorage>(),
      metricsLoader: active.repository.queryLibraryMetrics,
    );
    await library.readAll();
    Get.replace<LocalLibraryStore>(library);
    Get.replace<ListeningEventStore>(
      ListeningEventStore.sqlite(
        querySqlite: active.repository.queryListeningEvents,
      ),
    );
    sqliteHistory = SqliteEngineHistoryFactory(
      repository: active.repository,
      installationScope: active.installationScope,
    );
  }
  // Test-only staging remains available when no production generation is active.
  if (!productionStorage &&
      kDebugMode &&
      const bool.fromEnvironment('LISTENFY_SQLITE_STAGING_HISTORY')) {
    final storage = Get.find<GetStorage>();
    var scope = storage.read<String>('playback_staging_installation');
    if (scope == null) {
      scope = const Uuid().v4();
      await storage.write('playback_staging_installation', scope);
    }
    final (repository, restoration) = await PlaybackDebugBootstrap.open(
      storage,
      scope,
    );
    Get.put(repository, permanent: true);
    Get.put<PlaybackStateStorage>(restoration, permanent: true);
    Get.put<CatalogStorage>(
      await CatalogStorage.open(repository, storage, scope),
      permanent: true,
    );
    Get.put<DomainStorage>(
      await DomainStorage.open(repository, storage, scope),
      permanent: true,
    );
    final library = LocalLibraryStore(
      storage,
      metricsLoader: repository.queryLibraryMetrics,
    );
    await library.readAll();
    Get.replace<LocalLibraryStore>(library);
    Get.replace<ListeningEventStore>(
      ListeningEventStore.sqlite(querySqlite: repository.queryListeningEvents),
    );
    sqliteHistory = SqliteEngineHistoryFactory(
      repository: repository,
      installationScope: scope,
    );
    debugPrint(
      'SQLite DEBUG: legacy imported, restoration loaded, history consumers connected; scope=$scope',
    );
  }
  // Settings must read after SQL projections are loaded, not stale legacy data.
  Get.put(SettingsController(), permanent: true);
  Get.put(PlaybackSettingsController(), permanent: true);
  Get.put(SleepTimerController(), permanent: true);
  Get.put(EqualizerController(), permanent: true);
  Get.put(NotificationSettingsController(), permanent: true);
  final appAudio = AudioService(historyRecorder: sqliteHistory?.create());
  Get.put<AudioService>(appAudio, permanent: true);
  await appAudio.initializeAndroidAutoArtwork();

  // 🔔 Background controls / lockscreen
  final handler = await aud.AudioService.init(
    builder: () => AppAudioHandler(appAudio),
    config: const aud.AudioServiceConfig(
      androidNotificationChannelId: 'com.jv24dev.listenfy.audio',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationChannelDescription: 'Controles de reproducción',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_listenfy_notification',
      preloadArtwork: true,
    ),
  );
  appAudio.attachHandler(handler);

  // 🎬 Video global (CLAVE)
  Get.put<VideoService>(
    VideoService(historyRecorder: sqliteHistory?.create()),
    permanent: true,
  );

  // 🎧 Spatial audio (8D)
  Get.put<SpatialAudioService>(
    SpatialAudioService(audioService: Get.find<AudioService>()),
    permanent: true,
  );

  // 🌐 Cliente HTTP
  Get.lazyPut<DioClient>(() => DioClient(), fenix: true);

  // 📦 GetStorage (shared)

  Get.put(
    KaraokeRemotePipelineService(client: Get.find<DioClient>()),
    permanent: true,
  );
  Get.put(LocalMediaMetadataService(), permanent: true);

  // 💾 Local storage
  if (!Get.isRegistered<PlaylistStore>()) {
    Get.put(PlaylistStore(Get.find<GetStorage>()), permanent: true);
  }
  if (!Get.isRegistered<ArtistStore>()) {
    Get.put(ArtistStore(Get.find<GetStorage>()), permanent: true);
  }
  Get.put(InstrumentalGenerationService(), permanent: true);
  Get.put(Spatial8dGenerationService(), permanent: true);
  if (!Get.isRegistered<SourceThemeTopicStore>()) {
    Get.put(SourceThemeTopicStore(Get.find<GetStorage>()), permanent: true);
  }
  if (!Get.isRegistered<SourceThemeTopicPlaylistStore>()) {
    Get.put(
      SourceThemeTopicPlaylistStore(Get.find<GetStorage>()),
      permanent: true,
    );
  }

  // 🧩 Controller global de acciones de media
  Get.put(MediaActionsController(), permanent: true);

  // 📦 Repositorio de media
  Get.lazyPut<MediaRepository>(() => MediaRepository(), fenix: true);

  // 🧠 Recomendaciones locales (MVP diario)
  Get.put(RecommendationStore(Get.find<GetStorage>()), permanent: true);
  Get.put(RecommendationFeedbackStore(Get.find<GetStorage>()), permanent: true);
  Get.put(RecommendationMlStore(Get.find<GetStorage>()), permanent: true);
  Get.put(
    LocalMlRecommendationRanker(store: Get.find<RecommendationMlStore>()),
    permanent: true,
  );
  Get.put(
    RecommendationFeedbackService(
      store: Get.find<RecommendationFeedbackStore>(),
    ),
    permanent: true,
  );
  final recommendationService = LocalRecommendationService(
    store: Get.find<RecommendationStore>(),
    feedbackService: Get.find<RecommendationFeedbackService>(),
    listeningEventStore: Get.find<ListeningEventStore>(),
    ranker: Get.find<LocalMlRecommendationRanker>(),
    libraryLoader: () => Get.find<MediaRepository>().getLibrary(),
    artistProfileLoader: () => Get.find<ArtistStore>().readAll(),
    topicLoader: () async {
      if (!Get.isRegistered<SourceThemeTopicStore>()) {
        return const [];
      }
      return Get.find<SourceThemeTopicStore>().readAll();
    },
    topicPlaylistLoader: () async {
      if (!Get.isRegistered<SourceThemeTopicPlaylistStore>()) {
        return const [];
      }
      return Get.find<SourceThemeTopicPlaylistStore>().readAll();
    },
  );
  Get.put<LocalRecommendationService>(recommendationService, permanent: true);
  Get.put<RecommendationEngine>(recommendationService, permanent: true);
  final weeklySummaryBuilder = WeeklyListeningSummaryBuilder(
    listeningEventStore: Get.find<ListeningEventStore>(),
    libraryLoader: () => Get.find<MediaRepository>().getLibrary(),
  );
  Get.find<NotificationService>().configureWeeklySummaryLoader(
    weeklySummaryBuilder.build,
  );

  // 🚚 Runtime global de imports/descargas
  Get.put(DownloadTaskService(), permanent: true);

  if (!Get.isRegistered<DownloadsRepository>()) {
    Get.lazyPut<DownloadsRepository>(
      () =>
          DownloadsRepositoryImpl(mediaRepository: Get.find<MediaRepository>()),
      fenix: true,
    );
  }

  if (!Get.isRegistered<LoadDownloadItemsUseCase>()) {
    Get.lazyPut<LoadDownloadItemsUseCase>(
      () =>
          LoadDownloadItemsUseCase(repository: Get.find<DownloadsRepository>()),
      fenix: true,
    );
  }

  // 📥 Imports/Downloads global (share intent listener)
  Get.put(
    DownloadsController(
      loadDownloadItemsUseCase: Get.find<LoadDownloadItemsUseCase>(),
    ),
    permanent: true,
  );
  Get.put(DeepLinkService(), permanent: true);

  // 🎚️ Reaplicar ecualizador cuando AudioService ya existe (no bloquear arranque)
  if (Get.isRegistered<EqualizerController>()) {
    try {
      Get.find<EqualizerController>().refreshEqualizer();
    } catch (e) {
      // TODO: Handle error or log it
    }
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('es'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('es'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final PlaybackNavigationObserver _playbackNavigationObserver =
      PlaybackNavigationObserver();
  StreamSubscription<bool>? _notificationClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    unawaited(Get.find<DeepLinkService>().start());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(Get.find<NotificationService>().syncScheduledNotifications());
      Get.find<NotificationService>().flushPendingNavigation();
    });
    _notificationClickSub = aud.AudioService.notificationClicked.listen((
      clicked,
    ) {
      if (!clicked) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Get.currentRoute == AppRoutes.audioPlayer) return;
        Get.toNamed(AppRoutes.audioPlayer);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationClickSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(Get.find<NotificationService>().syncScheduledNotifications());
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (Get.isRegistered<AudioService>()) {
        Get.find<AudioService>().persistSessionNow();
      }
    }
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      final isBtGranted = await Permission.bluetoothConnect.isGranted;

      if (!isBtGranted) {
        await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final themeCtrl = Get.find<ThemeController>();
      final palette = themeCtrl.palette.value;
      final mode = themeCtrl.themeMode.value;

      return GetMaterialApp(
        title: tr('app.name'),
        debugShowCheckedModeBanner: false,
        initialRoute: AppRoutes.entry,
        getPages: AppPages.routes,
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,

        navigatorObservers: [_playbackNavigationObserver],

        builder: (context, child) {
          if (child == null) {
            return const SizedBox.shrink();
          }

          final safeBottom = MediaQuery.of(context).padding.bottom;
          final bottomOffset = safeBottom + kBottomNavigationBarHeight + 12;

          return Stack(
            children: [
              child,
              const DownloadProgressBanner(),
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomOffset,
                child: const MiniPlayerBar(),
              ),
            ],
          );
        },

        // ✅ Theming correcto
        theme: buildTheme(palette: palette, brightness: Brightness.light),
        darkTheme: buildTheme(palette: palette, brightness: Brightness.dark),
        themeMode: mode,
      );
    });
  }
}
