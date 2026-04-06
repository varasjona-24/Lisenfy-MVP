import '../recommendation_models.dart';

/// Contrato del motor de recomendaciones para desacoplar consumidores
/// (Home/Settings) de la implementación concreta.
abstract class RecommendationEngine {
  Future<RecommendationDailySet> getOrBuildForDay({
    required RecommendationMode mode,
  });

  Future<RecommendationDailySet> refreshManually({
    required RecommendationMode mode,
  });

  bool canManualRefreshToday({required RecommendationMode mode});

  String? nextRefreshHint({required RecommendationMode mode});

  Future<void> reloadFromStore();
}
