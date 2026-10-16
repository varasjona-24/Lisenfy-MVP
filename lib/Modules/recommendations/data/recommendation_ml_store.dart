import 'package:get_storage/get_storage.dart';
import '../../../app/data/local/domain_storage.dart';
import '../domain/recommendation_ml_models.dart';

class RecommendationMlStore {
  RecommendationMlStore(GetStorage box) : _box = domainStorage(box);
  RecommendationMlStore.memory([Map<String, dynamic>? state])
    : _box = null,
      _memory = state;
  static const storageKey = 'recommendation_ml_state_v1';
  final GetStorage? _box;
  Map<String, dynamic>? _memory;
  Future<RecommendationMlState> readState() async {
    final raw = _box != null ? _box.read(storageKey) : _memory;
    if (raw is! Map) return RecommendationMlState.empty();
    try {
      return RecommendationMlState.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return RecommendationMlState.empty();
    }
  }

  Future<void> writeState(RecommendationMlState state) async {
    final json = state.toJson();
    await _box?.write(storageKey, json);
    _memory = json;
  }
}
