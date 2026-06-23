enum RecommendationMixType {
  region,
  imports,
  timeOfDay,
  rediscovery,
  musicalGeography,
  stan,
}

extension RecommendationMixTypeX on RecommendationMixType {
  String get key => switch (this) {
    RecommendationMixType.region => 'region',
    RecommendationMixType.imports => 'imports',
    RecommendationMixType.timeOfDay => 'time_of_day',
    RecommendationMixType.rediscovery => 'rediscovery',
    RecommendationMixType.musicalGeography => 'musical_geography',
    RecommendationMixType.stan => 'stan',
  };

  static RecommendationMixType fromKey(String? raw) {
    return switch ((raw ?? '').trim()) {
      'region' => RecommendationMixType.region,
      'imports' => RecommendationMixType.imports,
      'rediscovery' => RecommendationMixType.rediscovery,
      'musical_geography' => RecommendationMixType.musicalGeography,
      'stan' => RecommendationMixType.stan,
      _ => RecommendationMixType.timeOfDay,
    };
  }
}

class RecommendationMixPlan {
  const RecommendationMixPlan({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.itemKeys,
    required this.generatedAt,
    this.regionKey,
    this.carryCyclesRemaining = 0,
  });

  final String id;
  final RecommendationMixType type;
  final String title;
  final String subtitle;
  final List<String> itemKeys;
  final int generatedAt;
  final String? regionKey;
  final int carryCyclesRemaining;

  RecommendationMixPlan copyWith({int? carryCyclesRemaining}) {
    return RecommendationMixPlan(
      id: id,
      type: type,
      title: title,
      subtitle: subtitle,
      itemKeys: itemKeys,
      generatedAt: generatedAt,
      regionKey: regionKey,
      carryCyclesRemaining: carryCyclesRemaining ?? this.carryCyclesRemaining,
    );
  }

  factory RecommendationMixPlan.fromJson(Map<String, dynamic> json) {
    return RecommendationMixPlan(
      id: (json['id'] as String?)?.trim() ?? '',
      type: RecommendationMixTypeX.fromKey(json['type'] as String?),
      title: (json['title'] as String?)?.trim() ?? '',
      subtitle: (json['subtitle'] as String?)?.trim() ?? '',
      itemKeys: ((json['itemKeys'] as List?) ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      generatedAt: (json['generatedAt'] as num?)?.toInt() ?? 0,
      regionKey: (json['regionKey'] as String?)?.trim(),
      carryCyclesRemaining:
          (json['carryCyclesRemaining'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.key,
    'title': title,
    'subtitle': subtitle,
    'itemKeys': itemKeys,
    'generatedAt': generatedAt,
    'regionKey': regionKey,
    'carryCyclesRemaining': carryCyclesRemaining,
  };
}

class RecommendationMixCycle {
  const RecommendationMixCycle({
    required this.id,
    required this.startedAt,
    required this.expiresAt,
    required this.mixes,
  });

  final String id;
  final int startedAt;
  final int expiresAt;
  final List<RecommendationMixPlan> mixes;

  factory RecommendationMixCycle.fromJson(Map<String, dynamic> json) {
    return RecommendationMixCycle(
      id: (json['id'] as String?)?.trim() ?? '',
      startedAt: (json['startedAt'] as num?)?.toInt() ?? 0,
      expiresAt: (json['expiresAt'] as num?)?.toInt() ?? 0,
      mixes: ((json['mixes'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (raw) =>
                RecommendationMixPlan.fromJson(Map<String, dynamic>.from(raw)),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt,
    'expiresAt': expiresAt,
    'mixes': mixes.map((mix) => mix.toJson()).toList(),
  };
}

class RecommendationMixHistoryEntry {
  const RecommendationMixHistoryEntry({
    required this.mixId,
    required this.type,
    required this.generatedAt,
    required this.itemKeys,
    this.regionKey,
    this.openedAt,
  });

  final String mixId;
  final RecommendationMixType type;
  final int generatedAt;
  final List<String> itemKeys;
  final String? regionKey;
  final int? openedAt;

  RecommendationMixHistoryEntry copyWith({int? openedAt}) {
    return RecommendationMixHistoryEntry(
      mixId: mixId,
      type: type,
      generatedAt: generatedAt,
      itemKeys: itemKeys,
      regionKey: regionKey,
      openedAt: openedAt ?? this.openedAt,
    );
  }

  factory RecommendationMixHistoryEntry.fromJson(Map<String, dynamic> json) {
    return RecommendationMixHistoryEntry(
      mixId: (json['mixId'] as String?)?.trim() ?? '',
      type: RecommendationMixTypeX.fromKey(json['type'] as String?),
      generatedAt: (json['generatedAt'] as num?)?.toInt() ?? 0,
      itemKeys: ((json['itemKeys'] as List?) ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      regionKey: (json['regionKey'] as String?)?.trim(),
      openedAt: (json['openedAt'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'mixId': mixId,
    'type': type.key,
    'generatedAt': generatedAt,
    'itemKeys': itemKeys,
    'regionKey': regionKey,
    'openedAt': openedAt,
  };
}

class RecommendationMixState {
  const RecommendationMixState({this.activeCycle, required this.history});

  final RecommendationMixCycle? activeCycle;
  final List<RecommendationMixHistoryEntry> history;

  factory RecommendationMixState.empty() {
    return const RecommendationMixState(history: []);
  }

  RecommendationMixState copyWith({
    RecommendationMixCycle? activeCycle,
    List<RecommendationMixHistoryEntry>? history,
  }) {
    return RecommendationMixState(
      activeCycle: activeCycle ?? this.activeCycle,
      history: history ?? this.history,
    );
  }

  factory RecommendationMixState.fromJson(Map<String, dynamic> json) {
    final cycleRaw = json['activeCycle'];
    return RecommendationMixState(
      activeCycle: cycleRaw is Map
          ? RecommendationMixCycle.fromJson(Map<String, dynamic>.from(cycleRaw))
          : null,
      history: ((json['history'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (raw) => RecommendationMixHistoryEntry.fromJson(
              Map<String, dynamic>.from(raw),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'activeCycle': activeCycle?.toJson(),
    'history': history.map((entry) => entry.toJson()).toList(),
  };
}
