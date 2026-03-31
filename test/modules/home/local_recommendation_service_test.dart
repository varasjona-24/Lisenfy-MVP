import 'package:listenfy/Modules/artists/domain/artist_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/home/data/recommendation_store.dart';
import 'package:listenfy/Modules/home/domain/recommendation_models.dart';
import 'package:listenfy/Modules/home/service/local_recommendation_service.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/app/models/media_item.dart';

void main() {
  group('LocalRecommendationService', () {
    test('mantiene set estable el mismo dia sin refresh manual', () async {
      var now = DateTime(2026, 3, 6, 10, 30);
      final items = List.generate(
        30,
        (i) => _buildItem(
          id: 'id-$i',
          publicId: 'pub-$i',
          title: 'Song $i',
          subtitle: 'Artist $i',
          hasAudio: true,
          hasVideo: true,
          playCount: i % 3,
        ),
      );

      final service = LocalRecommendationService(
        store: RecommendationStore.memory(),
        libraryLoader: () async => items,
        now: () => now,
      );

      final first = await service.getOrBuildForDay(
        mode: RecommendationMode.audio,
      );
      final second = await service.getOrBuildForDay(
        mode: RecommendationMode.audio,
      );

      expect(first.dateKey, second.dateKey);
      expect(_entryIds(first), _entryIds(second));
      expect(first.manualRefreshCount, 0);
    });

    test('rota automaticamente cuando cambia la fecha', () async {
      var now = DateTime(2026, 3, 6, 9, 0);
      final items = List.generate(
        40,
        (i) => _buildItem(
          id: 'id-$i',
          publicId: 'pub-$i',
          title: 'Tema $i',
          subtitle: 'Artista $i',
          hasAudio: true,
          hasVideo: true,
        ),
      );

      final service = LocalRecommendationService(
        store: RecommendationStore.memory(),
        libraryLoader: () async => items,
        now: () => now,
      );

      final dayOne = await service.getOrBuildForDay(
        mode: RecommendationMode.audio,
      );
      now = now.add(const Duration(days: 1));
      final dayTwo = await service.getOrBuildForDay(
        mode: RecommendationMode.audio,
      );

      expect(dayOne.dateKey, isNot(dayTwo.dateKey));
      expect(_entryIds(dayOne), isNot(equals(_entryIds(dayTwo))));
    });

    test('bloquea el tercer refresh manual del mismo dia', () async {
      final now = DateTime(2026, 3, 6, 12, 0);
      final items = List.generate(
        35,
        (i) => _buildItem(
          id: 'id-$i',
          publicId: 'pub-$i',
          title: 'Song $i',
          subtitle: 'Artist $i',
          hasAudio: true,
          hasVideo: true,
          playCount: i,
        ),
      );

      final service = LocalRecommendationService(
        store: RecommendationStore.memory(),
        libraryLoader: () async => items,
        now: () => now,
      );

      await service.getOrBuildForDay(mode: RecommendationMode.audio);
      expect(
        service.canManualRefreshToday(mode: RecommendationMode.audio),
        isTrue,
      );

      final firstRefresh = await service.refreshManually(
        mode: RecommendationMode.audio,
      );
      expect(firstRefresh.manualRefreshCount, 1);
      expect(
        service.canManualRefreshToday(mode: RecommendationMode.audio),
        isTrue,
      );

      final secondRefresh = await service.refreshManually(
        mode: RecommendationMode.audio,
      );
      expect(secondRefresh.manualRefreshCount, 2);
      expect(
        service.canManualRefreshToday(mode: RecommendationMode.audio),
        isFalse,
      );

      final thirdRefresh = await service.refreshManually(
        mode: RecommendationMode.audio,
      );
      expect(thirdRefresh.manualRefreshCount, 2);
      expect(_entryIds(thirdRefresh), _entryIds(secondRefresh));
    });

    test('respeta filtro por modo audio/video', () async {
      final now = DateTime(2026, 3, 6, 8, 0);
      final audioItems = List.generate(
        20,
        (i) => _buildItem(
          id: 'audio-$i',
          publicId: 'audio-pub-$i',
          title: 'Audio $i',
          subtitle: 'Artist A$i',
          hasAudio: true,
          hasVideo: false,
        ),
      );
      final videoItems = List.generate(
        20,
        (i) => _buildItem(
          id: 'video-$i',
          publicId: 'video-pub-$i',
          title: 'Video $i',
          subtitle: 'Artist V$i',
          hasAudio: false,
          hasVideo: true,
        ),
      );

      final service = LocalRecommendationService(
        store: RecommendationStore.memory(),
        libraryLoader: () async => [...audioItems, ...videoItems],
        now: () => now,
      );

      final audioSet = await service.getOrBuildForDay(
        mode: RecommendationMode.audio,
      );
      final videoSet = await service.getOrBuildForDay(
        mode: RecommendationMode.video,
      );

      expect(
        audioSet.entries.every((entry) => entry.itemId.startsWith('audio-')),
        isTrue,
      );
      expect(
        videoSet.entries.every((entry) => entry.itemId.startsWith('video-')),
        isTrue,
      );
    });

    test('detecta heuristica semantica trap latino / Puerto Rico', () async {
      final now = DateTime(2026, 3, 6, 15, 0);
      final items = <MediaItem>[
        _buildItem(
          id: 'seed-1',
          publicId: 'seed-1',
          title: 'Trap Latino Session Puerto Rico',
          subtitle: 'MC Boricua',
          hasAudio: true,
          hasVideo: true,
          isFavorite: true,
          playCount: 42,
          lastPlayedAt:
              now.millisecondsSinceEpoch -
              const Duration(hours: 3).inMilliseconds,
          origin: SourceOrigin.youtube,
        ),
        _buildItem(
          id: 'match-1',
          publicId: 'match-1',
          title: 'Trap de Puerto Rico Vol.2',
          subtitle: 'New Artist',
          hasAudio: true,
          hasVideo: false,
        ),
        _buildItem(
          id: 'other-1',
          publicId: 'other-1',
          title: 'Balada Romantica',
          subtitle: 'Singer X',
          hasAudio: true,
          hasVideo: true,
        ),
        ...List.generate(
          30,
          (i) => _buildItem(
            id: 'extra-$i',
            publicId: 'extra-$i',
            title: 'Tema extra $i',
            subtitle: 'Artista extra $i',
            hasAudio: true,
            hasVideo: true,
          ),
        ),
      ];

      final service = LocalRecommendationService(
        store: RecommendationStore.memory(),
        libraryLoader: () async => items,
        now: () => now,
      );

      final set = await service.getOrBuildForDay(
        mode: RecommendationMode.audio,
      );
      final reasons = set.entries
          .map((e) => e.reasonText.toLowerCase())
          .toList();

      expect(
        reasons.any(
          (reason) =>
              reason.contains('trap latino') || reason.contains('puerto rico'),
        ),
        isTrue,
      );
    });

    test(
      'usa el pais del artista como señal regional para recomendaciones',
      () async {
        final now = DateTime(2026, 3, 6, 18, 0);
        final items = <MediaItem>[
          _buildItem(
            id: 'seed-col',
            publicId: 'seed-col',
            title: 'Session de noche',
            subtitle: 'Artista Uno',
            hasAudio: true,
            hasVideo: true,
            isFavorite: true,
            playCount: 38,
            lastPlayedAt:
                now.millisecondsSinceEpoch -
                const Duration(hours: 4).inMilliseconds,
          ),
          _buildItem(
            id: 'match-col',
            publicId: 'match-col',
            title: 'Tema nuevo',
            subtitle: 'Artista Dos',
            hasAudio: true,
            hasVideo: false,
          ),
          ...List.generate(
            20,
            (i) => _buildItem(
              id: 'other-$i',
              publicId: 'other-$i',
              title: 'Tema otro $i',
              subtitle: 'Artista otro $i',
              hasAudio: true,
              hasVideo: true,
            ),
          ),
        ];
        final profiles = <ArtistProfile>[
          const ArtistProfile(
            key: 'artista uno',
            displayName: 'Artista Uno',
            country: 'Colombia',
          ),
          const ArtistProfile(
            key: 'artista dos',
            displayName: 'Artista Dos',
            country: 'Colombia',
          ),
          ...List.generate(
            20,
            (i) => ArtistProfile(
              key: 'artista otro $i',
              displayName: 'Artista otro $i',
              country: i.isEven ? 'Chile' : 'Argentina',
            ),
          ),
        ];

        final service = LocalRecommendationService(
          store: RecommendationStore.memory(),
          libraryLoader: () async => items,
          artistProfileLoader: () async => profiles,
          now: () => now,
        );

        final set = await service.getOrBuildForDay(
          mode: RecommendationMode.audio,
        );
        final reasons = set.entries
            .map((entry) => entry.reasonText.toLowerCase())
            .toList();

        expect(reasons.any((reason) => reason.contains('colombia')), isTrue);
      },
    );

    test(
      'cold start devuelve todos los items disponibles con fallback',
      () async {
        final now = DateTime(2026, 3, 6, 10, 0);
        final items = List.generate(
          50,
          (i) => _buildItem(
            id: 'cold-$i',
            publicId: 'cold-pub-$i',
            title: 'Tema frio $i',
            subtitle: 'Artista frio $i',
            hasAudio: true,
            hasVideo: true,
          ),
        );

        final service = LocalRecommendationService(
          store: RecommendationStore.memory(),
          libraryLoader: () async => items,
          now: () => now,
        );

        final set = await service.getOrBuildForDay(
          mode: RecommendationMode.audio,
        );
        expect(set.entries.length, items.length);
        expect(
          set.entries.every((e) => e.reasonText.trim().isNotEmpty),
          isTrue,
        );
      },
    );

    test('penaliza alta tasa de skip y premia retencion alta', () async {
      final now = DateTime(2026, 3, 6, 21, 0);
      final nowMs = now.millisecondsSinceEpoch;
      final items = <MediaItem>[
        _buildItem(
          id: 'seed',
          publicId: 'seed',
          title: 'Trap Latino Seed',
          subtitle: 'Artista Seed',
          hasAudio: true,
          hasVideo: true,
          playCount: 40,
          fullListenCount: 24,
          skipCount: 3,
          avgListenProgress: 0.92,
          isFavorite: true,
          lastPlayedAt: nowMs - const Duration(hours: 2).inMilliseconds,
          country: 'Puerto Rico',
        ),
        _buildItem(
          id: 'good',
          publicId: 'good',
          title: 'Trap Puerto Rico Good',
          subtitle: 'Artista Bueno',
          hasAudio: true,
          hasVideo: false,
          playCount: 20,
          fullListenCount: 14,
          skipCount: 2,
          avgListenProgress: 0.9,
          lastPlayedAt: nowMs - const Duration(days: 2).inMilliseconds,
          country: 'Puerto Rico',
        ),
        _buildItem(
          id: 'bad',
          publicId: 'bad',
          title: 'Trap Puerto Rico Bad',
          subtitle: 'Artista Malo',
          hasAudio: true,
          hasVideo: false,
          playCount: 20,
          fullListenCount: 1,
          skipCount: 15,
          avgListenProgress: 0.24,
          lastPlayedAt: nowMs - const Duration(days: 2).inMilliseconds,
          country: 'Puerto Rico',
        ),
        ...List.generate(
          20,
          (i) => _buildItem(
            id: 'extra-$i',
            publicId: 'extra-$i',
            title: 'Tema extra $i',
            subtitle: 'Artista extra $i',
            hasAudio: true,
            hasVideo: true,
          ),
        ),
      ];

      final service = LocalRecommendationService(
        store: RecommendationStore.memory(),
        libraryLoader: () async => items,
        now: () => now,
      );

      final set = await service.getOrBuildForDay(
        mode: RecommendationMode.audio,
      );
      final ids = _entryIds(set);

      expect(ids.contains('good'), isTrue);
      expect(ids.contains('bad'), isTrue);
      expect(ids.indexOf('good'), lessThan(ids.indexOf('bad')));
    });
  });
}

