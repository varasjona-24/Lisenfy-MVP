import 'dart:math';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/utils/artist_credit_parser.dart';
import '../../../artists/data/artist_store.dart';
import '../../../sources/controller/sources_controller.dart';
import '../../../world_mode/agent/local_affinity_engine.dart';
import '../../../world_mode/domain/entities/world_region_catalog.dart';

class RankedRowData {
  const RankedRowData({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.maxValue,
    required this.currentValue,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String value;
  final int maxValue;
  final int currentValue;
  final Color color;
}

class ArtistStats {
  const ArtistStats({
    required this.name,
    required this.plays,
    required this.tracks,
  });

  final String name;
  final int plays;
  final int tracks;
}

class ImportArtistStats {
  const ImportArtistStats({
    required this.name,
    required this.imports,
    required this.tracks,
  });

  final String name;
  final int imports;
  final int tracks;
}

class ImportPeak {
  const ImportPeak({required this.label, required this.count});

  final String label;
  final int count;
}

class RegionStats {
  const RegionStats({
    required this.code,
    required this.name,
    required this.plays,
    required this.topTracks,
  });

  final String code;
  final String name;
  final int plays;
  final List<MediaItem> topTracks;
}

class MonthData {
  const MonthData({
    required this.label,
    required this.shortLabel,
    required this.count,
  });

  final String label;
  final String shortLabel;
  final int count;
}

class CollectionStats {
  const CollectionStats({
    required this.name,
    required this.subtitle,
    required this.items,
  });

  final String name;
  final String subtitle;
  final int items;
}

class ListeningStats {
  const ListeningStats({
    required this.totalPlays,
    required this.totalCompleted,
    required this.averageProgressPercent,
    required this.recentTracks,
    required this.totalImportFiles,
    required this.importedAudioFiles,
    required this.importedVideoFiles,
    required this.importedAudioItems,
    required this.importedVideoItems,
    required this.totalImportSizeLabel,
    required this.latestImportLabel,
    required this.topImportedArtistsLastMonth,
    required this.topImportedArtists,
    required this.topImportMonthLabel,
    required this.topImportWeekLabel,
    required this.topImportPeriodDetail,
    required this.videoPlays,
    required this.videoRecentItems,
    required this.topVideos,
    required this.topTrack,
    required this.topTracks,
    required this.topFavoriteTracks,
    required this.topRegions,
    required this.topArtists,
    required this.mostCompleted,
    required this.mostSkipped,
    required this.monthlyImports,
    required this.audioLibraryDurationLabel,
    required this.audioCompletionRateLabel,
    required this.audioImportSizeLabel,
    required this.videoLibraryDurationLabel,
    required this.totalVideoCollections,
    required this.rootVideoCollections,
    required this.videoSubCollections,
    required this.collectionLinkedItems,
    required this.emptyVideoCollections,
    required this.largestCollectionName,
    required this.largestCollectionCount,
    required this.topCollections,
    required this.averageFileSizeLabel,
    required this.mostCommonFormat,
    required this.mostActiveImportWeekday,
    required this.estimatedListeningTimeLabel,
    required this.favoriteTimeOfDay,
    required this.artistDiversityCount,
    required this.organizedVideoPercentageLabel,
    required this.averageVideosPerCollectionLabel,
  });

  final int totalPlays;
  final int totalCompleted;
  final int averageProgressPercent;
  final int recentTracks;
  final int totalImportFiles;
  final int importedAudioFiles;
  final int importedVideoFiles;
  final int importedAudioItems;
  final int importedVideoItems;
  final String totalImportSizeLabel;
  final String latestImportLabel;
  final List<ImportArtistStats> topImportedArtistsLastMonth;
  final List<ImportArtistStats> topImportedArtists;
  final String topImportMonthLabel;
  final String topImportWeekLabel;
  final String topImportPeriodDetail;
  final int videoPlays;
  final int videoRecentItems;
  final List<MediaItem> topVideos;
  final MediaItem? topTrack;
  final List<MediaItem> topTracks;
  final List<MediaItem> topFavoriteTracks;
  final List<RegionStats> topRegions;
  final List<ArtistStats> topArtists;
  final List<MediaItem> mostCompleted;
  final List<MediaItem> mostSkipped;
  final List<MonthData> monthlyImports;

  final String audioLibraryDurationLabel;
  final String audioCompletionRateLabel;
  final String audioImportSizeLabel;
  final String videoLibraryDurationLabel;
  final int totalVideoCollections;
  final int rootVideoCollections;
  final int videoSubCollections;
  final int collectionLinkedItems;
  final int emptyVideoCollections;
  final String largestCollectionName;
  final int largestCollectionCount;
  final List<CollectionStats> topCollections;

  final String averageFileSizeLabel;
  final String mostCommonFormat;
  final String mostActiveImportWeekday;

  final String estimatedListeningTimeLabel;
  final String favoriteTimeOfDay;
  final int artistDiversityCount;

  final String organizedVideoPercentageLabel;
  final String averageVideosPerCollectionLabel;

  bool get hasListeningData =>
      totalPlays > 0 || totalCompleted > 0 || topTracks.isNotEmpty;

  bool get hasAnyData =>
      hasListeningData || totalImportFiles > 0 || totalVideoCollections > 0;

  static ListeningStats fromItems(
    List<MediaItem> items, {
    ArtistStore? artistStore,
    SourcesController? sourcesController,
  }) {
    final audioItems = items
        .where((item) => item.hasAudioLocal)
        .toList(growable: false);
    final videoItems = items
        .where((item) => item.hasVideoLocal && !item.hasAudioLocal)
        .toList(growable: false);

    final listened = audioItems
        .where(
          (item) =>
              item.playCount > 0 ||
              item.fullListenCount > 0 ||
              item.skipCount > 0 ||
              item.avgListenProgress > 0,
        )
        .toList(growable: false);
    final watched = videoItems
        .where(
          (item) =>
              item.playCount > 0 ||
              item.fullListenCount > 0 ||
              item.skipCount > 0 ||
              item.avgListenProgress > 0,
        )
        .toList(growable: false);

    final totalPlays = listened.fold<int>(
      0,
      (sum, item) => sum + item.playCount,
    );
    final totalCompleted = listened.fold<int>(
      0,
      (sum, item) => sum + effectiveCompletedFor(item),
    );
    final progressItems = listened
        .where((item) => item.avgListenProgress > 0)
        .toList(growable: false);
    final averageProgress = progressItems.isEmpty
        ? 0
        : progressItems.fold<double>(
                0,
                (sum, item) => sum + item.avgListenProgress.clamp(0, 1),
              ) /
              progressItems.length;

    final recentCutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    final recentTracks = listened
        .where((item) => (item.lastPlayedAt ?? 0) >= recentCutoff)
        .length;
    final videoRecentItems = watched
        .where((item) => (item.lastPlayedAt ?? 0) >= recentCutoff)
        .length;
    final videoPlays = watched.fold<int>(
      0,
      (sum, item) => sum + item.playCount,
    );

    final byPlays = listened.where((item) => listenScoreFor(item) > 0).toList()
      ..sort((a, b) {
        final plays = listenScoreFor(b).compareTo(listenScoreFor(a));
        if (plays != 0) return plays;
        return (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0);
      });

    final completed =
        listened
            .where((item) => effectiveCompletedFor(item) > 0)
            .toList(growable: false)
          ..sort(
            (a, b) =>
                effectiveCompletedFor(b).compareTo(effectiveCompletedFor(a)),
          );
    final skipped = listened.where((item) => item.skipCount > 0).toList()
      ..sort((a, b) => b.skipCount.compareTo(a.skipCount));
    final importStats = ImportStats.fromItems(items);
    final videosByPlays =
        watched.where((item) => listenScoreFor(item) > 0).toList()
          ..sort((a, b) {
            final plays = listenScoreFor(b).compareTo(listenScoreFor(a));
            if (plays != 0) return plays;
            return (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0);
          });
    final favoritesByPlays =
        listened
            .where((item) => item.isFavorite && listenScoreFor(item) > 0)
            .toList()
          ..sort((a, b) {
            final plays = listenScoreFor(b).compareTo(listenScoreFor(a));
            if (plays != 0) return plays;
            return (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0);
          });
    final topRegions = _buildTopRegions(listened, artistStore: artistStore);
    final monthlyImports = _buildMonthlyImports(importStats.monthCounts);

    final audioDurationSeconds = audioItems.fold<int>(
      0,
      (sum, item) => sum + (item.effectiveDurationSeconds ?? 0),
    );
    final audioLibraryDurationLabel = _formatDuration(audioDurationSeconds);

    final videoDurationSeconds = videoItems.fold<int>(
      0,
      (sum, item) => sum + (item.effectiveDurationSeconds ?? 0),
    );
    final videoLibraryDurationLabel = _formatDuration(videoDurationSeconds);

    final audioCompletionRateLabel = totalPlays == 0
        ? '0% completadas'
        : '${(totalCompleted / totalPlays * 100).toStringAsFixed(0)}% completadas';

    var audioBytes = 0;
    for (final item in audioItems) {
      for (final v in item.variants) {
        if (v.kind == MediaVariantKind.audio) {
          audioBytes += max(v.size ?? 0, 0);
        }
      }
    }
    final audioImportSizeLabel = _formatBytes(audioBytes);

    final topics = sourcesController?.topics ?? const [];
    final playlists = sourcesController?.topicPlaylists ?? const [];
    final totalVideoCollections = topics.length + playlists.length;
    final rootVideoCollections = topics.length;
    final videoSubCollections = playlists.length;

    final allLinkedIds = <String>{
      ...topics.expand((t) => t.itemIds),
      ...playlists.expand((p) => p.itemIds),
    };
    final collectionLinkedItems = allLinkedIds.length;

    final emptyTopics = topics.where((t) => t.itemIds.isEmpty).length;
    final emptyPlaylists = playlists.where((p) => p.itemIds.isEmpty).length;
    final emptyVideoCollections = emptyTopics + emptyPlaylists;

    var largestCount = 0;
    var largestName = 'Ninguna';
    for (final t in topics) {
      if (t.itemIds.length > largestCount) {
        largestCount = t.itemIds.length;
        largestName = t.title;
      }
    }
    for (final p in playlists) {
      if (p.itemIds.length > largestCount) {
        largestCount = p.itemIds.length;
        largestName = p.name;
      }
    }
    final largestCollectionName = largestName;
    final largestCollectionCount = largestCount;

    final allCollections = [
      ...topics.map(
        (t) => CollectionStats(
          name: t.title,
          subtitle: 'Collection',
          items: t.itemIds.length,
        ),
      ),
      ...playlists.map(
        (p) => CollectionStats(
          name: p.name,
          subtitle: 'Sub-collection',
          items: p.itemIds.length,
        ),
      ),
    ];
    allCollections.sort((a, b) => b.items.compareTo(a.items));
    final topCollections = allCollections.take(5).toList();

    final averageFileSizeLabel = importStats.totalFiles == 0
        ? '0 B'
        : _formatBytes(importStats.totalBytes ~/ importStats.totalFiles);

    final formatCounts = <String, int>{};
    final weekdayCounts = <int, int>{};
    for (final item in items) {
      for (final v in item.variants) {
        final fmt = v.format.toLowerCase().trim();
        if (fmt.isNotEmpty) {
          formatCounts[fmt] = (formatCounts[fmt] ?? 0) + 1;
        }
        if (v.createdAt > 0) {
          final dt = DateTime.fromMillisecondsSinceEpoch(v.createdAt);
          weekdayCounts[dt.weekday] = (weekdayCounts[dt.weekday] ?? 0) + 1;
        }
      }
    }
    final mostCommonFormat = formatCounts.isEmpty
        ? tr('wrapped.labels.none')
        : (formatCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key
              .toUpperCase();

    final weekdays = [
      '',
      tr('wrapped.labels.weekdays.monday'),
      tr('wrapped.labels.weekdays.tuesday'),
      tr('wrapped.labels.weekdays.wednesday'),
      tr('wrapped.labels.weekdays.thursday'),
      tr('wrapped.labels.weekdays.friday'),
      tr('wrapped.labels.weekdays.saturday'),
      tr('wrapped.labels.weekdays.sunday'),
    ];
    final mostActiveImportWeekday = weekdayCounts.isEmpty
        ? tr('wrapped.labels.no_data')
        : weekdays[(weekdayCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key];

    var totalListeningTimeSeconds = 0.0;
    for (final item in listened) {
      final duration = item.effectiveDurationSeconds ?? 0;
      if (duration <= 0) continue;
      final fullCount = effectiveCompletedFor(item);
      totalListeningTimeSeconds += fullCount * duration;
      final partialCount = max(item.playCount - fullCount, 0);
      totalListeningTimeSeconds +=
          partialCount * duration * item.avgListenProgress;
    }
    final estimatedListeningTimeLabel = _formatDuration(
      totalListeningTimeSeconds.round(),
    );

    final hourCounts = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};
    for (final item in listened) {
      if (item.lastPlayedAt != null && item.lastPlayedAt! > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(item.lastPlayedAt!);
        final hour = dt.hour;
        if (hour >= 6 && hour < 12) {
          hourCounts[1] = hourCounts[1]! + 1;
        } else if (hour >= 12 && hour < 18) {
          hourCounts[2] = hourCounts[2]! + 1;
        } else if (hour >= 18 && hour < 24) {
          hourCounts[3] = hourCounts[3]! + 1;
        } else {
          hourCounts[0] = hourCounts[0]! + 1;
        }
      }
    }
    final maxPeriodEntry = hourCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final favoriteTimeOfDay = maxPeriodEntry.first.value == 0
        ? tr('wrapped.labels.no_data')
        : switch (maxPeriodEntry.first.key) {
            0 => tr('wrapped.labels.time_of_day.dawn'),
            1 => tr('wrapped.labels.time_of_day.morning'),
            2 => tr('wrapped.labels.time_of_day.afternoon'),
            3 => tr('wrapped.labels.time_of_day.night'),
            _ => tr('wrapped.labels.no_data'),
          };

    final uniqueArtists = <String>{};
    for (final item in listened) {
      final credits = ArtistCreditParser.parse(item.displaySubtitle);
      final name = ArtistCreditParser.cleanName(credits.primaryArtist);
      if (name.isNotEmpty) {
        uniqueArtists.add(ArtistCreditParser.normalizeKey(name));
      }
    }
    final artistDiversityCount = uniqueArtists.length;

    final videoItemKeys = videoItems.map((e) => e.fileId).toSet();
    if (videoItemKeys.isEmpty) {
      videoItemKeys.addAll(videoItems.map((e) => e.id));
    }
    final linkedVideosCount = allLinkedIds.intersection(videoItemKeys).length;
    final organizedVideoPercentageLabel = videoItems.isEmpty
        ? '0%'
        : '${(linkedVideosCount / videoItems.length * 100).toStringAsFixed(0)}%';

    final totalCollectionsCount = topics.length + playlists.length;
    final averageVideosPerCollectionLabel = totalCollectionsCount == 0
        ? '0'
        : (allLinkedIds.length / totalCollectionsCount).toStringAsFixed(1);

    return ListeningStats(
      totalPlays: totalPlays,
      totalCompleted: totalCompleted,
      averageProgressPercent: (averageProgress * 100).round().clamp(0, 100),
      recentTracks: recentTracks,
      totalImportFiles: importStats.totalFiles,
      importedAudioFiles: importStats.audioFiles,
      importedVideoFiles: importStats.videoFiles,
      importedAudioItems: importStats.audioItems,
      importedVideoItems: importStats.videoItems,
      totalImportSizeLabel: _formatBytes(importStats.totalBytes),
      latestImportLabel: importStats.latestImportAt <= 0
          ? tr('wrapped.labels.no_import_date')
          : tr(
              'wrapped.labels.latest_import',
              args: [_relativeDateLabel(importStats.latestImportAt)],
            ),
      topImportedArtistsLastMonth: importStats.topArtistsLastMonth,
      topImportedArtists: importStats.topArtistsAllTime,
      topImportMonthLabel: importStats.topMonth.count <= 0
          ? tr('wrapped.labels.no_data')
          : importStats.topMonth.label,
      topImportWeekLabel: importStats.topWeek.count <= 0
          ? tr('wrapped.labels.no_data')
          : importStats.topWeek.label,
      topImportPeriodDetail: _topImportPeriodDetail(importStats),
      videoPlays: videoPlays,
      videoRecentItems: videoRecentItems,
      topVideos: videosByPlays.take(5).toList(growable: false),
      topTrack: byPlays.isEmpty ? null : byPlays.first,
      topTracks: byPlays.take(5).toList(growable: false),
      topFavoriteTracks: favoritesByPlays.take(5).toList(growable: false),
      topRegions: topRegions,
      topArtists: _buildTopArtists(listened),
      mostCompleted: completed.take(5).toList(growable: false),
      mostSkipped: skipped.take(5).toList(growable: false),
      monthlyImports: monthlyImports,
      audioLibraryDurationLabel: audioLibraryDurationLabel,
      audioCompletionRateLabel: audioCompletionRateLabel,
      audioImportSizeLabel: audioImportSizeLabel,
      videoLibraryDurationLabel: videoLibraryDurationLabel,
      totalVideoCollections: totalVideoCollections,
      rootVideoCollections: rootVideoCollections,
      videoSubCollections: videoSubCollections,
      collectionLinkedItems: collectionLinkedItems,
      emptyVideoCollections: emptyVideoCollections,
      largestCollectionName: largestCollectionName,
      largestCollectionCount: largestCollectionCount,
      topCollections: topCollections,
      averageFileSizeLabel: averageFileSizeLabel,
      mostCommonFormat: mostCommonFormat,
      mostActiveImportWeekday: mostActiveImportWeekday,
      estimatedListeningTimeLabel: estimatedListeningTimeLabel,
      favoriteTimeOfDay: favoriteTimeOfDay,
      artistDiversityCount: artistDiversityCount,
      organizedVideoPercentageLabel: organizedVideoPercentageLabel,
      averageVideosPerCollectionLabel: averageVideosPerCollectionLabel,
    );
  }

  static List<MonthData> _buildMonthlyImports(Map<String, int> monthCounts) {
    if (monthCounts.isEmpty) return [];

    final sorted = monthCounts.entries.toList()
      ..sort((a, b) {
        final aDate = _parseMonthKey(a.key);
        final bDate = _parseMonthKey(b.key);
        return aDate.compareTo(bDate);
      });

    final recent = sorted.length > 6
        ? sorted.sublist(sorted.length - 6)
        : sorted;

    const monthNames = [
      '',
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];

    return recent.map((e) {
      final parts = e.key.split('/');
      final month = int.tryParse(parts[0]) ?? 0;
      final year = parts.length > 1 ? parts[1] : '';
      final shortLabel = month >= 1 && month <= 12 ? monthNames[month] : e.key;
      return MonthData(
        label: '${monthNames.elementAtOrNull(month) ?? ''} $year',
        shortLabel: shortLabel,
        count: e.value,
      );
    }).toList();
  }

  static DateTime _parseMonthKey(String key) {
    final parts = key.split('/');
    if (parts.length < 2) return DateTime(0);
    final month = int.tryParse(parts[0]) ?? 1;
    final year = int.tryParse(parts[1]) ?? 0;
    return DateTime(year, month);
  }

  static String _topImportPeriodDetail(ImportStats stats) {
    if (stats.topMonth.count <= 0 && stats.topWeek.count <= 0) {
      return tr('wrapped.labels.not_enough_imports');
    }
    if (stats.topMonth.count <= 0) {
      return tr(
        'wrapped.labels.featured_week',
        args: ['${stats.topWeek.count}'],
      );
    }
    if (stats.topWeek.count <= 0) {
      return tr(
        'wrapped.labels.featured_month',
        args: ['${stats.topMonth.count}'],
      );
    }
    return tr(
      'wrapped.labels.featured_month_week',
      args: ['${stats.topMonth.count}', '${stats.topWeek.count}'],
    );
  }

  static List<ArtistStats> _buildTopArtists(List<MediaItem> items) {
    final playsByArtist = <String, int>{};
    final nameByKey = <String, String>{};
    final tracksByArtist = <String, Set<String>>{};

    for (final item in items) {
      final credits = ArtistCreditParser.parse(item.displaySubtitle);
      final name = ArtistCreditParser.cleanName(credits.primaryArtist);
      if (name.isEmpty) continue;
      final key = ArtistCreditParser.normalizeKey(name);
      if (key.isEmpty || key == 'unknown') continue;
      nameByKey[key] = name;
      playsByArtist[key] = (playsByArtist[key] ?? 0) + listenScoreFor(item);
      tracksByArtist.putIfAbsent(key, () => <String>{}).add(item.id);
    }

    final artists = playsByArtist.entries
        .map(
          (entry) => ArtistStats(
            name: nameByKey[entry.key] ?? entry.key,
            plays: entry.value,
            tracks: tracksByArtist[entry.key]?.length ?? 0,
          ),
        )
        .where((artist) => artist.plays > 0)
        .toList();
    artists.sort((a, b) => b.plays.compareTo(a.plays));
    return artists.take(5).toList(growable: false);
  }

  static List<RegionStats> _buildTopRegions(
    List<MediaItem> items, {
    ArtistStore? artistStore,
  }) {
    final affinity = LocalAffinityEngine(artistStore: artistStore);
    final playsByRegion = <String, int>{};
    final tracksByRegion = <String, List<MediaItem>>{};

    for (final item in items) {
      final score = listenScoreFor(item);
      if (score <= 0) continue;
      final countryCode = affinity.resolveCountryCode(item);
      if (countryCode == null) continue;
      final regionCodes = WorldRegionCatalog.regionCodesForCountry(countryCode);
      for (final regionCode in regionCodes) {
        playsByRegion[regionCode] = (playsByRegion[regionCode] ?? 0) + score;
        tracksByRegion.putIfAbsent(regionCode, () => <MediaItem>[]).add(item);
      }
    }

    final regions = playsByRegion.entries
        .map((entry) {
          final definition = WorldRegionCatalog.byCode(entry.key);
          if (definition == null) return null;
          final tracks =
              (tracksByRegion[entry.key] ?? const <MediaItem>[]).toList()
                ..sort((a, b) {
                  final plays = listenScoreFor(b).compareTo(listenScoreFor(a));
                  if (plays != 0) return plays;
                  return (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0);
                });
          return RegionStats(
            code: definition.code,
            name: definition.name,
            plays: entry.value,
            topTracks: tracks.take(3).toList(growable: false),
          );
        })
        .whereType<RegionStats>()
        .toList();
    regions.sort((a, b) => b.plays.compareTo(a.plays));
    return regions.take(5).toList(growable: false);
  }

  static int effectiveCompletedFor(MediaItem item) {
    if (item.playCount <= 0 && item.fullListenCount <= 0) {
      return 0;
    }
    final completedFromPlays = max(item.playCount - item.skipCount, 0);
    return max(item.fullListenCount, completedFromPlays);
  }

  static int listenScoreFor(MediaItem item) {
    if (item.playCount <= 0 && item.fullListenCount <= 0) {
      return 0;
    }
    final skipAdjustedPlays = max(item.playCount - item.skipCount, 0);
    return max(skipAdjustedPlays, 0) + max(item.fullListenCount, 0);
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final decimals = unit == 0 || value >= 10 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
  }

  static String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0s';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  static String _relativeDateLabel(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return tr('wrapped.labels.today');
    if (diff == 1) return tr('wrapped.labels.yesterday');
    if (diff < 30) return tr('wrapped.labels.days_ago', args: ['$diff']);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class ImportStats {
  const ImportStats({
    required this.totalFiles,
    required this.audioFiles,
    required this.videoFiles,
    required this.audioItems,
    required this.videoItems,
    required this.totalBytes,
    required this.latestImportAt,
    required this.topArtistsLastMonth,
    required this.topArtistsAllTime,
    required this.topMonth,
    required this.topWeek,
    required this.monthCounts,
  });

  final int totalFiles;
  final int audioFiles;
  final int videoFiles;
  final int audioItems;
  final int videoItems;
  final int totalBytes;
  final int latestImportAt;
  final List<ImportArtistStats> topArtistsLastMonth;
  final List<ImportArtistStats> topArtistsAllTime;
  final ImportPeak topMonth;
  final ImportPeak topWeek;
  final Map<String, int> monthCounts;

  static ImportStats fromItems(List<MediaItem> items) {
    var totalFiles = 0;
    var audioFiles = 0;
    var videoFiles = 0;
    var audioItems = 0;
    var videoItems = 0;
    var totalBytes = 0;
    var latestImportAt = 0;
    final now = DateTime.now();
    final lastMonthCutoff = now
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    final monthCounts = <String, int>{};
    final weekCounts = <String, int>{};
    final importAllTime = ArtistImportAccumulator();
    final importLastMonth = ArtistImportAccumulator();

    for (final item in items) {
      var hasAudio = false;
      var hasVideo = false;
      var audioImportsForItem = 0;
      var recentAudioImportsForItem = 0;
      for (final variant in item.variants) {
        if ((variant.localPath ?? '').trim().isEmpty) continue;
        totalFiles++;
        totalBytes += max(variant.size ?? 0, 0);
        if (variant.createdAt > latestImportAt) {
          latestImportAt = variant.createdAt;
        }
        if (variant.kind == MediaVariantKind.audio) {
          audioFiles++;
          hasAudio = true;
          audioImportsForItem++;
          if (variant.createdAt >= lastMonthCutoff) {
            recentAudioImportsForItem++;
          }
        } else {
          videoFiles++;
          hasVideo = true;
        }
        if (variant.createdAt > 0) {
          _increment(monthCounts, _monthKey(variant.createdAt));
          _increment(weekCounts, _weekKey(variant.createdAt));
        }
      }
      if (hasAudio) audioItems++;
      if (hasVideo) videoItems++;
      if (audioImportsForItem > 0) {
        importAllTime.add(item, audioImportsForItem);
      }
      if (recentAudioImportsForItem > 0) {
        importLastMonth.add(item, recentAudioImportsForItem);
      }
    }

    return ImportStats(
      totalFiles: totalFiles,
      audioFiles: audioFiles,
      videoFiles: videoFiles,
      audioItems: audioItems,
      videoItems: videoItems,
      totalBytes: totalBytes,
      latestImportAt: latestImportAt,
      topArtistsLastMonth: importLastMonth.top(5),
      topArtistsAllTime: importAllTime.top(5),
      topMonth: _topPeriod(monthCounts),
      topWeek: _topPeriod(weekCounts),
      monthCounts: monthCounts,
    );
  }

  static void _increment(Map<String, int> counts, String key) {
    counts[key] = (counts[key] ?? 0) + 1;
  }

  static String _monthKey(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final month = date.month.toString().padLeft(2, '0');
    return '$month/${date.year}';
  }

  static String _weekKey(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final day = DateTime(date.year, date.month, date.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    String short(DateTime value) =>
        '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
    return '${short(monday)} - ${short(sunday)}';
  }

  static ImportPeak _topPeriod(Map<String, int> counts) {
    if (counts.isEmpty) {
      return const ImportPeak(label: 'Sin datos', count: 0);
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return b.key.compareTo(a.key);
      });
    final top = entries.first;
    return ImportPeak(label: top.key, count: top.value);
  }
}

class ArtistImportAccumulator {
  final Map<String, int> _importsByArtist = {};
  final Map<String, String> _nameByKey = {};
  final Map<String, Set<String>> _tracksByArtist = {};

  void add(MediaItem item, int imports) {
    if (imports <= 0) return;
    final credits = ArtistCreditParser.parse(item.displaySubtitle);
    final name = ArtistCreditParser.cleanName(credits.primaryArtist);
    if (name.isEmpty) return;
    final key = ArtistCreditParser.normalizeKey(name);
    if (key.isEmpty || key == 'unknown') return;
    _nameByKey[key] = name;
    _importsByArtist[key] = (_importsByArtist[key] ?? 0) + imports;
    _tracksByArtist.putIfAbsent(key, () => <String>{}).add(item.id);
  }

  List<ImportArtistStats> top(int limit) {
    final artists = _importsByArtist.entries
        .map(
          (entry) => ImportArtistStats(
            name: _nameByKey[entry.key] ?? entry.key,
            imports: entry.value,
            tracks: _tracksByArtist[entry.key]?.length ?? 0,
          ),
        )
        .where((artist) => artist.imports > 0)
        .toList();
    artists.sort((a, b) {
      final byImports = b.imports.compareTo(a.imports);
      if (byImports != 0) return byImports;
      return b.tracks.compareTo(a.tracks);
    });
    return artists.take(limit).toList(growable: false);
  }
}
