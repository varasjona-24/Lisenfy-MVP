import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Translations;
import 'package:listenfy/Modules/captures/controller/capture_gallery_controller.dart';
import 'package:listenfy/Modules/captures/data/capture_gallery_store.dart';
import 'package:listenfy/Modules/captures/domain/capture_gallery_models.dart';
import 'package:listenfy/Modules/captures/ui/capture_action_sheet.dart';
import 'package:listenfy/Modules/captures/ui/capture_cover_target_sheet.dart';
import 'package:listenfy/Modules/captures/ui/capture_sort_sheet.dart';
import 'package:listenfy/Modules/captures/ui/capture_tile.dart';
import 'package:listenfy/Modules/captures/services/capture_share_service.dart';
import 'package:listenfy/Modules/captures/services/capture_cover_service.dart';
import 'package:listenfy/Modules/captures/view/capture_gallery_page.dart';
import 'package:listenfy/Modules/captures/view/capture_tags_page.dart';

class _Store implements CaptureGalleryStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends CaptureGalleryController {
  _Controller()
    : super(
        galleryStore: _Store(),
        shareService: const CaptureShareService(),
        coverService: const CaptureCoverService(),
      );
  String? applied;
  @override
  Future<void> reload() async {
    captures.assignAll(
      List.generate(
        8,
        (i) => CaptureItem(
          path: '/missing/capture-$i.png',
          name: 'Capture $i',
          modifiedAt: DateTime(2026, 1, i + 1),
          size: 100,
          tags: ['Tag $i'],
        ),
      ),
    );
    isLoading.value = false;
  }

  @override
  Future<List<CaptureCoverTarget>> loadCoverTargets() async => const [
    CaptureCoverTarget(
      id: 'video',
      label: 'My video',
      subtitle: 'Video',
      type: CaptureCoverTargetType.video,
    ),
  ];
  @override
  Future<void> applyCover({
    required CaptureItem capture,
    required CaptureCoverTarget target,
  }) async {
    applied = target.id;
  }
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
  setUp(() {
    Get.testMode = true;
  });
  tearDown(() async {
    Get.reset();
  });

  Future<_Controller> open(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(1440, 900),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller =
        Get.put<CaptureGalleryController>(_Controller()) as _Controller;
    await tester.pumpWidget(
      GetMaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> rightClick(WidgetTester tester, Finder finder) async {
    final gesture = await tester.startGesture(
      tester.getCenter(finder),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  }

  void centered(WidgetTester tester) {
    final rect = tester.getRect(find.byType(Dialog));
    expect(rect.center.dx, closeTo(tester.view.physicalSize.width / 2, 1));
    expect(rect.center.dy, closeTo(tester.view.physicalSize.height / 2, 1));
  }

  for (final size in [const Size(1440, 900), const Size(900, 650)]) {
    testWidgets(
      'desktop captures grid, right click, selection and sort at $size',
      (tester) async {
        final controller = await open(
          tester,
          const CaptureGalleryPage(),
          size: size,
          scale: 1.3,
        );
        final tiles = find.byType(CaptureTile);
        expect(tiles, findsWidgets);
        final positions = tester.getRect(tiles.first);
        expect(positions.width, lessThanOrEqualTo(340));
        expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
        if (size.width == 1440) {
          final xs = tester.getRect(tiles.at(2)).top;
          expect(xs, tester.getRect(tiles.first).top);
        }
        await rightClick(tester, tiles.first);
        expect(find.byType(CaptureActionSheet), findsOneWidget);
        centered(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        await tester.tap(find.byType(Checkbox).first);
        await tester.pumpAndSettle();
        expect(controller.selectedCount, 1);
        controller.clearSelection();
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(OutlinedButton, 'Sort'));
        await tester.pumpAndSettle();
        expect(find.byType(CaptureSortSheet), findsOneWidget);
        centered(tester);
        await tester.tap(find.text('Name'));
        await tester.pumpAndSettle();
        expect(controller.sort.value, CaptureSort.name);
        await tester.tap(find.text('Accept'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }

  testWidgets(
    'desktop cover picker stays centered and applies the selected target',
    (tester) async {
      final controller = await open(tester, const CaptureGalleryPage());
      await rightClick(tester, find.byType(CaptureTile).first);
      await tester.tap(find.text('Use as cover'));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureCoverTargetSheet), findsOneWidget);
      centered(tester);
      await tester.tap(find.text('My video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply cover'));
      await tester.pumpAndSettle();
      expect(controller.applied, 'video');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'desktop tag folder supports right click and centered sorting',
    (tester) async {
      await open(tester, const CaptureTagsPage());
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      await rightClick(tester, find.text('Tag 0'));
      centered(tester);
      expect(find.text('Edit'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.sort_rounded).last);
      await tester.pumpAndSettle();
      centered(tester);
      expect(find.text('Sort tags'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  testWidgets(
    'mobile keeps two columns, long press selection and bottom sheet actions',
    (tester) async {
      final controller = await open(
        tester,
        const CaptureGalleryPage(),
        size: const Size(390, 844),
      );
      final tiles = find.byType(CaptureTile);
      expect(tester.getRect(tiles.first).top, tester.getRect(tiles.at(1)).top);
      expect(
        tester.getRect(tiles.at(2)).top,
        greaterThan(tester.getRect(tiles.first).top),
      );
      await tester.longPress(tiles.first);
      await tester.pumpAndSettle();
      expect(controller.selectedCount, 1);
      await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byType(CaptureActionSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
