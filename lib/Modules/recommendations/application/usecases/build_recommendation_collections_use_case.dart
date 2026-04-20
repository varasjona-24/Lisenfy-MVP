import 'dart:math';

import '../../../../app/models/media_item.dart';
import '../../domain/recommendation_collection.dart';
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
    required this.dateKey,
    required this.recommendationMode,
    required this.manualRefreshCount,
    required this.hasArtistLocaleMetadata,
    required this.resolveLocaleSignal,
    required this.stableKeyOf,
  });

  final List<RecommendationCollectionSeed> entries;
  final String dateKey;
  final RecommendationMode recommendationMode;
  final int manualRefreshCount;
  final bool hasArtistLocaleMetadata;
  final RecommendationLocaleSignal? Function(MediaItem item)
  resolveLocaleSignal;
  final String Function(MediaItem item) stableKeyOf;
}

class BuildRecommendationCollectionsUseCase {
  const BuildRecommendationCollectionsUseCase();

  static const int _collectionMinItems = 15;
  static const int _collectionMaxCount = 4;

  List<RecommendationCollection> call(
    BuildRecommendationCollectionsInput input,
  ) {
    final entries = input.entries;
    if (entries.isEmpty) return const <RecommendationCollection>[];

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final momentTemplate = _momentTemplate(now.hour);

    final templates = <_RecommendationCollectionTemplate>[
      _RecommendationCollectionTemplate(
        id: 'scene',
        title: 'Escena que te gusta',
        subtitle: 'Por género, región y artistas',
        matcher: (entry) {
          return entry.entry.reasonCode ==
                  RecommendationReasonCode.genreMatch ||
              entry.entry.reasonCode == RecommendationReasonCode.regionMatch ||
              entry.entry.reasonCode == RecommendationReasonCode.artistAffinity;
        },
      ),
      _RecommendationCollectionTemplate(
        id: momentTemplate.id,
        title: momentTemplate.title,
        subtitle: momentTemplate.subtitle,
        matcher: (entry) => _matchesMoment(entry.item, nowMs, now.hour),
      ),
      _RecommendationCollectionTemplate(
        id: 'rediscovery',
        title: 'Redescubiertas',
        subtitle: 'Lo que vale la pena retomar',
        matcher: (entry) => _isRediscovery(entry.item, nowMs),
      ),
      _RecommendationCollectionTemplate(
        id: 'discovery',
        title: 'Para descubrir',
        subtitle: 'Nuevas para rotar hoy',
        matcher: _isDiscoveryCandidate,
      ),
    ];

    final targetCollections = min(
      _collectionMaxCount,
      max(1, min(_collectionMaxCount, entries.length)),
    );
    final enoughForMinPerCollection =
        entries.length >= (targetCollections * _collectionMinItems);
    final perCollectionTarget = enoughForMinPerCollection
        ? max(_collectionMinItems, (entries.length / targetCollections).ceil())
        : max(1, (entries.length / targetCollections).ceil());

    final used = <String>{};
    final collections = <RecommendationCollection>[];

    if (input.hasArtistLocaleMetadata) {
      final byRegion = <String, List<RecommendationCollectionSeed>>{};
      for (final entry in entries) {
        final signal = input.resolveLocaleSignal(entry.item);
        if (signal == null) continue;
        byRegion.putIfAbsent(
          signal.regionKey,
          () => <RecommendationCollectionSeed>[],
        );
        byRegion[signal.regionKey]!.add(entry);
      }

      final orderedRegions = byRegion.entries.toList(growable: false)
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

      if (orderedRegions.isNotEmpty && collections.length < targetCollections) {
        final bucket = _pickRegionalBucket(
          orderedRegions,
          dateKey: input.dateKey,
          recommendationMode: input.recommendationMode,
          manualRefreshCount: input.manualRefreshCount,
        );
        final availableInBucket = bucket.value
            .where((entry) => !used.contains(input.stableKeyOf(entry.item)))
            .toList(growable: false);

        final picks = availableInBucket.take(perCollectionTarget).toList();
        if (picks.isNotEmpty) {
          for (final pick in picks) {
            used.add(input.stableKeyOf(pick.item));
          }

          final regionLabel = _regionMixLabel(bucket.key);
          collections.add(
            RecommendationCollection(
              id: 'regional-${bucket.key}-1',
              title: 'Mix regional $regionLabel',
              subtitle: 'Solo canciones de la region $regionLabel',
              items: picks.map((e) => e.item).toList(growable: false),
            ),
          );
        }
      }
    }

    List<RecommendationCollectionSeed> available() => entries.where((entry) {
      return !used.contains(input.stableKeyOf(entry.item));
    }).toList();

    List<RecommendationCollectionSeed> pickForTemplate(
      _RecommendationCollectionTemplate template,
    ) {
      final free = available();
      if (free.isEmpty) return const <RecommendationCollectionSeed>[];
      final preferred = free.where(template.matcher).toList();

      final picks = <RecommendationCollectionSeed>[];
      final pickedKeys = <String>{};

      for (final entry in preferred) {
        if (picks.length >= perCollectionTarget) break;
        picks.add(entry);
        pickedKeys.add(input.stableKeyOf(entry.item));
      }

      if (picks.length < perCollectionTarget) {
        for (final entry in free) {
          if (picks.length >= perCollectionTarget) break;
          if (pickedKeys.contains(input.stableKeyOf(entry.item))) continue;
          picks.add(entry);
          pickedKeys.add(input.stableKeyOf(entry.item));
        }
      }

      return picks;
    }

    for (final template in templates) {
      if (collections.length >= targetCollections) break;
      final picks = pickForTemplate(template);
      if (picks.isEmpty) continue;

      for (final pick in picks) {
        used.add(input.stableKeyOf(pick.item));
      }

      collections.add(
        RecommendationCollection(
          id: '${template.id}-${collections.length + 1}',
          title: template.title,
          subtitle: template.subtitle,
          items: picks.map((e) => e.item).toList(growable: false),
        ),
      );
    }

    while (collections.length < targetCollections && available().isNotEmpty) {
      final free = available();
      final chunk = free.take(perCollectionTarget).toList();
      for (final entry in chunk) {
        used.add(input.stableKeyOf(entry.item));
      }
      collections.add(
        RecommendationCollection(
          id: 'mix-${collections.length + 1}',
          title: 'Mix diario ${collections.length + 1}',
          subtitle: 'Selección variada de hoy',
          items: chunk.map((e) => e.item).toList(growable: false),
        ),
      );
    }

    if (collections.isEmpty) {
      final fallback = entries
          .take(perCollectionTarget)
          .map((e) => e.item)
          .toList(growable: false);
      collections.add(
        RecommendationCollection(
          id: 'mix-1',
          title: 'Mix diario',
          subtitle: 'Selección recomendada',
          items: fallback,
        ),
      );
    }

    return collections.take(_collectionMaxCount).toList(growable: false);
  }

