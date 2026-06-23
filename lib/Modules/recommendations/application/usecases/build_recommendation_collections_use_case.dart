import 'dart:math';

import '../../../../app/models/media_item.dart';
import '../../../../app/utils/artist_credit_parser.dart';
import '../../data/recommendation_mix_store.dart';
import '../../data/listening_event_store.dart';
import '../../domain/recommendation_collection.dart';
import '../../domain/recommendation_mix_models.dart';
import '../../domain/recommendation_models.dart';

class RecommendationCollectionSeed {
  const RecommendationCollectionSeed({required this.item, required this.entry});

  final MediaItem item;
  final RecommendationEntry entry;
}

class RecommendationLocaleSignal {
  const RecommendationLocaleSignal({required this.regionKey, this.countryName});

  final String regionKey;
  final String? countryName;
}

class BuildRecommendationCollectionsInput {
  const BuildRecommendationCollectionsInput({
    required this.entries,
    required this.library,
    required this.resolveLocaleSignal,
    required this.stableKeyOf,
    required this.now,
  });

  final List<RecommendationCollectionSeed> entries;
  final List<MediaItem> library;
  final RecommendationLocaleSignal? Function(MediaItem item)
  resolveLocaleSignal;
  final String Function(MediaItem item) stableKeyOf;
  final DateTime now;
}

class BuildRecommendationCollectionsUseCase {
  BuildRecommendationCollectionsUseCase({
    required RecommendationMixStore store,
    required ListeningEventStore listeningEventStore,
  }) : _store = store,
       _listeningEventStore = listeningEventStore;

  static const _minimumLibrarySize = 60;
  static const _cycleDuration = Duration(hours: 15);
  static const _historyRetention = Duration(days: 120);
  static const _recentArtistWindow = Duration(days: 21);

  final RecommendationMixStore _store;
  final ListeningEventStore _listeningEventStore;

  Future<List<RecommendationCollection>> call(
    BuildRecommendationCollectionsInput input,
  ) async {
    final library = input.library
        .where((item) => item.hasAudioLocal)
        .toList(growable: false);
    if (library.length < _minimumLibrarySize) {
      return const <RecommendationCollection>[];
    }

    final nowMs = input.now.millisecondsSinceEpoch;
    final targetSize = _targetSize(library.length);
    var state = await _store.read();
    state = _pruneHistory(state, nowMs);

    final byKey = <String, MediaItem>{
      for (final item in library) input.stableKeyOf(item): item,
    };
    final active = state.activeCycle;
    if (active != null && active.expiresAt > nowMs) {
      final resolved = _resolveCycle(active, byKey, targetSize);
      if (resolved.isNotEmpty) return resolved;
    }

    final rankedScore = <String, double>{
      for (final seed in input.entries)
        input.stableKeyOf(seed.item): seed.entry.score,
    };
    final context = _BuildContext(
      input: input,
      library: library,
      byKey: byKey,
      rankedScore: rankedScore,
      state: state,
      targetSize: targetSize,
      nowMs: nowMs,
      seed: _seedFor(input.now, state.history.length),
      listeningEvents: _listeningEventStore.readAll(),
    );

    final selected = <RecommendationMixPlan>[];
    final usedThisCycle = <String>{};
    final carried = _carryRegionalMix(context);
    if (carried != null) {
      selected.add(carried);
      usedThisCycle.addAll(carried.itemKeys);
    }

    final candidates = <_MixCandidate?>[
      _buildRegionCandidate(context, usedThisCycle),
      _buildImportsCandidate(context, usedThisCycle),
      _buildTimeCandidate(context, usedThisCycle),
      _buildRediscoveryCandidate(context, usedThisCycle),
      _buildGeographyCandidate(context, usedThisCycle),
      _buildStanCandidate(context, usedThisCycle),
    ].whereType<_MixCandidate>().toList();

    candidates.sort((a, b) => b.priority.compareTo(a.priority));
    for (final candidate in candidates) {
      if (selected.length >= 2) break;
      if (selected.any((mix) => mix.type == candidate.type)) continue;
      final refreshed = candidate.rebuild(usedThisCycle);
      if (refreshed == null) continue;
      selected.add(refreshed);
      usedThisCycle.addAll(refreshed.itemKeys);
    }

    if (selected.isEmpty) return const <RecommendationCollection>[];

    final cycle = RecommendationMixCycle(
      id: 'cycle-$nowMs',
      startedAt: nowMs,
      expiresAt: nowMs + _cycleDuration.inMilliseconds,
      mixes: selected,
    );
    final additions = selected
        .where((mix) => mix.generatedAt == nowMs)
        .map(
          (mix) => RecommendationMixHistoryEntry(
            mixId: mix.id,
            type: mix.type,
            generatedAt: mix.generatedAt,
            itemKeys: mix.itemKeys,
            regionKey: mix.regionKey,
          ),
        );
    await _store.write(
      RecommendationMixState(
        activeCycle: cycle,
        history: [...state.history, ...additions],
      ),
    );
    return _resolveCycle(cycle, byKey, targetSize);
  }

