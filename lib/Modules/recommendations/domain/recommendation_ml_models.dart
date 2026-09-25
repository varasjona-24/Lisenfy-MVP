import 'dart:math';

class RecommendationMlFeatures {
  const RecommendationMlFeatures(this._values)
    : assert(_values.length == featureCount);

  static const schemaVersion = 2;
  static const featureCount = 14;
  static const featureNames = <String>[
    'previousPlayCount',
    'previousCompletionRate',
    'previousSkipRate',
    'previousAverageProgress',
    'daysSinceLastPlayed',
    'genreAffinity',
    'artistAffinity',
    'regionAffinity',
    'originAffinity',
    'daypartArtistAffinity',
    'daypartGenreAffinity',
    'trackRecentFrequency',
    'novelty',
    'profileConfidence',
  ];

  final List<double> _values;

  List<double> toVector() => _values
      .map((value) => value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0)
      .toList(growable: false);
}

class RecommendationMlTrainingExample {
  const RecommendationMlTrainingExample({
    required this.stableKey,
    required this.trackKey,
    required this.features,
    required this.target,
    required this.sampleWeight,
    required this.sourceEventCount,
  });
  final String stableKey;
  final String trackKey;
  final RecommendationMlFeatures features;
  final double target;
  final double sampleWeight;
  final int sourceEventCount;
}

class RecommendationMlPrediction {
  const RecommendationMlPrediction({
    required this.score,
    required this.confidence,
  });
  final double score;
  final double confidence;
}

class RecommendationMlDiagnostics {
  const RecommendationMlDiagnostics({
    required this.isReady,
    required this.state,
  });
  final bool isReady;
  final RecommendationMlModelState state;
}

class RecommendationMlModelState {
  const RecommendationMlModelState({
    required this.weights,
    required this.bias,
    required this.featureSchemaVersion,
    required this.trainedAt,
    required this.datasetSignature,
    required this.exampleCount,
    required this.sourceEventCount,
    required this.uniqueTrackCount,
    required this.targetVariance,
    required this.trainingLoss,
    required this.confidence,
  });

  final List<double> weights;
  final double bias;
  final int featureSchemaVersion;
  final int trainedAt;
  final String datasetSignature;
  final int exampleCount;
  final int sourceEventCount;
  final int uniqueTrackCount;
  final double targetVariance;
  final double trainingLoss;
  final double confidence;

  factory RecommendationMlModelState.empty() =>
      const RecommendationMlModelState(
        weights: <double>[],
        bias: 0,
        featureSchemaVersion: RecommendationMlFeatures.schemaVersion,
        trainedAt: 0,
        datasetSignature: '',
        exampleCount: 0,
        sourceEventCount: 0,
        uniqueTrackCount: 0,
        targetVariance: 0,
        trainingLoss: 0,
        confidence: 0,
      );

  bool get isValid =>
      weights.length == RecommendationMlFeatures.featureCount &&
      featureSchemaVersion == RecommendationMlFeatures.schemaVersion &&
      weights.every((value) => value.isFinite) &&
      bias.isFinite &&
      confidence.isFinite;

  RecommendationMlModelState copyWith({
    List<double>? weights,
    double? bias,
    int? featureSchemaVersion,
    int? trainedAt,
    String? datasetSignature,
    int? exampleCount,
    int? sourceEventCount,
    int? uniqueTrackCount,
    double? targetVariance,
    double? trainingLoss,
    double? confidence,
  }) => RecommendationMlModelState(
    weights: weights ?? this.weights,
    bias: bias ?? this.bias,
    featureSchemaVersion: featureSchemaVersion ?? this.featureSchemaVersion,
    trainedAt: trainedAt ?? this.trainedAt,
    datasetSignature: datasetSignature ?? this.datasetSignature,
    exampleCount: exampleCount ?? this.exampleCount,
    sourceEventCount: sourceEventCount ?? this.sourceEventCount,
    uniqueTrackCount: uniqueTrackCount ?? this.uniqueTrackCount,
    targetVariance: targetVariance ?? this.targetVariance,
    trainingLoss: trainingLoss ?? this.trainingLoss,
    confidence: confidence ?? this.confidence,
  );

  factory RecommendationMlModelState.fromJson(Map<String, dynamic> json) {
    final rawWeights = json['weights'] as List? ?? const [];
    return RecommendationMlModelState(
      weights: rawWeights
          .map((value) => value is num ? value.toDouble() : double.nan)
          .toList(),
      bias: (json['bias'] as num?)?.toDouble() ?? double.nan,
      featureSchemaVersion:
          (json['featureSchemaVersion'] as num?)?.toInt() ?? 0,
      trainedAt: (json['trainedAt'] as num?)?.toInt() ?? 0,
      datasetSignature: (json['datasetSignature'] as String?) ?? '',
      exampleCount: (json['exampleCount'] as num?)?.toInt() ?? 0,
      sourceEventCount: (json['sourceEventCount'] as num?)?.toInt() ?? 0,
      uniqueTrackCount: (json['uniqueTrackCount'] as num?)?.toInt() ?? 0,
      targetVariance: (json['targetVariance'] as num?)?.toDouble() ?? 0,
      trainingLoss: (json['trainingLoss'] as num?)?.toDouble() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'weights': weights,
    'bias': bias,
    'featureSchemaVersion': featureSchemaVersion,
    'trainedAt': trainedAt,
    'datasetSignature': datasetSignature,
    'exampleCount': exampleCount,
    'sourceEventCount': sourceEventCount,
    'uniqueTrackCount': uniqueTrackCount,
    'targetVariance': targetVariance,
    'trainingLoss': trainingLoss,
    'confidence': confidence,
  };
}

class RecommendationMlState {
  const RecommendationMlState(this.models);
  final Map<String, RecommendationMlModelState> models;
  factory RecommendationMlState.empty() => const RecommendationMlState({});
  factory RecommendationMlState.fromJson(Map<String, dynamic> json) {
    final raw = json['models'];
    if (raw is! Map) return RecommendationMlState.empty();
    final models = <String, RecommendationMlModelState>{};
    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      models[entry.key.toString()] = RecommendationMlModelState.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
    }
    return RecommendationMlState(models);
  }
  Map<String, dynamic> toJson() => {
    'models': models.map((key, value) => MapEntry(key, value.toJson())),
  };
  RecommendationMlState withModel(
    String mode,
    RecommendationMlModelState model,
  ) => RecommendationMlState({...models, mode: model});
}

double mlClamp(double value) =>
    value.isFinite ? value.clamp(0.0, 1.0).toDouble() : 0.0;
double mlVariance(List<double> values) {
  if (values.isEmpty) return 0;
  final mean = values.reduce((a, b) => a + b) / values.length;
  return values.map((value) => pow(value - mean, 2)).reduce((a, b) => a + b) /
      values.length;
}
