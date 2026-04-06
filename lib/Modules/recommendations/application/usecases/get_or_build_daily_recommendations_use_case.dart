import '../../domain/contracts/recommendation_engine.dart';
import '../../domain/recommendation_models.dart';

class GetOrBuildDailyRecommendationsUseCase {
  const GetOrBuildDailyRecommendationsUseCase(this._engine);

  final RecommendationEngine _engine;

  Future<RecommendationDailySet> call({required RecommendationMode mode}) {
    return _engine.getOrBuildForDay(mode: mode);
  }
}
