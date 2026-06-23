import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/recommendations/application/usecases/build_recommendation_collections_use_case.dart';
import 'package:listenfy/Modules/recommendations/data/recommendation_mix_store.dart';
import 'package:listenfy/Modules/recommendations/data/listening_event_store.dart';
import 'package:listenfy/Modules/recommendations/domain/recommendation_models.dart';
import 'package:listenfy/Modules/sources/domain/source_origin.dart';
import 'package:listenfy/app/models/media_item.dart';

void main() {
  group('BuildRecommendationCollectionsUseCase v2', () {
    test('oculta Para ti hoy con menos de 60 audios', () async {
      final useCase = _useCase();
      final now = DateTime(2026, 6, 22, 10);
      final items = _items(59, now: now);

      final result = await useCase.call(_input(items, now));

      expect(result, isEmpty);
    });

    test('genera dos mixes de 10 desde 60 audios sin solaparse', () async {
      final useCase = _useCase();
      final now = DateTime(2026, 6, 22, 10);
      final items = _items(60, now: now);

      final result = await useCase.call(_input(items, now));

      expect(result, hasLength(2));
      expect(result.every((mix) => mix.items.length == 10), isTrue);
      final first = result.first.items.map((item) => item.id).toSet();
      final second = result.last.items.map((item) => item.id).toSet();
      expect(first.intersection(second), isEmpty);
    });

    test('mantiene el ciclo durante 15 horas y después lo rota', () async {
      final useCase = _useCase();
      final start = DateTime(2026, 6, 22, 5);
      final items = _items(100, now: start);

      final first = await useCase.call(_input(items, start));
      final sameCycle = await useCase.call(
        _input(items, start.add(const Duration(hours: 14, minutes: 59))),
      );
      final nextCycle = await useCase.call(
        _input(items, start.add(const Duration(hours: 15, minutes: 1))),
      );

      expect(_mixIds(first), _mixIds(sameCycle));
      expect(_allItemIds(first), isNot(equals(_allItemIds(nextCycle))));
      expect(_allItemIds(first).intersection(_allItemIds(nextCycle)), isEmpty);
    });

    test('aplica tamaños 15 y 20 según el tamaño de biblioteca', () async {
      final now = DateTime(2026, 6, 22, 14);
      final medium = await _useCase().call(_input(_items(151, now: now), now));
      final large = await _useCase().call(_input(_items(301, now: now), now));

      expect(medium.every((mix) => mix.items.length == 15), isTrue);
      expect(large.every((mix) => mix.items.length == 20), isTrue);
    });

    test('el mix regional sobrevive al ciclo siguiente', () async {
      final useCase = _useCase();
      final start = DateTime(2026, 6, 22, 8);
      final items = _items(90, now: start);
      RecommendationLocaleSignal locale(MediaItem item) {
        final index = int.parse(item.id.split('-').last);
        return RecommendationLocaleSignal(
          regionKey: index.isEven ? 'latino' : 'anglo',
          countryName: index.isEven ? 'Ecuador' : 'Estados Unidos',
        );
      }

      final first = await useCase.call(
        _input(items, start, localeResolver: locale),
      );
      final regional = first.firstWhere((mix) => mix.id.startsWith('region-'));
      final second = await useCase.call(
        _input(
          items,
          start.add(const Duration(hours: 16)),
          localeResolver: locale,
        ),
      );

      expect(second.any((mix) => mix.id == regional.id), isTrue);
    });
  });
}

BuildRecommendationCollectionsUseCase _useCase() {
  return BuildRecommendationCollectionsUseCase(
    store: RecommendationMixStore.memory(),
    listeningEventStore: ListeningEventStore.memory(),
  );
}

BuildRecommendationCollectionsInput _input(
  List<MediaItem> items,
  DateTime now, {
  RecommendationLocaleSignal? Function(MediaItem)? localeResolver,
}) {
  return BuildRecommendationCollectionsInput(
    entries: items
        .map(
          (item) => RecommendationCollectionSeed(
            item: item,
            entry: RecommendationEntry(
              itemId: item.id,
              publicId: item.publicId,
              score: item.playCount.toDouble(),
              reasonCode: RecommendationReasonCode.recentAffinity,
              reasonText: 'Actividad local',
              generatedAt: now.millisecondsSinceEpoch,
            ),
          ),
        )
        .toList(),
    library: items,
    resolveLocaleSignal: localeResolver ?? (_) => null,
    stableKeyOf: (item) => 'p:${item.publicId}',
    now: now,
  );
}

List<MediaItem> _items(int count, {required DateTime now}) {
  return List.generate(count, (index) {
    final lastPlayed = index % 3 == 0
        ? now.subtract(Duration(days: 25 + (index % 20))).millisecondsSinceEpoch
        : null;
    return MediaItem(
      id: 'id-$index',
      publicId: 'pub-$index',
      title: 'Canción $index',
      subtitle: 'Artista ${index % 12}',
      source: MediaSource.local,
      variants: [
        MediaVariant(
          kind: MediaVariantKind.audio,
          format: 'mp3',
          fileName: '$index.mp3',
          localPath: '/tmp/$index.mp3',
          createdAt: now
              .subtract(Duration(days: index % 90))
              .millisecondsSinceEpoch,
        ),
      ],
      origin: SourceOrigin.device,
      playCount: index % 18,
      fullListenCount: index % 7,
      skipCount: index % 4,
      avgListenProgress: (index % 10) / 10,
      lastPlayedAt: lastPlayed,
    );
  });
}

List<String> _mixIds(List<dynamic> mixes) {
  return mixes.map<String>((mix) => mix.id as String).toList();
}

Set<String> _allItemIds(List<dynamic> mixes) {
  return mixes
      .expand<MediaItem>((mix) => mix.items as List<MediaItem>)
      .map((item) => item.id)
      .toSet();
}
