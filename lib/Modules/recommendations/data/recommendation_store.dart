import 'package:get_storage/get_storage.dart';

import '../domain/recommendation_models.dart';

class RecommendationStore {
  RecommendationStore(this._box);
  RecommendationStore.memory([Map<String, dynamic>? initialState])
    : _box = null,
      _memoryState = initialState;

  final GetStorage? _box;
  Map<String, dynamic>? _memoryState;

  static const stateStorageKey = 'recommendation_state_v1';

  Future<RecommendationState> readState() async {
    final raw = _box?.read(stateStorageKey) ?? _memoryState;
    if (raw is! Map) return RecommendationState.empty();
    try {
      return RecommendationState.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return RecommendationState.empty();
    }
  }

  Future<void> writeState(RecommendationState state) async {
    _memoryState = state.toJson();
    if (_box != null) {
      await _box.write(stateStorageKey, state.toJson());
    }
  }

  Future<Map<String, dynamic>> exportBackupPayload() async {
    final state = await readState();
    return {
      'recommendationProfile': state.profile.toJson(),
      'recommendationDailySets': state.dailySets.values
          .map((e) => e.toJson())
          .toList(),
      'recommendationInstallId': state.installId,
    };
  }

  Future<void> restoreBackupPayload(Map<String, dynamic> manifest) async {
    final hasProfile = manifest.containsKey('recommendationProfile');
    final hasDailySets = manifest.containsKey('recommendationDailySets');
    if (!hasProfile && !hasDailySets) return;

    final previous = await readState();

    final profileRaw = manifest['recommendationProfile'];
    final nextProfile = profileRaw is Map
        ? RecommendationProfile.fromJson(Map<String, dynamic>.from(profileRaw))
        : previous.profile;

    final dailyRaw = (manifest['recommendationDailySets'] as List?) ?? const [];
    final sets = <String, RecommendationDailySet>{};
    for (final raw in dailyRaw) {
      if (raw is! Map) continue;
      final parsed = RecommendationDailySet.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (parsed.dateKey.isEmpty) continue;
      sets['${parsed.dateKey}|${parsed.mode.key}'] = parsed;
    }

    final installId =
        (manifest['recommendationInstallId'] as String?)?.trim() ??
        previous.installId;

    final nextState = previous.copyWith(
      installId: installId,
      profile: nextProfile,
      dailySets: hasDailySets ? sets : previous.dailySets,
    );

    await writeState(nextState);
  }
}
