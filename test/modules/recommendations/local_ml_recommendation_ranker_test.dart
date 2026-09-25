import 'package:flutter_test/flutter_test.dart';
import 'package:listenfy/Modules/recommendations/application/local_ml_recommendation_ranker.dart';
import 'package:listenfy/Modules/recommendations/data/recommendation_ml_store.dart';
import 'package:listenfy/Modules/recommendations/domain/recommendation_ml_models.dart';
import 'package:listenfy/Modules/recommendations/domain/recommendation_models.dart';

void main() {
  test(
    'entrena un modelo local y solo predice al alcanzar evidencia suficiente',
    () async {
      final ranker = LocalMlRecommendationRanker(
        store: RecommendationMlStore.memory(),
        now: () => DateTime(2026, 9, 25),
      );
      final examples = List<RecommendationMlTrainingExample>.generate(120, (i) {
        final positive = i.isEven;
        final vector = List<double>.filled(
          RecommendationMlFeatures.featureCount,
          0,
        );
        vector[0] = positive ? 1 : 0;
        vector[5] = positive ? .9 : .1;
        return RecommendationMlTrainingExample(
          stableKey: 'track-$i',
          trackKey: 'track-$i',
          features: RecommendationMlFeatures(vector),
          target: positive ? 1 : 0,
          sampleWeight: 1,
          sourceEventCount: 1,
        );
      });

      await ranker.prepare(mode: RecommendationMode.audio, examples: examples);

      final positiveVector = List<double>.filled(
        RecommendationMlFeatures.featureCount,
        0,
      );
      positiveVector[0] = 1;
      positiveVector[5] = .9;
      final negativeVector = List<double>.filled(
        RecommendationMlFeatures.featureCount,
        0,
      );
      negativeVector[5] = .1;
      final positive = ranker.predict(
        mode: RecommendationMode.audio,
        features: RecommendationMlFeatures(positiveVector),
      );
      final negative = ranker.predict(
        mode: RecommendationMode.audio,
        features: RecommendationMlFeatures(negativeVector),
      );

      expect(positive, isNotNull);
      expect(negative, isNotNull);
      expect(positive!.score, greaterThan(negative!.score));
      expect(
        ranker.diagnostics(mode: RecommendationMode.audio).isReady,
        isTrue,
      );
    },
  );
}
