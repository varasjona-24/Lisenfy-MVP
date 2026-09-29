import 'package:audio_service/audio_service.dart' as aud;
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';

import '../services/app_audio_handler.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';

/// Performs the asynchronous initialization required before the widget tree
/// and GetX dependency graph are created.
class AppBootstrap {
  const AppBootstrap._({
    required this.audioService,
    required this.notificationService,
  });

  final AudioService audioService;
  final NotificationService notificationService;

  static Future<AppBootstrap> initialize() async {
    await EasyLocalization.ensureInitialized();
    await GetStorage.init();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    final notificationService = await NotificationService().init();
    final audioService = AudioService();
    await audioService.initializeAndroidAutoArtwork();

    final handler = await aud.AudioService.init(
      builder: () => AppAudioHandler(audioService),
      config: const aud.AudioServiceConfig(
        androidNotificationChannelId: 'com.jv24dev.listenfy.audio',
        androidNotificationChannelName: 'Reproducción',
        androidNotificationChannelDescription: 'Controles de reproducción',
        androidNotificationOngoing: true,
        androidNotificationIcon: 'drawable/ic_listenfy_notification',
        preloadArtwork: true,
      ),
    );
    audioService.attachHandler(handler);

    return AppBootstrap._(
      audioService: audioService,
      notificationService: notificationService,
    );
  }
}
