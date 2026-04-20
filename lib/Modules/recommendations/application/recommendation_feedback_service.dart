import '../data/recommendation_feedback_store.dart';
import '../domain/recommendation_feedback_models.dart';

class RecommendationFeedbackService {
  RecommendationFeedbackService({
    required RecommendationFeedbackStore store,
    DateTime Function()? now,
  }) : _store = store,
       _now = now ?? DateTime.now;

  final RecommendationFeedbackStore _store;
  final DateTime Function() _now;

  RecommendationFeedbackState? _cache;

  Future<RecommendationFeedbackSnapshot> readSnapshot() async {
    final state = await _ensureState();
    return RecommendationFeedbackSnapshot(state);
  }

  Future<void> reloadFromStore() async {
    _cache = await _store.readState();
  }

  Future<void> markTrackInterested(
    String stableKey, {
    double delta = 0.35,
  }) async {
    final key = stableKey.trim();
    if (key.isEmpty) return;
    final state = await _ensureState();
    final next = Map<String, double>.from(state.trackBias);
    next[key] = _clampBias((next[key] ?? 0) + delta);
    final hidden = Set<String>.from(state.hiddenTrackKeys)..remove(key);
    await _save(
      state.copyWith(
        trackBias: next,
        hiddenTrackKeys: hidden,
        updatedAt: _now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> hideTrack(String stableKey) async {
    final key = stableKey.trim();
    if (key.isEmpty) return;
    final state = await _ensureState();
    final hidden = Set<String>.from(state.hiddenTrackKeys)..add(key);
    await _save(
      state.copyWith(
        hiddenTrackKeys: hidden,
        updatedAt: _now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> hideArtist(String artistKey) async {
    final key = artistKey.trim();
    if (key.isEmpty) return;
    final state = await _ensureState();
    final hidden = Set<String>.from(state.hiddenArtistKeys)..add(key);
    await _save(
      state.copyWith(
        hiddenArtistKeys: hidden,
        updatedAt: _now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> setTagBias(String tagKey, double value) async {
    final key = tagKey.trim();
    if (key.isEmpty) return;
    final state = await _ensureState();
    final next = Map<String, double>.from(state.tagBias);
    next[key] = _clampBias(value);
    await _save(
      state.copyWith(tagBias: next, updatedAt: _now().millisecondsSinceEpoch),
    );
  }

  Future<RecommendationFeedbackState> _ensureState() async {
    final cached = _cache;
    if (cached != null) return cached;
    final loaded = await _store.readState();
    _cache = loaded;
    return loaded;
  }

  Future<void> _save(RecommendationFeedbackState next) async {
    _cache = next;
    await _store.writeState(next);
  }

  double _clampBias(double value) {
    return value.clamp(-1.0, 1.0).toDouble();
  }
}
