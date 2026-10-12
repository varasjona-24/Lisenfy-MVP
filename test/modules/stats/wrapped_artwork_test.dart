import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/Modules/stats/presentation/widgets/wrapped_artwork.dart';

MediaItem item({String? local}) => MediaItem.fromJson({
  'id': 'song',
  'title': 'A long song title for a favorite memory',
  'subtitle': 'An artist',
  'thumbnailLocalPath': local,
  'variants': [],
});

void main() {
  testWidgets(
    'aspect is explicit: audio stays square even with a video variant',
    (tester) async {
      final media = MediaItem.fromJson({
        'id': 'mixed',
        'title': 'Mixed',
        'variants': [
          {'kind': 'audio', 'localPath': '/a.mp3'},
          {'kind': 'video', 'localPath': '/v.mp4'},
        ],
      });
      for (final ratio in [1.0, 16 / 9]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: WrappedArtwork(
                  item: media,
                  size: 160,
                  aspectRatio: ratio,
                ),
              ),
            ),
          ),
        );
        final size = tester.getSize(find.byType(WrappedArtwork));
        expect(size.width / size.height, closeTo(ratio, .001));
      }
    },
  );
  testWidgets('video collage preserves widescreen thumbnails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: WrappedCoverStrip(
                items: [item(), item(), item()],
                aspectRatio: 16 / 9,
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      final size = tester.getSize(find.byType(WrappedArtwork).at(i));
      expect(size.width / size.height, closeTo(16 / 9, .001));
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('uses a real local artwork file without changing its identity', (
    tester,
  ) async {
    final media = item(local: File('assets/ui/vinyl.png').absolute.path);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WrappedArtwork(item: media)),
      ),
    );
    expect(tester.widget<Image>(find.byType(Image)).image, isA<FileImage>());
    expect(media.id, 'song');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing local cover falls back safely', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WrappedArtwork(item: item(local: '/missing-wrapped-cover.png')),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 760.0]) {
    testWidgets('spotlight adapts at $width with enlarged text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: SingleChildScrollView(
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: WrappedTrackSpotlight(
                      item: item(),
                      badge: 'Your favorite track',
                      caption: '120 plays',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(WrappedArtwork), findsOneWidget);
      expect(find.text('120 plays'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('cover collage is limited to three artworks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WrappedCoverStrip(items: List.generate(8, (_) => item())),
        ),
      ),
    );
    expect(find.byType(WrappedArtwork), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