  MapEntry<String, List<RecommendationCollectionSeed>> _pickRegionalBucket(
    List<MapEntry<String, List<RecommendationCollectionSeed>>> orderedRegions, {
    required String dateKey,
    required RecommendationMode recommendationMode,
    required int manualRefreshCount,
  }) {
    if (orderedRegions.length <= 1) return orderedRegions.first;

    final rotationWindow = min(orderedRegions.length, 3);
    final dayOrdinal = _dayOrdinalFromDateKey(dateKey);
    final modeOffset = recommendationMode == RecommendationMode.audio ? 0 : 1;
    final offset = dayOrdinal + modeOffset + manualRefreshCount;
    final index = offset % rotationWindow;
    return orderedRegions[index];
  }

  int _dayOrdinalFromDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length == 3) {
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (year != null && month != null && day != null) {
        final date = DateTime(year, month, day);
        return date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
      }
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  _MomentTemplate _momentTemplate(int hour) {
    if (hour >= 22 || hour < 6) {
      return const _MomentTemplate(
        id: 'night',
        title: 'Mix nocturno',
        subtitle: 'Retención alta para esta hora',
      );
    }
    if (hour >= 6 && hour < 12) {
      return const _MomentTemplate(
        id: 'morning',
        title: 'Mix para arrancar',
        subtitle: 'Recientes con buena respuesta',
      );
    }
    if (hour >= 12 && hour < 18) {
      return const _MomentTemplate(
        id: 'afternoon',
        title: 'Mix en movimiento',
        subtitle: 'Lo más activo de tu biblioteca',
      );
    }
    return const _MomentTemplate(
      id: 'evening',
      title: 'Mix de tarde',
      subtitle: 'Favoritas y buen avance',
    );
  }

  bool _matchesMoment(MediaItem item, int nowMs, int hour) {
    final retention = _retentionSignal(item);
    final recentSignal = _recentSignal(item, nowMs);
    final playSignal = (item.playCount / 30).clamp(0.0, 1.0);
    final favoriteSignal = item.isFavorite ? 1.0 : 0.0;

    if (hour >= 22 || hour < 6) {
      return retention >= 0.58 && _skipRate(item) <= 0.6;
    }
    if (hour >= 6 && hour < 12) {
      return recentSignal >= 0.45 || (playSignal >= 0.2 && retention >= 0.45);
    }
    if (hour >= 12 && hour < 18) {
      return playSignal >= 0.35 || recentSignal >= 0.55;
    }
    return favoriteSignal >= 0.9 || (retention >= 0.52 && recentSignal >= 0.3);
  }

  bool _isRediscovery(MediaItem item, int nowMs) {
    final hasHistory = item.playCount > 0 || item.fullListenCount > 0;
    if (!hasHistory) return false;
    final ts = item.lastPlayedAt ?? 0;
    if (ts <= 0) return true;
    final ageDays = (nowMs - ts) / const Duration(days: 1).inMilliseconds;
    return ageDays >= 21;
  }

  bool _isDiscoveryCandidate(RecommendationCollectionSeed entry) {
    final item = entry.item;
    final reason = entry.entry.reasonCode;
    final lowHistory = (item.playCount + item.fullListenCount) <= 2;
    final lowSkip = _skipRate(item) <= 0.7;
    final freshReason =
        reason == RecommendationReasonCode.freshPick ||
        reason == RecommendationReasonCode.coldStart;
    return freshReason || (lowHistory && lowSkip && !item.isFavorite);
  }

  double _recentSignal(MediaItem item, int nowMs) {
    final ts = item.lastPlayedAt ?? 0;
    if (ts <= 0) return 0;
    final ageHours = max(
      0,
      ((nowMs - ts) / const Duration(hours: 1).inMilliseconds).round(),
    );
    if (ageHours <= 24) return 1;
    if (ageHours <= 24 * 3) return 0.85;
    if (ageHours <= 24 * 7) return 0.65;
    if (ageHours <= 24 * 14) return 0.45;
    return 0.2;
  }

  double _skipRate(MediaItem item) {
    final denominator = item.fullListenCount + item.skipCount;
    if (denominator <= 0) return 0;
    return (item.skipCount / denominator).clamp(0.0, 1.0).toDouble();
  }

  double _retentionSignal(MediaItem item) {
    final progress = item.avgListenProgress.clamp(0.0, 1.0).toDouble();
    final completionRate = item.fullListenCount + item.skipCount <= 0
        ? progress
        : (item.fullListenCount / (item.fullListenCount + item.skipCount))
              .clamp(0.0, 1.0)
              .toDouble();
    return ((completionRate * 0.6) + (progress * 0.4)) *
        (1 - (_skipRate(item) * 0.55));
  }

  String _regionMixLabel(String regionKey) {
    switch (regionKey.trim().toLowerCase()) {
      case 'latino':
        return 'latino';
      case 'asiatico':
        return 'asiatico';
      case 'anglo':
        return 'anglo';
      case 'europeo':
        return 'euro';
      case 'africano':
        return 'africano';
      case 'medio_oriente':
        return 'medio oriente';
      case 'oceania':
        return 'oceania';
      case 'global':
        return 'global';
      default:
        return regionKey;
    }
  }
}

class _RecommendationCollectionTemplate {
  _RecommendationCollectionTemplate({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.matcher,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool Function(RecommendationCollectionSeed entry) matcher;
}

class _MomentTemplate {
  const _MomentTemplate({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}
