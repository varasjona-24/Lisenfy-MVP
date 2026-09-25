import 'dart:math';
import '../data/recommendation_ml_store.dart';
import '../domain/contracts/recommendation_ranker.dart';
import '../domain/recommendation_ml_models.dart';
import '../domain/recommendation_models.dart';

class LocalMlRecommendationRanker implements RecommendationRanker {
  LocalMlRecommendationRanker({
    required RecommendationMlStore store,
    DateTime Function()? now,
  }) : _store = store,
       _now = now ?? DateTime.now;
  static const _minimumExamples = 12,
      _minimumEvents = 40,
      _activationExamples = 25,
      _activationEvents = 100;
  static const _minimumVariance = 0.015,
      _initialLearningRate = 0.12,
      _l2 = 0.015,
      _maxEpochs = 80;
  final RecommendationMlStore _store;
  final DateTime Function() _now;
  RecommendationMlState? _state;

  @override
  Future<void> reloadFromStore() async => _state = await _store.readState();
  Future<RecommendationMlState> _ensure() async =>
      _state ??= await _store.readState();

  @override
  Future<void> prepare({
    required RecommendationMode mode,
    required List<RecommendationMlTrainingExample> examples,
  }) async {
    final state = await _ensure();
    final valid =
        examples
            .where(
              (example) =>
                  example.stableKey.isNotEmpty &&
                  example.sampleWeight.isFinite &&
                  example.sampleWeight > 0 &&
                  example.target.isFinite,
            )
            .toList()
          ..sort((a, b) => a.stableKey.compareTo(b.stableKey));
    final events = valid.fold<int>(
      0,
      (sum, example) => sum + example.sourceEventCount,
    );
    final uniqueTracks = valid
        .map((example) => example.trackKey)
        .toSet()
        .length;
    final variance = mlVariance(
      valid.map((example) => mlClamp(example.target)).toList(),
    );
    if (valid.length < _minimumExamples ||
        events < _minimumEvents ||
        variance < _minimumVariance) {
      if (state.models.containsKey(mode.key)) {
        _state = state.withModel(mode.key, RecommendationMlModelState.empty());
        await _store.writeState(_state!);
      }
      return;
    }
    final signature = _signature(mode, valid);
    final previous =
        state.models[mode.key] ?? RecommendationMlModelState.empty();
    if (previous.isValid && previous.datasetSignature == signature) return;
    final trained = _train(
      valid,
      previous,
      signature,
      events,
      uniqueTracks,
      variance,
    );
    if (!trained.isValid) return;
    _state = state.withModel(mode.key, trained);
    await _store.writeState(_state!);
  }

  @override
  RecommendationMlPrediction? predict({
    required RecommendationMode mode,
    required RecommendationMlFeatures features,
  }) {
    final state = _state?.models[mode.key];
    if (state == null || !state.isValid || !_isReady(state)) return null;
    final vector = features.toVector();
    var z = state.bias;
    for (var i = 0; i < vector.length; i++) {
      z += state.weights[i] * vector[i];
    }
    return RecommendationMlPrediction(
      score: _sigmoid(z),
      confidence: state.confidence,
    );
  }

  @override
  RecommendationMlDiagnostics diagnostics({required RecommendationMode mode}) {
    final model =
        _state?.models[mode.key] ?? RecommendationMlModelState.empty();
    return RecommendationMlDiagnostics(
      isReady: model.isValid && _isReady(model),
      state: model,
    );
  }

  bool _isReady(RecommendationMlModelState state) =>
      state.exampleCount >= _activationExamples &&
      state.sourceEventCount >= _activationEvents &&
      state.uniqueTrackCount >= 25 &&
      state.targetVariance >= _minimumVariance;
  RecommendationMlModelState _train(
    List<RecommendationMlTrainingExample> examples,
    RecommendationMlModelState previous,
    String signature,
    int events,
    int uniqueTracks,
    double variance,
  ) {
    var weights = previous.isValid
        ? List<double>.from(previous.weights)
        : List<double>.filled(RecommendationMlFeatures.featureCount, 0);
    var bias = previous.isValid ? previous.bias : 0.0;
    var bestLoss = double.infinity, staleEpochs = 0;
    for (var epoch = 0; epoch < _maxEpochs; epoch++) {
      final gradients = List<double>.filled(weights.length, 0);
      var biasGradient = 0.0, weightSum = 0.0, loss = 0.0;
      for (final example in examples) {
        final vector = example.features.toVector();
        var z = bias;
        for (var i = 0; i < vector.length; i++) {
          z += weights[i] * vector[i];
        }
        final prediction = _sigmoid(z),
            target = mlClamp(example.target),
            sampleWeight = example.sampleWeight.clamp(0.1, 2.5).toDouble();
        final error = (prediction - target) * sampleWeight;
        for (var i = 0; i < vector.length; i++) {
          gradients[i] += error * vector[i];
        }
        biasGradient += error;
        weightSum += sampleWeight;
        loss +=
            sampleWeight *
            (-(target * log(max(prediction, 1e-8))) -
                ((1 - target) * log(max(1 - prediction, 1e-8))));
      }
      final lr = _initialLearningRate / (1 + epoch * 0.03);
      final divisor = max(weightSum, 1.0);
      for (var i = 0; i < weights.length; i++) {
        weights[i] =
            (weights[i] - lr * ((gradients[i] / divisor) + (_l2 * weights[i])))
                .clamp(-6.0, 6.0)
                .toDouble();
      }
      bias = (bias - lr * (biasGradient / divisor)).clamp(-6.0, 6.0).toDouble();
      final normalizedLoss = loss / divisor;
      if ((bestLoss - normalizedLoss).abs() < 0.00001) {
        staleEpochs++;
        if (staleEpochs >= 5) break;
      } else {
        staleEpochs = 0;
      }
      bestLoss = min(bestLoss, normalizedLoss);
    }
    final confidence =
        ((((events - _activationEvents) / 210).clamp(0, 1) * .50) +
                (((uniqueTracks - 25) / 48).clamp(0, 1) * .35) +
                ((variance / .08).clamp(0, 1) * .15))
            .clamp(0, 1)
            .toDouble();
    return RecommendationMlModelState(
      weights: weights,
      bias: bias,
      featureSchemaVersion: RecommendationMlFeatures.schemaVersion,
      trainedAt: _now().millisecondsSinceEpoch,
      datasetSignature: signature,
      exampleCount: examples.length,
      sourceEventCount: events,
      uniqueTrackCount: uniqueTracks,
      targetVariance: variance,
      trainingLoss: bestLoss.isFinite ? bestLoss : 0,
      confidence: confidence,
    );
  }

  String _signature(
    RecommendationMode mode,
    List<RecommendationMlTrainingExample> examples,
  ) {
    var hash = 0x811C9DC5;
    void add(String value) {
      for (final unit in value.codeUnits) {
        hash ^= unit;
        hash = (hash * 0x01000193) & 0x7fffffff;
      }
    }

    add('${mode.key}|${RecommendationMlFeatures.schemaVersion}');
    for (final example in examples) {
      add(
        '${example.stableKey}|${example.trackKey}|${example.target.toStringAsFixed(5)}|${example.sampleWeight.toStringAsFixed(5)}|${example.features.toVector().map((v) => v.toStringAsFixed(5)).join(',')}',
      );
    }
    return hash.toRadixString(16);
  }

  double _sigmoid(double value) {
    final z = value.clamp(-20.0, 20.0);
    return 1 / (1 + exp(-z));
  }
}
