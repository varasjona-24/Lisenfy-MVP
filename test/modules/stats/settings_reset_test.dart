import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/Modules/Home/Controller/home_controller.dart';
import 'package:listenfy/Modules/settings/controller/settings_controller.dart';

class _Preferences implements GetStorage {
  final values = <String, dynamic>{};
  @override
  T? read<T>(String key) => values[key] as T?;
  @override
  Future<void> write(String key, dynamic value) async => values[key] = value;
  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('listenfy/app_icon');
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'installed version and update time come from package metadata',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => {
              'version': '1.2.3',
              'build': '42',
              'updatedAt': 1792400000000,
            },
          );
      final settings = SettingsController(storage: _Preferences());
      await settings.loadInstalledAppInfo();
      expect(settings.installedVersion.value, '1.2.3 (42)');
      expect(
        settings.installedUpdatedAt.value!.millisecondsSinceEpoch,
        1792400000000,
      );
    },
  );
  test(
    'wallpapers can be disabled and enabled without deleting selections',
    () async {
      final prefs = _Preferences()
        ..values.addAll({
          'appBackgroundImagePaths': ['saved.jpg'],
          'appBackgroundImagePath': 'saved.jpg',
        });
      final settings = SettingsController(storage: prefs);
      await settings.setAppBackgroundEnabled(false);
      expect(settings.appBackgroundEnabled.value, isFalse);
      expect(prefs.values['appBackgroundImagePaths'], ['saved.jpg']);
      expect(prefs.values['appBackgroundImagePath'], 'saved.jpg');
      await settings.setAppBackgroundEnabled(true);
      expect(prefs.values['appBackgroundEnabled'], isTrue);
    },
  );
  test('Home reset hides shortcuts but keeps targets in both modes', () async {
    final prefs = _Preferences()
      ..values.addAll({
        'home_widget_order': ['randomMix'],
        'home_custom_sections': [
          {'id': 'artists_custom', 'targetId': 'a|b', 'enabled': true},
        ],
        'video_home_custom_sections': [
          {'id': 'collections_custom', 'targetId': 'c', 'enabled': true},
        ],
        'unrelated': 123,
      });
    await HomeController.resetSavedHomeLayout(preferences: prefs);
    expect(prefs.values.containsKey('home_widget_order'), isFalse);
    for (final key in ['home_custom_sections', 'video_home_custom_sections']) {
      final section = (prefs.values[key] as List).single as Map;
      expect(section['enabled'], isFalse);
      expect(section['targetId'], key.startsWith('video') ? 'c' : 'a|b');
    }
    expect(prefs.values['unrelated'], 123);
  });
}
