class RecommendationFeedbackState {
  const RecommendationFeedbackState({
    required this.trackBias,
    required this.artistBias,
    required this.tagBias,
    required this.hiddenTrackKeys,
    required this.hiddenArtistKeys,
    this.updatedAt,
  });

  final Map<String, double> trackBias;
  final Map<String, double> artistBias;
  final Map<String, double> tagBias;
  final Set<String> hiddenTrackKeys;
  final Set<String> hiddenArtistKeys;
  final int? updatedAt;

  factory RecommendationFeedbackState.empty() {
    return const RecommendationFeedbackState(
      trackBias: <String, double>{},
      artistBias: <String, double>{},
      tagBias: <String, double>{},
      hiddenTrackKeys: <String>{},
      hiddenArtistKeys: <String>{},
    );
  }

  RecommendationFeedbackState copyWith({
    Map<String, double>? trackBias,
    Map<String, double>? artistBias,
    Map<String, double>? tagBias,
    Set<String>? hiddenTrackKeys,
    Set<String>? hiddenArtistKeys,
    int? updatedAt,
  }) {
    return RecommendationFeedbackState(
      trackBias: trackBias ?? this.trackBias,
      artistBias: artistBias ?? this.artistBias,
      tagBias: tagBias ?? this.tagBias,
      hiddenTrackKeys: hiddenTrackKeys ?? this.hiddenTrackKeys,
      hiddenArtistKeys: hiddenArtistKeys ?? this.hiddenArtistKeys,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'trackBias': trackBias,
    'artistBias': artistBias,
    'tagBias': tagBias,
    'hiddenTrackKeys': hiddenTrackKeys.toList(growable: false),
    'hiddenArtistKeys': hiddenArtistKeys.toList(growable: false),
    'updatedAt': updatedAt,
  };

  factory RecommendationFeedbackState.fromJson(Map<String, dynamic> json) {
    return RecommendationFeedbackState(
      trackBias: _readDoubleMap(json['trackBias']),
      artistBias: _readDoubleMap(json['artistBias']),
      tagBias: _readDoubleMap(json['tagBias']),
      hiddenTrackKeys: _readStringSet(json['hiddenTrackKeys']),
      hiddenArtistKeys: _readStringSet(json['hiddenArtistKeys']),
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
    );
  }

  static Map<String, double> _readDoubleMap(dynamic raw) {
    if (raw is! Map) return const <String, double>{};
    final out = <String, double>{};
    raw.forEach((key, value) {
      final normalizedKey = key.toString().trim();
      if (normalizedKey.isEmpty) return;
      final number = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      if (number == null) return;
      out[normalizedKey] = number;
    });
    return out;
  }

  static Set<String> _readStringSet(dynamic raw) {
    if (raw is! List) return const <String>{};
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }
}

class RecommendationFeedbackSnapshot {
  const RecommendationFeedbackSnapshot(this.state);

  final RecommendationFeedbackState state;

  factory RecommendationFeedbackSnapshot.empty() {
    return RecommendationFeedbackSnapshot(RecommendationFeedbackState.empty());
  }

  bool isTrackHidden(String stableKey) {
    return state.hiddenTrackKeys.contains(stableKey.trim());
  }

  bool hasHiddenArtist(List<String> artistKeys) {
    for (final key in artistKeys) {
      final normalized = key.trim();
      if (normalized.isEmpty) continue;
      if (state.hiddenArtistKeys.contains(normalized)) return true;
    }
    return false;
  }

  double trackBiasForStableKey(String stableKey) {
    final key = stableKey.trim();
    if (key.isEmpty) return 0;
    return state.trackBias[key] ?? 0;
  }

  double bestArtistBias(List<String> artistKeys) {
    var best = 0.0;
    for (final key in artistKeys) {
      final normalized = key.trim();
      if (normalized.isEmpty) continue;
      final value = state.artistBias[normalized] ?? 0;
      if (value.abs() > best.abs()) best = value;
    }
    return best;
  }

  double bestTagBias({
    required List<String> genres,
    required List<String> regions,
    required String originKey,
  }) {
    final keys = <String>[
      ...genres.map((g) => 'genre:$g'),
      ...regions.map((r) => 'region:$r'),
      'origin:$originKey',
    ];
    var best = 0.0;
    for (final key in keys) {
      final normalized = key.trim();
      if (normalized.isEmpty) continue;
      final value = state.tagBias[normalized] ?? 0;
      if (value.abs() > best.abs()) best = value;
    }
    return best;
  }
}
