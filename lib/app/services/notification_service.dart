import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../routes/app_routes.dart';

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

  static const _weeklyNotificationId = 4101;
  static const _recommendationsNotificationId = 4102;
  static const _importNotificationId = 4201;
  static const _connectNotificationId = 4202;
  static const _timerNotificationId = 4203;

  final FlutterLocalNotificationsPlugin _plugin;
  final GetStorage _storage = GetStorage();

  bool _initialized = false;
  String? _pendingPayload;

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  bool get isMasterEnabled => _storage.read<bool>(masterEnabledKey) ?? false;

  bool isCategoryEnabled(String key, {required bool defaultValue}) {
    return _storage.read<bool>(key) ?? defaultValue;
  }

  Future<NotificationService> init() async {
    if (!isSupported) return this;

    tz_data.initializeTimeZones();
    await _configureLocalTimezone();

    const android = AndroidInitializationSettings('ic_notification');
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
    if (isMasterEnabled) {
      await syncScheduledNotifications();
    }
    return this;
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
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

    if (isCategoryEnabled(weeklyEnabledKey, defaultValue: false)) {
      await _scheduleWeeklySummary();
    } else {
      await _plugin.cancel(id: _weeklyNotificationId);
    }

    if (isCategoryEnabled(recommendationsEnabledKey, defaultValue: false)) {
      await _scheduleDailyRecommendations();
    } else {
      await _plugin.cancel(id: _recommendationsNotificationId);
    }
  }

  Future<void> showImportSuccess() {
    return _showForCategory(
      categoryKey: importsEnabledKey,
      defaultValue: true,
      id: _importNotificationId,
      title: 'Importación finalizada',
      body: 'Tu archivo se agregó correctamente a la biblioteca.',
      payload: AppRoutes.downloads,
      details: _importsDetails,
    );
  }

  Future<void> showImportFailure(String message) {
    return _showForCategory(
      categoryKey: importsEnabledKey,
      defaultValue: true,
      id: _importNotificationId,
      title: 'Error de importación',
      body: message,
      payload: AppRoutes.downloads,
      details: _importsDetails,
    );
  }

  Future<void> showConnectRequest(String clientName) {
    return _showForCategory(
      categoryKey: connectEnabledKey,
      defaultValue: true,
      id: _connectNotificationId,
      title: 'Solicitud de conexión',
      body: '$clientName solicita acceso a Listenfy Connect.',
      payload: AppRoutes.localConnect,
      details: _connectDetails,
    );
  }

  Future<void> showConnectApproved(String clientName) {
    return _showForCategory(
      categoryKey: connectEnabledKey,
      defaultValue: true,
      id: _connectNotificationId,
      title: 'Dispositivo conectado',
      body: '$clientName se sincronizó correctamente con Listenfy.',
      payload: AppRoutes.localConnect,
      details: _connectDetails,
    );
  }

  Future<void> showSleepTimerFinished() {
    return _showForCategory(
      categoryKey: timersEnabledKey,
      defaultValue: true,
      id: _timerNotificationId,
      title: 'Temporizador finalizado',
      body: 'La reproducción se detuvo según el temporizador configurado.',
      payload: AppRoutes.audioPlayer,
      details: _timersDetails,
    );
  }

  Future<void> showInactivityPause() {
    return _showForCategory(
      categoryKey: timersEnabledKey,
      defaultValue: true,
      id: _timerNotificationId,
      title: 'Reproducción pausada',
      body: 'La reproducción se pausó después de un periodo sin actividad.',
      payload: AppRoutes.audioPlayer,
      details: _timersDetails,
    );
  }

  Future<void> _showForCategory({
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
      return;
    }
    if (!_initialized) {
      _debugLog('notification $id skipped: service not initialized');
      return;
    }
    if (!isMasterEnabled) {
      _debugLog('notification $id skipped: master setting disabled');
      return;
    }
    if (!isCategoryEnabled(categoryKey, defaultValue: defaultValue)) {
      _debugLog('notification $id skipped: category $categoryKey disabled');
      return;
    }
    if (!await _canPostNotification(details)) {
      return;
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
    } catch (error, stackTrace) {
      _debugLog('notification $id failed: $error');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
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

  Future<void> _scheduleWeeklySummary() async {
    final scheduledDate = _nextWeekday(weekday: DateTime.sunday, hour: 19);
    try {
      await _plugin.cancel(id: _weeklyNotificationId);
      await _plugin.zonedSchedule(
        id: _weeklyNotificationId,
        title: 'Tu resumen semanal está listo',
        body:
            'Descubre tus canciones, artistas y hábitos de escucha de esta semana.',
        scheduledDate: scheduledDate,
        notificationDetails: _weeklyDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: AppRoutes.listeningStats,
      );
      _debugLog('weekly summary scheduled for $scheduledDate');
    } catch (error, stackTrace) {
      _logSchedulingFailure('weekly summary', error, stackTrace);
    }
  }

  Future<void> _scheduleDailyRecommendations() async {
    final scheduledDate = _nextTime(hour: 9);
    try {
      await _plugin.cancel(id: _recommendationsNotificationId);
      await _plugin.zonedSchedule(
        id: _recommendationsNotificationId,
        title: 'Nuevos mixes para ti',
        body: 'Tus recomendaciones personalizadas ya están listas.',
        scheduledDate: scheduledDate,
        notificationDetails: _recommendationsDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: AppRoutes.home,
      );
      _debugLog('daily recommendations scheduled for $scheduledDate');
    } catch (error, stackTrace) {
      _logSchedulingFailure('daily recommendations', error, stackTrace);
    }
  }

  void _logSchedulingFailure(
    String notification,
    Object error,
    StackTrace stackTrace,
  ) {
    _debugLog('$notification scheduling failed: $error');
    if (kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  tz.TZDateTime _nextTime({required int hour, int minute = 0}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextWeekday({
    required int weekday,
    required int hour,
    int minute = 0,
  }) {
    var scheduled = _nextTime(hour: hour, minute: minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
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

  static const _importsDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'listenfy_imports',
      'Importaciones',
      channelDescription: 'Resultados de importaciones y descargas',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _connectDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'listenfy_connect',
      'Listenfy Connect',
      channelDescription: 'Solicitudes y sincronización de dispositivos',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _timersDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'listenfy_timers',
      'Reproducción y temporizadores',
      channelDescription: 'Temporizador de sueño y pausa por inactividad',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _weeklyDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'listenfy_weekly',
      'Resumen semanal de Listenfy',
      channelDescription: 'Resumen semanal de actividad en Listenfy',
    ),
    iOS: DarwinNotificationDetails(),
  );

  static const _recommendationsDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'listenfy_recommendations',
      'Mixes personalizados',
      channelDescription: 'Selección diaria de música recomendada',
    ),
    iOS: DarwinNotificationDetails(),
  );
}
