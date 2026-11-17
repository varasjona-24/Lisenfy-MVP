import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Translations;
import 'package:listenfy/Modules/player/audio/controller/audio_player_controller.dart';
import 'package:listenfy/app/controllers/media_actions_controller.dart';
import 'package:listenfy/app/data/local/local_library_store.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/ui/widgets/forms/app_option_selector.dart';

MediaItem _song(String id) => MediaItem.fromJson({
  'id': id,
  'publicId': id,
  'title': id,
  'variants': [
    {
      'kind': 'audio',
      'format': 'mp3',
      'fileName': '$id.mp3',
      'localPath': '/media/$id.mp3',
    },
  ],
});

class _Store extends GetxService implements LocalLibraryStore {
  final items = [_song('First'), _song('Second'), _song('Third')];
  @override
  Future<List<MediaItem>> readAll() async => items;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Player extends GetxController implements AudioPlayerController {
  @override
  final queue = <MediaItem>[].obs;
  @override
  MediaItem? get currentItemOrNull => _song('First');
  List<MediaItem> added = [], rebuilt = [];
  @override
  Future<void> addToQueue(List<MediaItem> items) async {
    added = items;
  }

  @override
  Future<void> replaceQueue(List<MediaItem> items, int index) async {
    rebuilt = items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(
    () => Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    ),
  );
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());
  void viewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
    testWidgets(
      'preference selector keeps selection and uses the appropriate panel on $platform',
      (tester) async {
        viewport(tester);
        var value = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppOptionSelector<int>(
                value: 1,
                options: const {1: 'First', 2: 'Second'},
                onChanged: (v) => value = v,
                icon: Icons.settings,
                title: 'Preference',
              ),
            ),
          ),
        );
        await tester.tap(find.byType(AppOptionSelector<int>));
        await tester.pumpAndSettle();
        expect(
          find.byType(Dialog),
          platform == TargetPlatform.macOS ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(BottomSheet),
          platform == TargetPlatform.android ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.text('Second'));
        await tester.pumpAndSettle();
        expect(value, 2);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
  for (final rebuild in [false, true]) {
    testWidgets(
      'queue action panels preserve ${rebuild ? 'rebuild' : 'append'} behavior',
      (tester) async {
        viewport(tester);
        Get.put<LocalLibraryStore>(_Store());
        final player = Get.put<AudioPlayerController>(_Player()) as _Player;
        final actions = Get.put(MediaActionsController());
        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      actions.showItemActions(context, _song('Second')),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add to queue'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        await tester.tap(
          find.text(
            rebuild ? 'Build a new queue' : 'Keep queue and add to end',
          ),
        );
        await tester.pumpAndSettle();
        if (rebuild) {
          expect(find.byType(Dialog), findsOneWidget);
          expect(find.byType(BottomSheet), findsNothing);
          await tester.enterText(find.byType(TextField), 'Third');
          await tester.pumpAndSettle();
          await tester.tap(find.byType(Checkbox));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Use 3 songs'));
          await tester.pumpAndSettle();
          expect(player.rebuilt.map((item) => item.id), [
            'First',
            'Second',
            'Third',
          ]);
        } else {
          expect(player.added.single.id, 'Second');
        }
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
        Get.closeAllSnackbars();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }
}
