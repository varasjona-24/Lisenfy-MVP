import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/recommendations/application/usecases/build_recommendation_collections_use_case.dart';
import 'package:listenfy/Modules/recommendations/domain/recommendation_models.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/app/models/media_item.dart';

void main() {
  group('BuildRecommendationCollectionsUseCase', () {
    const useCase = BuildRecommendationCollectionsUseCase();

    test('retorna vacio cuando no hay entradas', () {
      final collections = useCase.call(
        const BuildRecommendationCollectionsInput(
          entries: <RecommendationCollectionSeed>[],
          dateKey: '2026-04-06',
          recommendationMode: RecommendationMode.audio,
          manualRefreshCount: 0,
          hasArtistLocaleMetadata: false,
          resolveLocaleSignal: _noLocale,
          stableKeyOf: _stableKeyOf,
        ),
      );

      expect(collections, isEmpty);
    });

    test('incluye mix regional cuando hay metadata de artista', () {
      final entries = List.generate(24, (i) {
        final item = _buildItem(
          id: 'id-$i',
          publicId: 'pub-$i',
          title: 'Tema $i',
          subtitle: 'Artista $i',
          playCount: i + 1,
          fullListenCount: i ~/ 2,
          skipCount: i % 3,
        );
        final reason = i.isEven
            ? RecommendationReasonCode.regionMatch
            : RecommendationReasonCode.genreMatch;
        return RecommendationCollectionSeed(
          item: item,
          entry: RecommendationEntry(
            itemId: item.id,
            publicId: item.publicId,
            score: 0.7,
            reasonCode: reason,
            reasonText: 'motivo $i',
            generatedAt: DateTime(2026, 4, 6).millisecondsSinceEpoch,
          ),
        );
      });

      final collections = useCase.call(
        BuildRecommendationCollectionsInput(
          entries: entries,
          dateKey: '2026-04-06',
          recommendationMode: RecommendationMode.audio,
          manualRefreshCount: 0,
          hasArtistLocaleMetadata: true,
          resolveLocaleSignal: (item) {
            final id = int.tryParse(item.id.split('-').last) ?? 0;
            return RecommendationLocaleSignal(
              regionKey: id.isEven ? 'latino' : 'asiatico',
              countryName: id.isEven ? 'Colombia' : 'Japon',
            );
          },
          stableKeyOf: _stableKeyOf,
        ),
      );

      expect(collections, isNotEmpty);
      expect(collections.first.id.startsWith('regional-'), isTrue);
    });

    test('no crea coleccion regional cuando no hay metadata', () {
      final entries = List.generate(18, (i) {
        final item = _buildItem(
          id: 'raw-$i',
          publicId: 'raw-pub-$i',
          title: 'Song $i',
          subtitle: 'Artist $i',
          playCount: 4 + i,
        );
        return RecommendationCollectionSeed(
          item: item,
          entry: RecommendationEntry(
            itemId: item.id,
            publicId: item.publicId,
            score: 0.5,
            reasonCode: RecommendationReasonCode.recentAffinity,
            reasonText: 'actividad',
            generatedAt: DateTime(2026, 4, 6).millisecondsSinceEpoch,
          ),
        );
      });

      final collections = useCase.call(
        BuildRecommendationCollectionsInput(
          entries: entries,
          dateKey: '2026-04-06',
          recommendationMode: RecommendationMode.audio,
          manualRefreshCount: 0,
          hasArtistLocaleMetadata: false,
          resolveLocaleSignal: _noLocale,
          stableKeyOf: _stableKeyOf,
        ),
      );

      expect(collections, isNotEmpty);
      expect(collections.any((c) => c.id.startsWith('regional-')), isFalse);
    });
  });
}

RecommendationLocaleSignal? _noLocale(MediaItem _) => null;

String _stableKeyOf(MediaItem item) {
  if (item.publicId.trim().isNotEmpty) return 'p:${item.publicId.trim()}';
  return 'i:${item.id.trim()}';
}

MediaItem _buildItem({
  required String id,
  required String publicId,
  required String title,
  required String subtitle,
  int playCount = 0,
  int skipCount = 0,
  int fullListenCount = 0,
}) {
  return MediaItem(
    id: id,
    publicId: publicId,
    title: title,
    subtitle: subtitle,
    source: MediaSource.local,
    variants: const <MediaVariant>[
      MediaVariant(
        kind: MediaVariantKind.audio,
        format: 'mp3',
        fileName: 'x.mp3',
        createdAt: 1,
        localPath: '/tmp/x.mp3',
      ),
    ],
    origin: SourceOrigin.generic,
    playCount: playCount,
    skipCount: skipCount,
    fullListenCount: fullListenCount,
  );
}
