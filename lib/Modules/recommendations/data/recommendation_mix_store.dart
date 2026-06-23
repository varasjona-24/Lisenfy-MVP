import 'package:get_storage/get_storage.dart';

import '../domain/recommendation_mix_models.dart';

class RecommendationMixStore {
  RecommendationMixStore(this._box);
  RecommendationMixStore.memory([Map<String, dynamic>? initial])
    : _box = null,
      _memory = initial;

  static const storageKey = 'recommendation_mix_state_v2';

  final GetStorage? _box;
  Map<String, dynamic>? _memory;

  Future<RecommendationMixState> read() async {
    final raw = _box?.read(storageKey) ?? _memory;
    if (raw is! Map) return RecommendationMixState.empty();
    try {
      return RecommendationMixState.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return RecommendationMixState.empty();
    }
  }

  Future<void> write(RecommendationMixState state) async {
    _memory = state.toJson();
    await _box?.write(storageKey, state.toJson());
  }

  Future<void> markOpened(String mixId, int openedAt) async {
    final state = await read();
    final history = state.history
        .map(
          (entry) =>
              entry.mixId == mixId ? entry.copyWith(openedAt: openedAt) : entry,
        )
        .toList(growable: false);
    await write(state.copyWith(history: history));
  }
}
