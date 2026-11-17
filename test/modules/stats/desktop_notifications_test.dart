import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/app/routes/app_routes.dart';
import 'package:listenfy/app/services/notification_service.dart';

class _MemoryStorage implements GetStorage {
  final values = <String, dynamic>{};
  @override
  T? read<T>(String key) => values[key] as T?;
  @override
  Future<void> write(String key, dynamic value) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MacNotifications extends MacOSFlutterLocalNotificationsPlugin {
  bool granted = true;
  int requests = 0;

  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool providesAppNotificationSettings = false,
  }) async {
    requests++;
    return granted;
  }

  @override
  Future<NotificationsEnabledOptions?> checkPermissions() async =>
      NotificationsEnabledOptions(
        isEnabled: granted,
        isSoundEnabled: granted,
        isAlertEnabled: granted,
        isBadgeEnabled: granted,
        isProvisionalEnabled: false,
        isCriticalEnabled: false,
        isProvidesAppNotificationSettingsEnabled: false,
      );
}

class _Notifications implements FlutterLocalNotificationsPlugin {
  final mac = _MacNotifications();
  InitializationSettings? settings;
  DidReceiveNotificationResponseCallback? response;
  NotificationAppLaunchDetails? launchDetails;
  bool initialized = true;
  bool fail = false;
  bool failShow = false;
  final shown = <({String? payload, NotificationDetails? details})>[];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    if (fail) throw PlatformException(code: 'registration');
    this.settings = settings;
    response = onDidReceiveNotificationResponse;
    return initialized;
  }

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => T == MacOSFlutterLocalNotificationsPlugin ? mac as T : null;

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => launchDetails;

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    if (failShow) throw PlatformException(code: 'show');
    shown.add((payload: payload, details: notificationDetails));
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GetStorage storage;
  late _Notifications plugin;

  setUp(() {
    Get.testMode = true;
    storage = _MemoryStorage();
    plugin = _Notifications();
  });

  tearDown(() {
    Get.reset();
  });

  NotificationService service(TargetPlatform platform) =>
      NotificationService(plugin: plugin, storage: storage, platform: platform);

  test(
    'macOS defers permission until requested even when initialize returns false',
    () async {
      plugin.initialized = false;
      final notifications = await service(TargetPlatform.macOS).init();
      expect(plugin.settings!.macOS!.requestAlertPermission, isFalse);
      expect(plugin.mac.requests, 0);
      expect(await notifications.requestPermission(), isTrue);
      expect(plugin.mac.requests, 1);
      plugin.mac.granted = false;
      expect(await notifications.requestPermission(), isFalse);
    },
  );

  test(
    'Windows has stable registration and no mobile permission request',
    () async {
      final notifications = await service(TargetPlatform.windows).init();
      expect(plugin.settings!.windows!.appName, 'Listenfy');
      expect(plugin.settings!.windows!.appUserModelId, 'com.jv24dev.listenfy');
      expect(
        plugin.settings!.windows!.guid,
        matches(RegExp(r'^[a-f0-9-]{36}$')),
      );
      expect(await notifications.requestPermission(), isTrue);
      expect(plugin.mac.requests, 0);
    },
  );

  test(
    'failed Windows registration does not enable posting or prevent startup',
    () async {
      plugin.initialized = false;
      final notifications = await service(TargetPlatform.windows).init();
      await storage.write(NotificationService.masterEnabledKey, true);
      expect(await notifications.requestPermission(), isFalse);
      await notifications.showImportSuccess();
      expect(plugin.shown, isEmpty);
      plugin.fail = true;
      await notifications.init();
      expect(await notifications.requestPermission(), isFalse);
    },
  );

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    test(
      'master/category preferences and desktop details on $platform',
      () async {
        final notifications = await service(platform).init();
        await notifications.showImportSuccess();
        expect(plugin.shown, isEmpty);
        await storage.write(NotificationService.masterEnabledKey, true);
        await storage.write(NotificationService.importsEnabledKey, false);
        await notifications.showImportSuccess();
        expect(plugin.shown, isEmpty);
        await storage.write(NotificationService.importsEnabledKey, true);
        await notifications.showImportSuccess();
        await notifications.showImportFailure('failed');
        await notifications.showGeneratedVariantSuccess(
          variant: GeneratedAudioVariantKind.instrumental,
          mediaTitle: 'Song',
        );
        await notifications.showConnectRequest('Phone');
        await notifications.showSleepTimerFinished();
        expect(plugin.shown.length, 5);
        expect(plugin.shown.first.payload, AppRoutes.downloads);
        expect(
          plugin.shown.every(
            (item) =>
                item.details!.macOS != null &&
                item.details!.windows != null &&
                item.details!.android != null,
          ),
          isTrue,
        );
      },
    );
  }

  test(
    'revoked macOS permission does not consume a recommendation cycle',
    () async {
      final notifications = await service(TargetPlatform.macOS).init();
      await storage.write(NotificationService.masterEnabledKey, true);
      await storage.write(NotificationService.recommendationsEnabledKey, true);
      plugin.mac.granted = false;
      Future<void> notify() => notifications.showRecommendationCycle(
        cycleKey: 'cycle-1',
        mixTitle: 'Mix',
        mixSubtitle: '',
        trackCount: 5,
      );
      await notify();
      expect(plugin.shown, isEmpty);
      plugin.mac.granted = true;
      await notify();
      await notify();
      expect(plugin.shown.length, 1);
    },
  );

  testWidgets('cold notification launch focuses window and opens its section', (
    tester,
  ) async {
    plugin.launchDetails = const NotificationAppLaunchDetails(
      true,
      notificationResponse: NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: AppRoutes.downloads,
      ),
    );
    final notifications = await service(TargetPlatform.windows).init();
    final calls = <String>[];
    const channel = MethodChannel('window_manager');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      if (call.method == 'isMinimized') return true;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: Text('Home')),
        getPages: [
          GetPage(
            name: AppRoutes.downloads,
            page: () => const Scaffold(body: Text('Imports target')),
          ),
        ],
      ),
    );
    notifications.flushPendingNavigation();
    await tester.pumpAndSettle();
    expect(calls, ['isMinimized', 'restore', 'show', 'focus']);
    expect(find.text('Imports target'), findsOneWidget);
    // A click while already on the target still brings the window forward.
    expect(Get.context, isNotNull);
    plugin.response!(
      const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: AppRoutes.downloads,
      ),
    );
    await tester.pumpAndSettle();
    expect(calls.where((call) => call == 'focus').length, 2);
    expect(find.text('Imports target'), findsOneWidget);
  });
}
