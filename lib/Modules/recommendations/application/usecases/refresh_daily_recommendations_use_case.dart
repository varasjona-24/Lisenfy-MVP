import '../../domain/contracts/recommendation_engine.dart';
import '../../domain/recommendation_models.dart';

class RefreshDailyRecommendationsUseCase {
  const RefreshDailyRecommendationsUseCase(this._engine);

  final RecommendationEngine _engine;

  Future<RecommendationDailySet> call({required RecommendationMode mode}) {
    return _engine.refreshManually(mode: mode);
  }
}