  Future<void> markOpened(String mixId, {DateTime? at}) {
    return _store.markOpened(
      mixId,
      (at ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  RecommendationMixPlan? _carryRegionalMix(_BuildContext context) {
    final previous = context.state.activeCycle;
    if (previous == null) return null;
    for (final mix in previous.mixes) {
      if (mix.type != RecommendationMixType.region ||
          mix.carryCyclesRemaining <= 0) {
        continue;
      }
      final available = mix.itemKeys
          .where(context.byKey.containsKey)
          .take(context.targetSize)
          .toList(growable: false);
      if (available.length < context.targetSize) return null;
      return RecommendationMixPlan(
        id: mix.id,
        type: mix.type,
        title: mix.title,
        subtitle: '${mix.subtitle} · segundo ciclo',
        itemKeys: available,
        generatedAt: mix.generatedAt,
        regionKey: mix.regionKey,
        carryCyclesRemaining: mix.carryCyclesRemaining - 1,
      );
    }
    return null;
  }

  _MixCandidate? _buildRegionCandidate(
    _BuildContext context,
    Set<String> used,
  ) {
    final weekCount = context.countThisWeek(RecommendationMixType.region);
    if (weekCount >= 3) return null;

    final byRegion = context.itemsByRegion;
    final localizedCount = byRegion.values.fold<int>(
      0,
      (sum, items) => sum + items.length,
    );
    if (localizedCount < 30) return null;

    final eligible = byRegion.entries
        .where((entry) => entry.value.length >= context.targetSize)
        .where((entry) => !_regionIsResting(context, entry.key))
        .toList();
    if (eligible.isEmpty) return null;

    eligible.sort((a, b) {
      final aLast = context.lastRegionUse(a.key);
      final bLast = context.lastRegionUse(b.key);
      final byAge = aLast.compareTo(bLast);
      if (byAge != 0) return byAge;
      return b.value.length.compareTo(a.value.length);
    });
    final region = eligible.first;

    RecommendationMixPlan? build(Set<String> currentUsed) {
      final picks = context.pick(
        region.value,
        currentUsed,
        salt: 'region-${region.key}',
      );
      if (picks.length < context.targetSize) return null;
      final label = _regionLabel(region.key);
      return context.plan(
        type: RecommendationMixType.region,
        title: 'Mix $label',
        subtitle: 'Una ruta completa por la región $label',
        picks: picks,
        regionKey: region.key,
        carryCyclesRemaining: 1,
      );
    }

    return _MixCandidate(
      priority: weekCount < 2 ? 98 : 62,
      type: RecommendationMixType.region,
      rebuild: build,
    );
  }

  bool _regionIsResting(_BuildContext context, String regionKey) {
    final regionCount = context.itemsByRegion.length;
    if (regionCount <= 3) return false;
    final openedAt = context.lastOpenedRegion(regionKey);
    if (openedAt <= 0) return false;
    final rest = regionCount >= 6
        ? const Duration(days: 14)
        : const Duration(days: 7);
    return context.nowMs - openedAt < rest.inMilliseconds;
  }

  _MixCandidate? _buildImportsCandidate(
    _BuildContext context,
    Set<String> used,
  ) {
    final weekCount = context.countThisWeek(RecommendationMixType.imports);
    if (weekCount >= 2) return null;

    List<MediaItem> candidates = const [];
    var label = '';
    for (final days in const [15, 30, 45]) {
      final cutoff = context.nowMs - Duration(days: days).inMilliseconds;
      candidates = context.library
          .where((item) => _latestImportAt(item) >= cutoff)
          .toList();
      if (candidates.length >= context.targetSize) {
        label = 'Importadas en los últimos $days días';
        break;
      }
    }

    if (candidates.length < context.targetSize) {
      final cutoff = context.nowMs - const Duration(days: 120).inMilliseconds;
      candidates = context.library.where((item) {
        return _latestImportAt(item) >= cutoff &&
            (item.lastPlayedAt == null || item.lastPlayedAt == 0);
      }).toList();
      label = 'Joyas nuevas que todavía no escuchaste';
    }
    if (candidates.length < context.targetSize) return null;

    candidates.sort((a, b) => _latestImportAt(b).compareTo(_latestImportAt(a)));
    RecommendationMixPlan? build(Set<String> currentUsed) {
      final picks = context.pick(candidates, currentUsed, salt: 'imports');
      if (picks.length < context.targetSize) return null;
      return context.plan(
        type: RecommendationMixType.imports,
        title: 'Tus importaciones',
        subtitle: label,
        picks: picks,
      );
    }

    return _MixCandidate(
      priority: weekCount == 0 ? 82 : 34,
      type: RecommendationMixType.imports,
      rebuild: build,
    );
  }

  _MixCandidate? _buildTimeCandidate(_BuildContext context, Set<String> used) {
    final moment = _moment(context.input.now);
    final candidates = [...context.library]
      ..sort((a, b) {
        final aScore = _momentScore(a, moment.$1);
        final bScore = _momentScore(b, moment.$1);
        return bScore.compareTo(aScore);
      });

    RecommendationMixPlan? build(Set<String> currentUsed) {
      final picks = context.pick(
        candidates,
        currentUsed,
        salt: 'moment-${moment.$1}',
      );
      if (picks.length < context.targetSize) return null;
      return context.plan(
        type: RecommendationMixType.timeOfDay,
        title: moment.$2,
        subtitle: moment.$3,
        picks: picks,
      );
    }

    return _MixCandidate(
      priority: 70 + _stalenessBonus(context, RecommendationMixType.timeOfDay),
      type: RecommendationMixType.timeOfDay,
      rebuild: build,
    );
  }

  _MixCandidate? _buildRediscoveryCandidate(
    _BuildContext context,
    Set<String> used,
  ) {
    final cutoff = context.nowMs - const Duration(days: 21).inMilliseconds;
    final candidates =
        context.library.where((item) {
          final last = item.lastPlayedAt ?? 0;
          return last == 0 || last <= cutoff;
        }).toList()..sort((a, b) {
          final plays = a.playCount.compareTo(b.playCount);
          if (plays != 0) return plays;
          return (a.lastPlayedAt ?? 0).compareTo(b.lastPlayedAt ?? 0);
        });
    if (candidates.length < context.targetSize) {
      final extras = [...context.library]
        ..sort((a, b) => a.playCount.compareTo(b.playCount));
      for (final item in extras) {
        if (!candidates.contains(item)) candidates.add(item);
      }
    }

    RecommendationMixPlan? build(Set<String> currentUsed) {
      final picks = context.pick(candidates, currentUsed, salt: 'rediscovery');
      if (picks.length < context.targetSize) return null;
      return context.plan(
        type: RecommendationMixType.rediscovery,
        title: 'Redescubiertas',
        subtitle: 'Canciones que llevan al menos tres semanas esperando',
        picks: picks,
      );
    }

    return _MixCandidate(
      priority:
          64 + _stalenessBonus(context, RecommendationMixType.rediscovery),
      type: RecommendationMixType.rediscovery,
      rebuild: build,
    );
  }

  _MixCandidate? _buildGeographyCandidate(
    _BuildContext context,
    Set<String> used,
  ) {
    final eventCountByRegion = <String, int>{};
    for (final event in context.listeningEvents) {
      final item = context.byKey[event.trackKey];
      if (item == null) continue;
      final region = context.input.resolveLocaleSignal(item)?.regionKey;
      if (region == null || region.isEmpty) continue;
      eventCountByRegion[region] = (eventCountByRegion[region] ?? 0) + 1;
    }
    final regions =
        context.itemsByRegion.entries
            .map(
              (entry) => MapEntry(
                entry.key,
                eventCountByRegion[entry.key] ??
                    entry.value.fold<int>(
                      0,
                      (sum, item) => sum + item.playCount,
                    ),
              ),
            )
            .where((entry) => entry.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final selectedRegions = regions.take(4).map((entry) => entry.key).toList();
    if (selectedRegions.length < 2) return null;

    final candidates = <MediaItem>[];
    var index = 0;
    while (true) {
      var added = false;
      for (final region in selectedRegions) {
        final bucket = [...context.itemsByRegion[region]!]
          ..sort((a, b) => b.playCount.compareTo(a.playCount));
        if (index < bucket.length) {
          candidates.add(bucket[index]);
          added = true;
        }
      }
      if (!added) break;
      index++;
    }
    if (candidates.length < context.targetSize) return null;

    RecommendationMixPlan? build(Set<String> currentUsed) {
      final picks = context.pick(candidates, currentUsed, salt: 'geography');
      if (picks.length < context.targetSize) return null;
      return context.plan(
        type: RecommendationMixType.musicalGeography,
        title: 'Tu geografía musical',
        subtitle: 'Tus ${selectedRegions.length} regiones más escuchadas',
        picks: picks,
      );
    }

    return _MixCandidate(
      priority:
          58 + _stalenessBonus(context, RecommendationMixType.musicalGeography),
      type: RecommendationMixType.musicalGeography,
      rebuild: build,
    );
  }

  _MixCandidate? _buildStanCandidate(_BuildContext context, Set<String> used) {
    final recentCutoff = context.nowMs - _recentArtistWindow.inMilliseconds;
    final recentScores = <String, int>{};
    final totalScores = <String, int>{};
    final byArtist = <String, List<MediaItem>>{};
    for (final item in context.library) {
      final artist = _artistKey(item);
      if (artist.isEmpty || artist == 'unknown') continue;
      byArtist.putIfAbsent(artist, () => []).add(item);
      totalScores[artist] = (totalScores[artist] ?? 0) + item.playCount;
    }
    for (final event in context.listeningEvents) {
      if (event.occurredAt < recentCutoff) continue;
      final item = context.byKey[event.trackKey];
      if (item == null) continue;
      final artist = _artistKey(item);
      if (artist.isEmpty || artist == 'unknown') continue;
      final weight = event.completed
          ? 3
          : event.skipped
          ? 1
          : max(1, (event.progress * 2).round());
      recentScores[artist] = (recentScores[artist] ?? 0) + weight;
    }
    if (recentScores.isEmpty) {
      for (final item in context.library) {
        if ((item.lastPlayedAt ?? 0) >= recentCutoff) {
          final artist = _artistKey(item);
          if (artist.isEmpty || artist == 'unknown') continue;
          recentScores[artist] =
              (recentScores[artist] ?? 0) + max(1, item.playCount);
        }
      }
    }
    if (byArtist.length < 2 || recentScores.isEmpty) return null;

    final recentArtists = recentScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalArtists = totalScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final recentTarget = (context.targetSize * .7).round();
    final candidates = <MediaItem>[];
    _appendArtistRoundRobin(
      candidates,
      recentArtists.map((entry) => entry.key),
      byArtist,
      recentTarget,
    );
    _appendArtistRoundRobin(
      candidates,
      totalArtists.map((entry) => entry.key),
      byArtist,
      context.targetSize * 2,
    );
    if (candidates.length < context.targetSize) return null;

    RecommendationMixPlan? build(Set<String> currentUsed) {
      final picks = context.pick(candidates, currentUsed, salt: 'stan');
      if (picks.length < context.targetSize) return null;
      return context.plan(
        type: RecommendationMixType.stan,
        title: 'Tu lista de Stan',
        subtitle: '70% obsesiones recientes · 30% favoritos históricos',
        picks: picks,
      );
    }

    return _MixCandidate(
      priority: 61 + _stalenessBonus(context, RecommendationMixType.stan),
      type: RecommendationMixType.stan,
      rebuild: build,
    );
  }

  void _appendArtistRoundRobin(
    List<MediaItem> output,
    Iterable<String> artists,
    Map<String, List<MediaItem>> byArtist,
    int limit,
  ) {
    final queues = artists
        .take(8)
        .map(
          (artist) =>
              [...byArtist[artist]!]
                ..sort((a, b) => b.playCount.compareTo(a.playCount)),
        )
        .toList();
    var index = 0;
    while (output.length < limit && queues.any((queue) => queue.isNotEmpty)) {
      final queue = queues[index % queues.length];
      if (queue.isNotEmpty) {
        final item = queue.removeAt(0);
        if (!output.contains(item)) output.add(item);
      }
      index++;
    }
  }

  List<RecommendationCollection> _resolveCycle(
    RecommendationMixCycle cycle,
    Map<String, MediaItem> byKey,
    int targetSize,
  ) {
    final result = <RecommendationCollection>[];
    for (final mix in cycle.mixes) {
      final items = mix.itemKeys
          .map((key) => byKey[key])
          .whereType<MediaItem>()
          .take(targetSize)
          .toList(growable: false);
      if (items.length < targetSize) continue;
      result.add(
        RecommendationCollection(
          id: mix.id,
          title: mix.title,
          subtitle: mix.subtitle,
          items: items,
          expiresAt: cycle.expiresAt,
        ),
      );
    }
    return result.take(2).toList(growable: false);
  }

  RecommendationMixState _pruneHistory(
    RecommendationMixState state,
    int nowMs,
  ) {
    final cutoff = nowMs - _historyRetention.inMilliseconds;
    return state.copyWith(
      history: state.history
          .where((entry) => entry.generatedAt >= cutoff)
          .toList(growable: false),
    );
  }

  int _targetSize(int count) {
    if (count <= 150) return 10;
    if (count <= 300) return 15;
    return 20;
  }

  int _seedFor(DateTime now, int historyLength) {
    return Object.hash(
      now.year,
      now.month,
      now.day,
      now.hour ~/ 15,
      historyLength,
    );
  }

  int _latestImportAt(MediaItem item) {
    var latest = 0;
    for (final variant in item.variants) {
      if (variant.kind == MediaVariantKind.audio &&
          variant.createdAt > latest) {
        latest = variant.createdAt;
      }
    }
    return latest;
  }

  (String, String, String) _moment(DateTime now) {
    final minutes = (now.hour * 60) + now.minute;
    if (minutes >= 241 && minutes <= 720) {
      return (
        'morning',
        'Mix para arrancar',
        'Energía gradual para empezar el día',
      );
    }
    if (minutes >= 721 && minutes <= 1200) {
      return (
        'movement',
        'Mix en movimiento',
        'Canciones activas para mantener el ritmo',
      );
    }
    return (
      'relax',
      'Mix para relajarse',
      'Selección suave según tu forma de escuchar',
    );
  }

  double _momentScore(MediaItem item, String moment) {
    final retention = item.avgListenProgress.clamp(0.0, 1.0);
    final skipPenalty =
        item.skipCount / max(1, item.playCount + item.skipCount);
    final popularity = min(1.0, item.playCount / 25);
    return switch (moment) {
      'movement' => (popularity * .55) + (retention * .35) - skipPenalty,
      'relax' => (retention * .7) + (item.isFavorite ? .2 : 0) - skipPenalty,
      _ => (retention * .45) + (popularity * .35) - (skipPenalty * .5),
    };
  }

  int _stalenessBonus(_BuildContext context, RecommendationMixType type) {
    final last = context.lastTypeUse(type);
    if (last <= 0) return 20;
    final days = (context.nowMs - last) ~/ Duration.millisecondsPerDay;
    return min(20, days * 3);
  }

  String _artistKey(MediaItem item) {
    final parsed = ArtistCreditParser.parse(item.displaySubtitle);
    return ArtistCreditParser.normalizeKey(parsed.primaryArtist);
  }

  String _regionLabel(String key) {
    return switch (key) {
      'latino' => 'latino',
      'asiatico' => 'asiático',
      'anglo' => 'anglo',
      'europeo' => 'europeo',
      'africano' => 'africano',
      'medio_oriente' => 'de Medio Oriente',
      'oceania' => 'de Oceanía',
      _ => 'global',
    };
  }
}

class _BuildContext {
  _BuildContext({
    required this.input,
    required this.library,
    required this.byKey,
    required this.rankedScore,
    required this.state,
    required this.targetSize,
    required this.nowMs,
    required this.seed,
    required this.listeningEvents,
  });

  final BuildRecommendationCollectionsInput input;
  final List<MediaItem> library;
  final Map<String, MediaItem> byKey;
  final Map<String, double> rankedScore;
  final RecommendationMixState state;
  final int targetSize;
  final int nowMs;
  final int seed;
  final List<ListeningEvent> listeningEvents;

  late final Map<String, List<MediaItem>> itemsByRegion = () {
    final result = <String, List<MediaItem>>{};
    for (final item in library) {
      final signal = input.resolveLocaleSignal(item);
      if (signal == null || signal.regionKey.trim().isEmpty) continue;
      result.putIfAbsent(signal.regionKey, () => []).add(item);
    }
    return result;
  }();

  List<MediaItem> pick(
    List<MediaItem> candidates,
    Set<String> usedThisCycle, {
    required String salt,
  }) {
    final deduped = <String, MediaItem>{};
    for (final item in candidates) {
      final key = input.stableKeyOf(item);
      if (!usedThisCycle.contains(key)) deduped.putIfAbsent(key, () => item);
    }
    final exposure = <String, int>{};
    for (final entry in state.history) {
      for (final key in entry.itemKeys) {
        exposure[key] = max(exposure[key] ?? 0, entry.generatedAt);
      }
    }

    for (final days in const [23, 14, 7, 3, 0]) {
      final cutoff = nowMs - Duration(days: days).inMilliseconds;
      final eligible = deduped.values.where((item) {
        final last = exposure[input.stableKeyOf(item)] ?? 0;
        return days == 0 || last <= cutoff;
      }).toList();
      if (eligible.length < targetSize) continue;
      final position = <String, int>{
        for (var index = 0; index < candidates.length; index++)
          input.stableKeyOf(candidates[index]): index,
      };
      eligible.sort((a, b) {
        final aPosition = position[input.stableKeyOf(a)] ?? candidates.length;
        final bPosition = position[input.stableKeyOf(b)] ?? candidates.length;
        final aContext =
            1 - (aPosition / max(1, candidates.length)).clamp(0.0, 1.0);
        final bContext =
            1 - (bPosition / max(1, candidates.length)).clamp(0.0, 1.0);
        final aScore =
            aContext +
            ((rankedScore[input.stableKeyOf(a)] ?? 0).clamp(-1.0, 1.0) * .2) +
            (_noise(input.stableKeyOf(a), salt) * .25);
        final bScore =
            bContext +
            ((rankedScore[input.stableKeyOf(b)] ?? 0).clamp(-1.0, 1.0) * .2) +
            (_noise(input.stableKeyOf(b), salt) * .25);
        return bScore.compareTo(aScore);
      });
      return eligible.take(targetSize).toList(growable: false);
    }
    return const <MediaItem>[];
  }

  double _noise(String key, String salt) {
    final random = Random(Object.hash(seed, key, salt));
    return random.nextDouble();
  }

  RecommendationMixPlan plan({
    required RecommendationMixType type,
    required String title,
    required String subtitle,
    required List<MediaItem> picks,
    String? regionKey,
    int carryCyclesRemaining = 0,
  }) {
    return RecommendationMixPlan(
      id: '${type.key}-$nowMs-${Object.hash(title, seed).abs()}',
      type: type,
      title: title,
      subtitle: subtitle,
      itemKeys: picks.map(input.stableKeyOf).toList(growable: false),
      generatedAt: nowMs,
      regionKey: regionKey,
      carryCyclesRemaining: carryCyclesRemaining,
    );
  }

  int countThisWeek(RecommendationMixType type) {
    final start = DateTime.fromMillisecondsSinceEpoch(nowMs);
    final day = DateTime(start.year, start.month, start.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return state.history.where((entry) {
      return entry.type == type &&
          entry.generatedAt >= monday.millisecondsSinceEpoch;
    }).length;
  }

  int lastTypeUse(RecommendationMixType type) {
    var latest = 0;
    for (final entry in state.history) {
      if (entry.type == type) latest = max(latest, entry.generatedAt);
    }
    return latest;
  }

  int lastRegionUse(String regionKey) {
    var latest = 0;
    for (final entry in state.history) {
      if (entry.regionKey == regionKey) latest = max(latest, entry.generatedAt);
    }
    return latest;
  }

  int lastOpenedRegion(String regionKey) {
    var latest = 0;
    for (final entry in state.history) {
      if (entry.regionKey == regionKey && entry.openedAt != null) {
        latest = max(latest, entry.openedAt!);
      }
    }
    return latest;
  }
}

class _MixCandidate {
  const _MixCandidate({
    required this.priority,
    required this.type,
    required this.rebuild,
  });

  final int priority;
  final RecommendationMixType type;
  final RecommendationMixPlan? Function(Set<String> used) rebuild;
}
