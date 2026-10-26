import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/nearby_transfer/view/nearby_transfer_page.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/app/models/media_item.dart';

void main() {
  final item = MediaItem(
    id: 'mixed',
    publicId: 'mixed',
    title: 'Song',
    subtitle: 'Artist',
    source: MediaSource.local,
    origin: SourceOrigin.device,
    thumbnailLocalPath: '/missing-cover.jpg',
    variants: [
      for (final kind in MediaVariantKind.values)
        MediaVariant(
          kind: kind,
          format: kind == MediaVariantKind.audio ? 'mp3' : 'mp4',
          fileName: kind.name,
          createdAt: 1,
          localPath: '/${kind.name}',
        ),
    ],
  );
  for (final brightness in Brightness.values) {
    testWidgets('picker artwork and selection in $brightness', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: TransferLibraryPicker(items: [item], preselected: const []),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final audio = tester.getSize(
        find.byKey(const ValueKey('transfer-cover-mixed-audio')),
      );
      final video = tester.getSize(
        find.byKey(const ValueKey('transfer-cover-mixed-video')),
      );
      expect(audio.width / audio.height, 1);
      expect(video.width / video.height, closeTo(16 / 9, .001));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'artist');
      await tester.pump();
      expect(find.byType(Checkbox), findsNWidgets(2));
      await tester.enterText(find.byType(TextField), 'not found');
      await tester.pump();
      expect(find.byType(Checkbox), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isTrue,
      );
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isFalse,
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isTrue);
    });
  }
}
