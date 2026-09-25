import '../recommendation_ml_models.dart';
import '../recommendation_models.dart';

abstract interface class RecommendationRanker {
  Future<void> prepare({
    required RecommendationMode mode,
    required List<RecommendationMlTrainingExample> examples,
  });
  RecommendationMlPrediction? predict({
    required RecommendationMode mode,
    required RecommendationMlFeatures features,
  });
  RecommendationMlDiagnostics diagnostics({required RecommendationMode mode});
  Future<void> reloadFromStore();
}
