import '../../domain/contracts/recommendation_engine.dart';
import '../../domain/recommendation_models.dart';

class RecommendationRefreshPolicyUseCase {
  const RecommendationRefreshPolicyUseCase(this._engine);

  final RecommendationEngine _engine;

  bool canRefresh({required RecommendationMode mode}) {
    return _engine.canManualRefreshToday(mode: mode);
  }

  String? nextHint({required RecommendationMode mode}) {
    return _engine.nextRefreshHint(mode: mode);
  }
}