List<String> _entryIds(RecommendationDailySet set) {
  return set.entries.map((e) => e.itemId).toList(growable: false);
}

MediaItem _buildItem({
  required String id,
  required String publicId,
  required String title,
  required String subtitle,
  required bool hasAudio,
  required bool hasVideo,
  int playCount = 0,
  bool isFavorite = false,
  int? lastPlayedAt,
  int skipCount = 0,
  int fullListenCount = 0,
  double avgListenProgress = 0,
  int? lastCompletedAt,
  String? country,
  SourceOrigin origin = SourceOrigin.generic,
}) {
  final variants = <MediaVariant>[];
  if (hasAudio) {
    variants.add(
      MediaVariant(
        kind: MediaVariantKind.audio,
        format: 'mp3',
        fileName: '$id.mp3',
        createdAt: 1,
        localPath: '/tmp/$id.mp3',
      ),
    );
  }
  if (hasVideo) {
    variants.add(
      MediaVariant(
        kind: MediaVariantKind.video,
        format: 'mp4',
        fileName: '$id.mp4',
        createdAt: 1,
        localPath: '/tmp/$id.mp4',
      ),
    );
  }

  return MediaItem(
    id: id,
    publicId: publicId,
    title: title,
    subtitle: subtitle,
    country: country,
    source: MediaSource.local,
    variants: variants,
    origin: origin,
    isFavorite: isFavorite,
    playCount: playCount,
    lastPlayedAt: lastPlayedAt,
    skipCount: skipCount,
    fullListenCount: fullListenCount,
    avgListenProgress: avgListenProgress,
    lastCompletedAt: lastCompletedAt,
  );
}
