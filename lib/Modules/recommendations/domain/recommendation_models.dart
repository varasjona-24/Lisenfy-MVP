enum RecommendationReasonCode {
  genreMatch,
  regionMatch,
  artistAffinity,
  originAffinity,
  favoriteAffinity,
  recentAffinity,
  freshPick,
  coldStart,
}

extension RecommendationReasonCodeX on RecommendationReasonCode {
  String get key {
    switch (this) {
      case RecommendationReasonCode.genreMatch:
        return 'genre_match';
      case RecommendationReasonCode.regionMatch:
        return 'region_match';
      case RecommendationReasonCode.artistAffinity:
        return 'artist_affinity';
      case RecommendationReasonCode.originAffinity:
        return 'origin_affinity';
      case RecommendationReasonCode.favoriteAffinity:
        return 'favorite_affinity';
      case RecommendationReasonCode.recentAffinity:
        return 'recent_affinity';
      case RecommendationReasonCode.freshPick:
        return 'fresh_pick';
      case RecommendationReasonCode.coldStart:
        return 'cold_start';
    }
  }

  static RecommendationReasonCode fromKey(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    switch (key) {
      case 'genre_match':
        return RecommendationReasonCode.genreMatch;
      case 'region_match':
        return RecommendationReasonCode.regionMatch;
      case 'artist_affinity':
        return RecommendationReasonCode.artistAffinity;
      case 'origin_affinity':
        return RecommendationReasonCode.originAffinity;
      case 'favorite_affinity':
        return RecommendationReasonCode.favoriteAffinity;
      case 'recent_affinity':
        return RecommendationReasonCode.recentAffinity;
      case 'fresh_pick':
        return RecommendationReasonCode.freshPick;
      case 'cold_start':
      default:
        return RecommendationReasonCode.coldStart;
    }
  }
}

enum RecommendationMode { audio, video }

extension RecommendationModeX on RecommendationMode {
  String get key => this == RecommendationMode.audio ? 'audio' : 'video';

  static RecommendationMode fromKey(String? raw) {
    return (raw ?? '').trim().toLowerCase() == 'video'
        ? RecommendationMode.video
        : RecommendationMode.audio;
  }
}

class RecommendationEntry {
  const RecommendationEntry({
    required this.itemId,
    required this.publicId,
    required this.score,
    required this.reasonCode,
    required this.reasonText,
    required this.generatedAt,
  });

  final String itemId;
  final String publicId;
  final double score;
  final RecommendationReasonCode reasonCode;
  final String reasonText;
  final int generatedAt;

