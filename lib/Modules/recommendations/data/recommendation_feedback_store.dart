import 'package:get_storage/get_storage.dart';

import '../domain/recommendation_feedback_models.dart';

class RecommendationFeedbackStore {
  RecommendationFeedbackStore(this._box);

  RecommendationFeedbackStore.memory([Map<String, dynamic>? initialState])
    : _box = null,
      _memoryState = initialState;

  final GetStorage? _box;
  Map<String, dynamic>? _memoryState;

  static const stateStorageKey = 'recommendation_feedback_v1';

  Future<RecommendationFeedbackState> readState() async {
    final raw = _box?.read(stateStorageKey) ?? _memoryState;
    if (raw is! Map) return RecommendationFeedbackState.empty();
    try {
      return RecommendationFeedbackState.fromJson(
        Map<String, dynamic>.from(raw),
      );
    } catch (_) {
      return RecommendationFeedbackState.empty();
    }
  }

  Future<void> writeState(RecommendationFeedbackState state) async {
    final json = state.toJson();
    _memoryState = json;
    if (_box != null) {
      await _box.write(stateStorageKey, json);
    }
  }

  Future<Map<String, dynamic>> exportBackupPayload() async {
    final state = await readState();
    return {'recommendationFeedback': state.toJson()};
  }

  Future<void> restoreBackupPayload(Map<String, dynamic> manifest) async {
    final raw = manifest['recommendationFeedback'];
    if (raw is! Map) return;
    final parsed = RecommendationFeedbackState.fromJson(
      Map<String, dynamic>.from(raw),
    );
    await writeState(parsed);
  }
}
