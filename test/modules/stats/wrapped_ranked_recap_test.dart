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