  RecommendationEntry copyWith({
    String? itemId,
    String? publicId,
    double? score,
    RecommendationReasonCode? reasonCode,
    String? reasonText,
    int? generatedAt,
  }) {
    return RecommendationEntry(
      itemId: itemId ?? this.itemId,
      publicId: publicId ?? this.publicId,
      score: score ?? this.score,
      reasonCode: reasonCode ?? this.reasonCode,
      reasonText: reasonText ?? this.reasonText,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  factory RecommendationEntry.fromJson(Map<String, dynamic> json) {
    return RecommendationEntry(
      itemId: (json['itemId'] as String?)?.trim() ?? '',
      publicId: (json['publicId'] as String?)?.trim() ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      reasonCode: RecommendationReasonCodeX.fromKey(
        json['reasonCode'] as String?,
      ),
      reasonText: (json['reasonText'] as String?)?.trim() ?? '',
      generatedAt: (json['generatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'publicId': publicId,
    'score': score,
    'reasonCode': reasonCode.key,
    'reasonText': reasonText,
    'generatedAt': generatedAt,
  };
}

class RecommendationDailySet {
  const RecommendationDailySet({
    required this.dateKey,
    required this.mode,
    required this.entries,
    this.manualRefreshCount = 0,
    this.lastRefreshAt,
  });

  final String dateKey;
  final RecommendationMode mode;
  final List<RecommendationEntry> entries;
  final int manualRefreshCount;
  final int? lastRefreshAt;

  RecommendationDailySet copyWith({
    String? dateKey,
    RecommendationMode? mode,
    List<RecommendationEntry>? entries,
    int? manualRefreshCount,
    int? lastRefreshAt,
    bool clearLastRefreshAt = false,
  }) {
    return RecommendationDailySet(
      dateKey: dateKey ?? this.dateKey,
      mode: mode ?? this.mode,
      entries: entries ?? this.entries,
      manualRefreshCount: manualRefreshCount ?? this.manualRefreshCount,
      lastRefreshAt: clearLastRefreshAt
          ? null
          : (lastRefreshAt ?? this.lastRefreshAt),
    );
  }

  factory RecommendationDailySet.fromJson(Map<String, dynamic> json) {
    final rawEntries = (json['entries'] as List?) ?? const [];
    return RecommendationDailySet(
      dateKey: (json['dateKey'] as String?)?.trim() ?? '',
      mode: RecommendationModeX.fromKey(json['mode'] as String?),
      entries: rawEntries
          .whereType<Map>()
          .map(
            (raw) =>
                RecommendationEntry.fromJson(Map<String, dynamic>.from(raw)),
          )
          .toList(),
      manualRefreshCount: (json['manualRefreshCount'] as num?)?.toInt() ?? 0,
      lastRefreshAt: (json['lastRefreshAt'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'mode': mode.key,
    'entries': entries.map((e) => e.toJson()).toList(),
    'manualRefreshCount': manualRefreshCount,
    'lastRefreshAt': lastRefreshAt,
  };
}

class RecommendationProfile {
  const RecommendationProfile({
    required this.genreWeights,
    required this.regionWeights,
    required this.artistWeights,
    required this.originWeights,
    this.lastComputedAt,
  });

  final Map<String, double> genreWeights;
  final Map<String, double> regionWeights;
  final Map<String, double> artistWeights;
  final Map<String, double> originWeights;
  final int? lastComputedAt;

  factory RecommendationProfile.empty() {
    return const RecommendationProfile(
      genreWeights: <String, double>{},
      regionWeights: <String, double>{},
      artistWeights: <String, double>{},
      originWeights: <String, double>{},
    );
  }

  RecommendationProfile copyWith({
    Map<String, double>? genreWeights,
    Map<String, double>? regionWeights,
    Map<String, double>? artistWeights,
    Map<String, double>? originWeights,
    int? lastComputedAt,
    bool clearLastComputedAt = false,
  }) {
    return RecommendationProfile(
      genreWeights: genreWeights ?? this.genreWeights,
      regionWeights: regionWeights ?? this.regionWeights,
      artistWeights: artistWeights ?? this.artistWeights,
      originWeights: originWeights ?? this.originWeights,
      lastComputedAt: clearLastComputedAt
          ? null
          : (lastComputedAt ?? this.lastComputedAt),
    );
  }

  factory RecommendationProfile.fromJson(Map<String, dynamic> json) {
    return RecommendationProfile(
      genreWeights: _readDoubleMap(json['genreWeights']),
      regionWeights: _readDoubleMap(json['regionWeights']),
      artistWeights: _readDoubleMap(json['artistWeights']),
      originWeights: _readDoubleMap(json['originWeights']),
      lastComputedAt: (json['lastComputedAt'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'genreWeights': genreWeights,
    'regionWeights': regionWeights,
    'artistWeights': artistWeights,
    'originWeights': originWeights,
    'lastComputedAt': lastComputedAt,
  };

  static Map<String, double> _readDoubleMap(dynamic raw) {
    if (raw is! Map) return <String, double>{};
    final result = <String, double>{};
    raw.forEach((key, value) {
      final cleanKey = key.toString().trim();
      if (cleanKey.isEmpty) return;
      final number = value is num
          ? value.toDouble()
          : double.tryParse('$value');
      if (number == null) return;
      result[cleanKey] = number;
    });
    return result;
  }
}

class RecommendationState {
  const RecommendationState({
    required this.installId,
    required this.profile,
    required this.dailySets,
  });

  final String installId;
  final RecommendationProfile profile;
  final Map<String, RecommendationDailySet> dailySets;

  factory RecommendationState.empty() {
    return RecommendationState(
      installId: '',
      profile: RecommendationProfile.empty(),
      dailySets: const <String, RecommendationDailySet>{},
    );
  }

  RecommendationState copyWith({
    String? installId,
    RecommendationProfile? profile,
    Map<String, RecommendationDailySet>? dailySets,
  }) {
    return RecommendationState(
      installId: installId ?? this.installId,
      profile: profile ?? this.profile,
      dailySets: dailySets ?? this.dailySets,
    );
  }

  factory RecommendationState.fromJson(Map<String, dynamic> json) {
    final profileRaw = json['profile'];
    final setsRaw = (json['dailySets'] as List?) ?? const [];
    final sets = <String, RecommendationDailySet>{};
    for (final raw in setsRaw) {
      if (raw is! Map) continue;
      final parsed = RecommendationDailySet.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (parsed.dateKey.isEmpty) continue;
      sets['${parsed.dateKey}|${parsed.mode.key}'] = parsed;
    }
    return RecommendationState(
      installId: (json['installId'] as String?)?.trim() ?? '',
      profile: profileRaw is Map
          ? RecommendationProfile.fromJson(
              Map<String, dynamic>.from(profileRaw),
            )
          : RecommendationProfile.empty(),
      dailySets: sets,
    );
  }

  Map<String, dynamic> toJson() => {
    'installId': installId,
    'profile': profile.toJson(),
    'dailySets': dailySets.values.map((e) => e.toJson()).toList(),
  };
}
