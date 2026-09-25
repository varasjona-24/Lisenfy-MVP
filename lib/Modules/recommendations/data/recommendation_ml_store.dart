import 'package:get_storage/get_storage.dart';
import '../domain/recommendation_ml_models.dart';

class RecommendationMlStore {
  RecommendationMlStore(this._box);
  RecommendationMlStore.memory([Map<String, dynamic>? state])
    : _box = null,
      _memory = state;
  static const storageKey = 'recommendation_ml_state_v1';
  final GetStorage? _box;
  Map<String, dynamic>? _memory;
  Future<RecommendationMlState> readState() async {
    final raw = _box?.read(storageKey) ?? _memory;
    if (raw is! Map) return RecommendationMlState.empty();
    try {
      return RecommendationMlState.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return RecommendationMlState.empty();
    }
  }

  Future<void> writeState(RecommendationMlState state) async {
    _memory = state.toJson();
    await _box?.write(storageKey, _memory);
  }
}
