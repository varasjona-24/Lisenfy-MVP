import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart' as aud;
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/bindings/app_binding.dart';
import 'app/bootstrap/app_bootstrap.dart';
import 'app/controllers/navigation_controller.dart';
import 'app/controllers/theme_controller.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/ui/themes/app_theme_factory.dart';
import 'app/ui/widgets/player/mini_player_bar.dart';
import 'app/ui/widgets/download/download_progress_banner.dart';
import 'app/services/audio_service.dart';
import 'app/services/deep_link_service.dart';
import 'app/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await AppBootstrap.initialize();
  AppBinding(bootstrap).dependencies();

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

        routingCallback: (routing) {
          final current = routing?.current;
          if (current != null) {
            Get.find<NavigationController>().setRoute(current);
          }
        },

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
