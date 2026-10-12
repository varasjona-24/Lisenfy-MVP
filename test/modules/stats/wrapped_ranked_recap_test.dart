import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/artists/domain/artist_profile.dart';
import 'package:listenfy/Modules/stats/application/wrapped_artist_artwork.dart';
import 'package:listenfy/Modules/stats/domain/entities/listening_stats_entities.dart';
import 'package:listenfy/Modules/stats/presentation/views/listening_stats_page.dart';
import 'package:listenfy/Modules/stats/presentation/widgets/wrapped_artwork.dart';
import 'package:listenfy/app/models/media_item.dart';

MediaItem song(
  String id, {
  String artist = 'Artist',
  int plays = 1,
  bool favorite = false,
  String? cover,
}) => MediaItem.fromJson({
  'id': id,
  'title': id,
  'subtitle': artist,
  'playCount': plays,
  'isFavorite': favorite,
  'thumbnailLocalPath': cover,
  'variants': [
    {
      'kind': 'audio',
      'format': 'mp3',
      'fileName': '$id.mp3',
      'localPath': '/$id.mp3',
    },
  ],
});

void main() {
  test(
    'listened rate mixes sources while the lower comparison stays observed',
    () {
      final stats = ListeningStats.fromItems(
        [],
        audioCompletionSummary: const {
          'legacyCompleted': 10,
          'legacyEstimated': 70,
          'legacySkips': 15,
          'samples': 20,
          'completed': 10,
          'skips': 5,
        },
      );
      expect(stats.combinedListened, 90);
      expect(stats.combinedSkips, 20);
      expect(stats.listenedRate, closeTo(90 / 110, .0001));
      expect(stats.observedCompleted, 10);
      expect(stats.observedSkips, 5);
      expect(ListeningStats.fromItems([]).listenedRate, 0);
    },
  );
  test('Wrapped sizes use decimal units for base 1000', () {
    for (final entry in {
      0: '0 B',
      999: '999 B',
      1000: '1.0 KB',
      1000000: '1.0 MB',
      1000000000: '1.0 GB',
      1073741824: '1.1 GB',
      1000000000000: '1.0 TB',
    }.entries) {
      final media = MediaItem.fromJson({
        'id': 'size',
        'title': 'Size',
        'variants': [
          {
            'kind': 'audio',
            'format': 'mp3',
            'fileName': 'size.mp3',
            'localPath': '/size.mp3',
            'size': entry.key,
          },
        ],
      });
      final stats = ListeningStats.fromItems([media]);
      expect(stats.totalImportSizeLabel, entry.value);
      expect(stats.audioImportSizeLabel, entry.value);
      expect(stats.averageFileSizeLabel, entry.value);
    }
  });
  test('mood mixes legacy once without changing verified metrics', () {
    final stats = ListeningStats.fromItems(
      [],
      audioCompletionSummary: const {
        'legacyPlays': 100,
        'legacyCompleted': 10,
        'legacyEstimated': 70,
        'samples': 20,
        'completed': 10,
      },
    );
    expect(stats.moodCompletionRatio, .75);
    expect(stats.moodIncludesEstimates, isTrue);
    expect(stats.observedCompleted, 10);
    expect(stats.observedCompletionSamples, 20);
    expect(stats.totalCompleted, 0);
  });
  test('new installation mood uses only observed sessions', () {
    final stats = ListeningStats.fromItems(
      [],
      audioCompletionSummary: const {'samples': 10, 'completed': 8},
    );
    expect(stats.moodCompletionRatio, .8);
    expect(stats.moodIncludesEstimates, isFalse);
    expect(ListeningStats.fromItems([]).moodCompletionRatio, 0);
  });
  test(
    'legacy estimates stay separate from explicit and observed completions',
    () {
      final stats = ListeningStats.fromItems(
        [song('legacy', plays: 100).copyWith(fullListenCount: 3)],
        audioCompletionSummary: const {
          'legacyPlays': 100,
          'legacyCompleted': 3,
          'legacyEstimated': 90,
          'samples': 22,
          'completed': 16,
        },
      );
      expect(stats.totalCompleted, 3);
      expect(stats.observedCompletionSamples, 22);
      expect(stats.observedCompleted, 16);
      expect(stats.audioCompletionSummary['legacyEstimated'], 90);
    },
  );
  test('favorite rate counts the whole audio library, not the top five', () {
    final items = List.generate(
      8,
      (i) => song('favorite-$i', favorite: true, plays: 0),
    );
    items.add(song('not-favorite', plays: 0));
    final stats = ListeningStats.fromItems(items);
    expect(stats.favoriteAudioCount, 8);
    expect(stats.importedAudioItems, 9);
    expect(stats.topFavoriteTracks, isEmpty);
  });
  test(
    'average requires session coverage, never historical per-song progress',
    () {
      final items = [song('legacy', plays: 100).copyWith(avgListenProgress: 1)];
      final legacy = ListeningStats.fromItems(items);
      expect(legacy.hasAverageCoverage, isFalse);
      final observed = ListeningStats.fromItems(
        items,
        averageAudioCoverage: .992,
      );
      expect(observed.hasAverageCoverage, isTrue);
      expect(observed.averageProgressPercent, 99);
    },
  );
  test('zero completions are not inferred from plays minus skips', () {
    final item = song('partial', plays: 100);
    expect(ListeningStats.effectiveCompletedFor(item), 0);
    expect(ListeningStats.fromItems([item]).totalCompleted, 0);
  });
  test(
    'explicit historical completions survive and skips include all items',
    () {
      final items = List.generate(
        8,
        (index) => song(
          'song-$index',
          plays: 10,
        ).copyWith(fullListenCount: 3, skipCount: 2),
      );
      final stats = ListeningStats.fromItems(items);
      expect(stats.totalCompleted, 24);
      expect(stats.totalPlays, 80);
      expect(stats.totalSkips, 16);
      expect(stats.mostSkipped, hasLength(5));
    },
  );
  testWidgets('video spotlight and remaining ranked thumbnails use 16:9', (
    tester,
  ) async {
    final items = [song('First'), song('Second')];
    final rows = [
      for (final item in items)
        RankedRowData(
          title: item.title,
          subtitle: 'Video',
          value: '12 plays',
          maxValue: 12,
          currentValue: 12,
          color: Colors.green,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 320,
                child: WrappedRankedRecap(
                  rows: rows,
                  artworkItems: items,
                  badge: 'Top video',
                  artworkAspectRatio: 16 / 9,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 2; i++) {
      final size = tester.getSize(find.byType(WrappedArtwork).at(i));
      expect(size.width / size.height, closeTo(16 / 9, .001));
    }
    expect(tester.takeException(), isNull);
  });
  setUpAll(() {
    Localization.load(
      const Locale('es'),
      translations: Translations(
        jsonDecode(File('assets/translations/es.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
  });
  test('artist uses saved profile photo before a song cover', () {
    final image = wrappedArtistArtwork(
      'Artist',
      profiles: [
        const ArtistProfile(
          key: 'artist-1',
          displayName: 'Artist',
          thumbnailLocalPath: '/artist.jpg',
        ),
      ],
      items: [song('song', cover: '/song.jpg')],
    );
    expect(image.thumbnailLocalPath, '/artist.jpg');
    expect(image.title, 'Artist');
  });
  test('fallback matches exact parsed guest credit, not substrings', () {
    final items = [
      song('wrong', artist: 'Ghost', cover: '/wrong.jpg'),
      song('right', artist: 'Artist feat. Guest', cover: '/right.jpg'),
    ];
    expect(
      wrappedArtistArtwork(
        'Guest',
        profiles: [],
        items: items,
      ).thumbnailLocalPath,
      '/right.jpg',
    );
    expect(
      wrappedArtistArtwork(
        'Gue',
        profiles: [],
        items: items,
      ).thumbnailLocalPath,
      isNull,
    );
  });
  test('homonymous artists are not assigned one another’s photos', () {
    final image = wrappedArtistArtwork(
      'Lisa',
      profiles: [
        const ArtistProfile(
          key: 'artist-k',
          displayName: 'LISA',
          thumbnailLocalPath: '/k.jpg',
        ),
        const ArtistProfile(
          key: 'artist-j',
          displayName: 'LiSA',
          thumbnailLocalPath: '/j.jpg',
        ),
      ],
      items: [song('song', artist: 'Lisa', cover: '/song.jpg')],
    );
    expect(image.thumbnailLocalPath, isNull);
  });
  test('favorites keep independent play ranking and exclude non-favorites', () {
    final stats = ListeningStats.fromItems([
      song('popular', plays: 100),
      song('favorite-two', plays: 5, favorite: true),
      song('favorite-one', plays: 20, favorite: true),
    ]);
    expect(stats.topFavoriteTracks.map((i) => i.id), [
      'favorite-one',
      'favorite-two',
    ]);
    expect(stats.topTracks.first.id, 'popular');
    expect(stats.topImportedArtists.first.artwork?.title, 'Artist');
  });
  testWidgets('first is large once, rest show images and original rank', (
    tester,
  ) async {
    final items = [song('First'), song('Second'), song('Third')];
    final rows = [
      for (var i = 0; i < items.length; i++)
        RankedRowData(
          title: items[i].title,
          subtitle: 'Artist',
          value: '12345 reproducciones',
          maxValue: 3,
          currentValue: 3 - i,
          color: Colors.green,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: WrappedRankedRecap(
                  rows: rows,
                  artworkItems: items,
                  badge: 'Tu favorita más escuchada',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(WrappedTrackSpotlight), findsOneWidget);
    expect(find.byType(WrappedArtwork), findsNWidgets(3));
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
