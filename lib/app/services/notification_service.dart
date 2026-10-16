import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../Modules/stats/application/weekly_listening_summary.dart';
import '../routes/app_routes.dart';

enum GeneratedAudioVariantKind { instrumental, spatial8d }

class NotificationService extends GetxService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const masterEnabledKey = 'notificationsEnabled';
  static const importsEnabledKey = 'notificationsImportsEnabled';
  static const connectEnabledKey = 'notificationsConnectEnabled';
  static const timersEnabledKey = 'notificationsTimersEnabled';
  static const weeklyEnabledKey = 'notificationsWeeklyEnabled';
  static const recommendationsEnabledKey =
      'notificationsRecommendationsEnabled';
  static const _lastRecommendationCycleKey =
      'notificationsRecommendationsLastCycle';
  static const _lastWeeklySummaryPeriodKey =
      'notificationsWeeklyLastSummaryPeriod';
  static const _dynamicNotificationMigrationKey =
      'notificationsDynamicContentMigrationV1';

  static const _weeklyNotificationId = 4101;
  static const _recommendationsNotificationId = 4102;
  static const _importNotificationId = 4201;
  static const _connectNotificationId = 4202;
  static const _timerNotificationId = 4203;

  final FlutterLocalNotificationsPlugin _plugin;
  final GetStorage _storage = GetStorage();

  bool _initialized = false;
  String? _pendingPayload;
  WeeklyListeningSummaryLoader? _weeklySummaryLoader;

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  bool get isMasterEnabled => _storage.read<bool>(masterEnabledKey) ?? false;

  bool isCategoryEnabled(String key, {required bool defaultValue}) {
    return _storage.read<bool>(key) ?? defaultValue;
  }

  void configureWeeklySummaryLoader(WeeklyListeningSummaryLoader loader) {
    _weeklySummaryLoader = loader;
  }

  Future<NotificationService> init() async {
    if (!isSupported) return this;

    const android = AndroidInitializationSettings('ic_listenfy_notification');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: iOS);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingPayload = launchDetails?.notificationResponse?.payload;
    }

    _initialized = true;
    return this;
  }

  Future<bool> requestPermission() async {
    if (!isSupported || !_initialized) return false;

    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }

    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  Future<void> syncScheduledNotifications() async {
    if (!isSupported || !_initialized) return;

    if (!isMasterEnabled) {
      await _plugin.cancel(id: _weeklyNotificationId);
      await _plugin.cancel(id: _recommendationsNotificationId);
      return;
    }

    await _clearLegacySchedules();

    if (isCategoryEnabled(weeklyEnabledKey, defaultValue: false)) {
      await _showWeeklySummaryIfDue();
    } else {
      await _plugin.cancel(id: _weeklyNotificationId);
    }

    if (!isCategoryEnabled(recommendationsEnabledKey, defaultValue: false)) {
      await _plugin.cancel(id: _recommendationsNotificationId);
    }
  }

  Future<void> showImportSuccess() async {
    await _showForCategory(
      categoryKey: importsEnabledKey,
      defaultValue: true,
      id: _importNotificationId,
      title: tr('notifications.imports.success_title'),
      body: tr('notifications.imports.success_body'),
      payload: AppRoutes.downloads,
      details: _importsDetails,
    );
  }

  Future<void> showImportFailure(String message) async {
    await _showForCategory(
      categoryKey: importsEnabledKey,
      defaultValue: true,
      id: _importNotificationId,
      title: tr('notifications.imports.failure_title'),
      body: message,
      payload: AppRoutes.downloads,
      details: _importsDetails,
    );
  }

  Future<void> showGeneratedVariantSuccess({
    required GeneratedAudioVariantKind variant,
    required String mediaTitle,
  }) async {
    final title = mediaTitle.trim();
    if (title.isEmpty) return;
    await _showForCategory(
      categoryKey: importsEnabledKey,
      defaultValue: true,
      id: _importNotificationId,
      title: tr('notifications.imports.variant_success_title'),
      body: tr(
        'notifications.imports.variant_success_body',
        args: [_generatedVariantLabel(variant), title],
      ),
      payload: AppRoutes.home,
      details: _importsDetails,
    );
  }

  Future<void> showGeneratedVariantFailure({
    required GeneratedAudioVariantKind variant,
    required String mediaTitle,
    required String message,
  }) async {
    final title = mediaTitle.trim();
    if (title.isEmpty) return;
    final detail = message.trim();
    await _showForCategory(
      categoryKey: importsEnabledKey,
      defaultValue: true,
      id: _importNotificationId,
      title: tr('notifications.imports.variant_failure_title'),
      body: tr(
        'notifications.imports.variant_failure_body',
        args: [
          _generatedVariantLabel(variant),
          title,
          detail.isEmpty
              ? tr('notifications.imports.variant_failure_fallback')
              : detail,
        ],
      ),
      payload: AppRoutes.home,
      details: _importsDetails,
    );
  }

  String _generatedVariantLabel(GeneratedAudioVariantKind variant) {
    return switch (variant) {
      GeneratedAudioVariantKind.instrumental =>
        tr('notifications.imports.variant_instrumental'),
      GeneratedAudioVariantKind.spatial8d =>
        tr('notifications.imports.variant_spatial8d'),
    };
  }

  Future<void> showConnectRequest(String clientName) async {
    await _showForCategory(
      categoryKey: connectEnabledKey,
      defaultValue: true,
      id: _connectNotificationId,
      title: tr('notifications.connect.request_title'),
      body: tr('notifications.connect.request_body', args: [clientName]),
      payload: AppRoutes.localConnect,
      details: _connectDetails,
    );
  }

  Future<void> showConnectApproved(String clientName) async {
    await _showForCategory(
      categoryKey: connectEnabledKey,
      defaultValue: true,
      id: _connectNotificationId,
      title: tr('notifications.connect.approved_title'),
      body: tr('notifications.connect.approved_body', args: [clientName]),
      payload: AppRoutes.localConnect,
      details: _connectDetails,
    );
  }

  Future<void> showSleepTimerFinished() async {
    await _showForCategory(
      categoryKey: timersEnabledKey,
      defaultValue: true,
      id: _timerNotificationId,
      title: tr('notifications.timers.sleep_title'),
      body: tr('notifications.timers.sleep_body'),
      payload: AppRoutes.audioPlayer,
      details: _timersDetails,
    );
  }

  Future<void> showInactivityPause() async {
    await _showForCategory(
      categoryKey: timersEnabledKey,
      defaultValue: true,
      id: _timerNotificationId,
      title: tr('notifications.timers.inactivity_title'),
      body: tr('notifications.timers.inactivity_body'),
      payload: AppRoutes.audioPlayer,
      details: _timersDetails,
    );
  }

  /// Publishes a preview of a mix that has already been generated locally.
  /// [cycleKey] changes with the recommendation rotation, so a loaded home
  /// page cannot emit the same notification repeatedly.
  Future<void> showRecommendationCycle({
    required String cycleKey,
    required String mixTitle,
    required String mixSubtitle,
    required int trackCount,
  }) async {
    final normalizedCycleKey = cycleKey.trim();
    final normalizedTitle = mixTitle.trim();
    if (normalizedCycleKey.isEmpty || normalizedTitle.isEmpty) return;
    if ((_storage.read<String>(_lastRecommendationCycleKey) ?? '') ==
        normalizedCycleKey) {
      return;
    }

    final normalizedSubtitle = mixSubtitle.trim();
    final normalizedCount = trackCount < 0 ? 0 : trackCount;
    final body = normalizedSubtitle.isEmpty
        ? tr(
            'notifications.recommendations.cycle_body',
            args: [normalizedTitle, '$normalizedCount'],
          )
        : tr(
            'notifications.recommendations.cycle_body_with_subtitle',
            args: [normalizedTitle, '$normalizedCount', normalizedSubtitle],
          );
    final published = await _showForCategory(
      categoryKey: recommendationsEnabledKey,
      defaultValue: false,
      id: _recommendationsNotificationId,
      title: tr('notifications.recommendations.cycle_title'),
      body: body,
      payload: AppRoutes.home,
      details: _recommendationsDetails,
    );
    if (published) {
      await _storage.write(_lastRecommendationCycleKey, normalizedCycleKey);
    }
  }

  Future<bool> _showForCategory({
    required String categoryKey,
    required bool defaultValue,
    required int id,
    required String title,
    required String body,
    required String payload,
    required NotificationDetails details,
  }) async {
    if (!isSupported) {
      _debugLog('notification $id skipped: unsupported platform');
      return false;
    }
    if (!_initialized) {
      _debugLog('notification $id skipped: service not initialized');
      return false;
    }
    if (!isMasterEnabled) {
      _debugLog('notification $id skipped: master setting disabled');
      return false;
    }
    if (!isCategoryEnabled(categoryKey, defaultValue: defaultValue)) {
      _debugLog('notification $id skipped: category $categoryKey disabled');
      return false;
    }
    if (!await _canPostNotification(details)) {
      return false;
    }

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: details,
      );
      _debugLog('notification $id published: $title');
      return true;
    } catch (error, stackTrace) {
      _debugLog('notification $id failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      return false;
    }
  }

  Future<bool> _canPostNotification(NotificationDetails details) async {
    if (!Platform.isAndroid) return true;

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) {
        _debugLog('notification skipped: Android implementation unavailable');
        return false;
      }

      final appNotificationsEnabled =
          await android.areNotificationsEnabled() ?? false;
      if (!appNotificationsEnabled) {
        _debugLog(
          'notification skipped: Android notifications permission is disabled',
        );
        return false;
      }

      final channelId = details.android?.channelId;
      if (channelId == null || channelId.isEmpty) return true;

      final channels = await android.getNotificationChannels();
      final channel = channels
          ?.where((item) => item.id == channelId)
          .firstOrNull;
      if (channel?.importance == Importance.none) {
        _debugLog(
          'notification skipped: Android channel $channelId is disabled',
        );
        return false;
      }
    } catch (error) {
      _debugLog('could not inspect Android notification settings: $error');
    }
    return true;
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[Notifications] $message');
    }
  }

  Future<void> _clearLegacySchedules() async {
    if (_storage.read<bool>(_dynamicNotificationMigrationKey) == true) return;
    try {
      await _plugin.cancel(id: _weeklyNotificationId);
      await _plugin.cancel(id: _recommendationsNotificationId);
      await _storage.write(_dynamicNotificationMigrationKey, true);
      _debugLog('legacy scheduled notifications cleared');
    } catch (error, stackTrace) {
      _debugLog('legacy notification cleanup failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> _showWeeklySummaryIfDue() async {
    final now = DateTime.now();
    final isSundayEvening = now.weekday == DateTime.sunday && now.hour >= 19;
    final isMondayMorning = now.weekday == DateTime.monday && now.hour < 12;
    if (!isSundayEvening && !isMondayMorning) return;

    final loader = _weeklySummaryLoader;
    if (loader == null) return;
    try {
      final summary = await loader(now);
      if (summary == null) return;
      if ((_storage.read<String>(_lastWeeklySummaryPeriodKey) ?? '') ==
          summary.periodKey) {
        return;
      }

      final artist = summary.topArtistName?.trim() ?? '';
      final body = summary.listenedMinutes > 0
          ? artist.isEmpty
                ? tr(
                    'notifications.weekly.body_with_time',
                    args: [
                      '${summary.sessionCount}',
                      '${summary.listenedMinutes}',
                      '${summary.uniqueTrackCount}',
                    ],
                  )
                : tr(
                    'notifications.weekly.body_with_time_and_artist',
                    args: [
                      '${summary.sessionCount}',
                      '${summary.listenedMinutes}',
                      '${summary.uniqueTrackCount}',
                      artist,
                    ],
                  )
          : artist.isEmpty
          ? tr(
              'notifications.weekly.body',
              args: ['${summary.sessionCount}', '${summary.uniqueTrackCount}'],
            )
          : tr(
              'notifications.weekly.body_with_artist',
              args: [
                '${summary.sessionCount}',
                '${summary.uniqueTrackCount}',
                artist,
              ],
            );
      final published = await _showForCategory(
        categoryKey: weeklyEnabledKey,
        defaultValue: false,
        id: _weeklyNotificationId,
        title: tr('notifications.weekly.title'),
        body: body,
        payload: AppRoutes.listeningStats,
        details: _weeklyDetails,
      );
      if (published) {
        await _storage.write(_lastWeeklySummaryPeriodKey, summary.periodKey);
      }
    } catch (error, stackTrace) {
      _debugLog('weekly summary generation failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  void flushPendingNavigation() {
    final payload = _pendingPayload;
    if (payload == null || payload.isEmpty) return;
    _pendingPayload = null;
    _navigate(payload);
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    if (Get.context == null) {
      _pendingPayload = payload;
      return;
    }
    _navigate(payload);
  }

  void _navigate(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.currentRoute == route) return;
      Get.toNamed(route);
    });
  }

  static NotificationDetails get _importsDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      'listenfy_imports',
      tr('notifications.imports.channel_name'),
      channelDescription: tr('notifications.imports.channel_description'),
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  static NotificationDetails get _connectDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      'listenfy_connect',
      tr('notifications.connect.channel_name'),
      channelDescription: tr('notifications.connect.channel_description'),
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  static NotificationDetails get _timersDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      'listenfy_timers',
      tr('notifications.timers.channel_name'),
      channelDescription: tr('notifications.timers.channel_description'),
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  static NotificationDetails get _weeklyDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      'listenfy_weekly',
      tr('notifications.weekly.channel_name'),
      channelDescription: tr('notifications.weekly.channel_description'),
    ),
    iOS: const DarwinNotificationDetails(),
  );

  static NotificationDetails get _recommendationsDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      'listenfy_recommendations',
      tr('notifications.recommendations.channel_name'),
      channelDescription: tr(
        'notifications.recommendations.channel_description',
      ),
    ),
    iOS: const DarwinNotificationDetails(),
  );
}
