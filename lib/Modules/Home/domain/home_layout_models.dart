import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

enum HomeMode { audio, video }

enum HomeWidgetId {
  favorites,
  recommendations,
  continueWatching,
  mostPlayed,
  recentlyPlayed,
  featured,
  latestDownloads,
  notPlayed,
  randomMix,
}

extension HomeWidgetIdX on HomeWidgetId {
  String get key => switch (this) {
    HomeWidgetId.favorites => 'favorites',
    HomeWidgetId.recommendations => 'recommendations',
    HomeWidgetId.continueWatching => 'continueWatching',
    HomeWidgetId.mostPlayed => 'mostPlayed',
    HomeWidgetId.recentlyPlayed => 'recentlyPlayed',
    HomeWidgetId.featured => 'featured',
    HomeWidgetId.latestDownloads => 'latestDownloads',
    HomeWidgetId.notPlayed => 'notPlayed',
    HomeWidgetId.randomMix => 'randomMix',
  };

  String get label => switch (this) {
    HomeWidgetId.favorites => tr('home.widgets.favorites'),
    HomeWidgetId.recommendations => tr('home.widgets.recommendations'),
    HomeWidgetId.continueWatching => tr('home.widgets.continueWatching'),
    HomeWidgetId.mostPlayed => tr('home.widgets.mostPlayed'),
    HomeWidgetId.recentlyPlayed => tr('home.widgets.recentlyPlayed'),
    HomeWidgetId.featured => tr('home.widgets.featured'),
    HomeWidgetId.latestDownloads => tr('home.widgets.latestDownloads'),
    HomeWidgetId.notPlayed => tr('home.widgets.notPlayed'),
    HomeWidgetId.randomMix => tr('home.widgets.randomMix'),
  };

  IconData get icon => switch (this) {
    HomeWidgetId.favorites => Icons.favorite_rounded,
    HomeWidgetId.recommendations => Icons.auto_awesome_rounded,
    HomeWidgetId.continueWatching => Icons.play_circle_fill_rounded,
    HomeWidgetId.mostPlayed => Icons.trending_up_rounded,
    HomeWidgetId.recentlyPlayed => Icons.history_rounded,
    HomeWidgetId.featured => Icons.star_rounded,
    HomeWidgetId.latestDownloads => Icons.download_done_rounded,
    HomeWidgetId.notPlayed => Icons.fiber_new_rounded,
    HomeWidgetId.randomMix => Icons.shuffle_rounded,
  };

  bool get audioOnly => this == HomeWidgetId.recommendations;
  bool get videoOnly => this == HomeWidgetId.continueWatching;
  bool get canDisable => this != HomeWidgetId.continueWatching;

  bool get videoHomeSupported =>
      this == HomeWidgetId.favorites ||
      this == HomeWidgetId.continueWatching ||
      this == HomeWidgetId.latestDownloads ||
      this == HomeWidgetId.featured ||
      this == HomeWidgetId.mostPlayed ||
      this == HomeWidgetId.recentlyPlayed;

  bool get hasFixedLayout =>
      this == HomeWidgetId.recommendations ||
      this == HomeWidgetId.mostPlayed ||
      this == HomeWidgetId.continueWatching;

  static HomeWidgetId? fromKey(String key) {
    for (final value in HomeWidgetId.values) {
      if (value.key == key) return value;
    }
    return null;
  }
}

/// Preserve customized order; insert a missing mandatory session widget after
/// favorites, including layouts restored from older backups.
List<HomeWidgetId> normalizeVideoHomeOrder(Iterable<HomeWidgetId> order) {
  final result = order.where((id) => id.videoHomeSupported).toSet().toList();
  if (!result.contains(HomeWidgetId.continueWatching)) {
    final favorites = result.indexOf(HomeWidgetId.favorites);
    result.insert(
      favorites < 0 ? 0 : favorites + 1,
      HomeWidgetId.continueWatching,
    );
  }
  return result;
}

enum HomeMediaSort { title, artist, importedAt, size, plays, duration, recent }

extension HomeMediaSortX on HomeMediaSort {
  String get key => name;

  String get label => switch (this) {
    HomeMediaSort.title => tr('home.sort.title'),
    HomeMediaSort.artist => tr('home.sort.artist'),
    HomeMediaSort.importedAt => tr('home.sort.importedAt'),
    HomeMediaSort.size => tr('home.sort.size'),
    HomeMediaSort.plays => tr('home.sort.plays'),
    HomeMediaSort.duration => tr('home.sort.duration'),
    HomeMediaSort.recent => tr('home.sort.recent'),
  };

  IconData get icon => switch (this) {
    HomeMediaSort.title => Icons.sort_by_alpha_rounded,
    HomeMediaSort.artist => Icons.person_rounded,
    HomeMediaSort.importedAt => Icons.download_done_rounded,
    HomeMediaSort.size => Icons.sd_storage_rounded,
    HomeMediaSort.plays => Icons.play_circle_rounded,
    HomeMediaSort.duration => Icons.timer_rounded,
    HomeMediaSort.recent => Icons.history_rounded,
  };

  static HomeMediaSort? fromKey(String key) {
    for (final value in HomeMediaSort.values) {
      if (value.key == key) return value;
    }
    return null;
  }
}

enum HomeCustomSectionKind { playlist, artist, smart, collection }

enum HomeCustomSectionLayout { cards, list }

extension HomeCustomSectionLayoutX on HomeCustomSectionLayout {
  String get key => switch (this) {
    HomeCustomSectionLayout.cards => 'cards',
    HomeCustomSectionLayout.list => 'list',
  };

  String get label => switch (this) {
    HomeCustomSectionLayout.cards => tr('home.layout.cards'),
    HomeCustomSectionLayout.list => tr('home.layout.list'),
  };

  IconData get icon => switch (this) {
    HomeCustomSectionLayout.cards => Icons.view_carousel_rounded,
    HomeCustomSectionLayout.list => Icons.view_list_rounded,
  };

  static HomeCustomSectionLayout fromRaw(dynamic raw) {
    return raw?.toString() == 'list'
        ? HomeCustomSectionLayout.list
        : HomeCustomSectionLayout.cards;
  }
}

extension HomeCustomSectionKindX on HomeCustomSectionKind {
  String get key => switch (this) {
    HomeCustomSectionKind.playlist => 'playlist',
    HomeCustomSectionKind.artist => 'artist',
    HomeCustomSectionKind.smart => 'smart',
    HomeCustomSectionKind.collection => 'collection',
  };

  IconData get icon => switch (this) {
    HomeCustomSectionKind.playlist => Icons.queue_music_rounded,
    HomeCustomSectionKind.artist => Icons.person_rounded,
    HomeCustomSectionKind.smart => Icons.auto_awesome_rounded,
    HomeCustomSectionKind.collection => Icons.video_library_rounded,
  };

  String get moduleLabel => switch (this) {
    HomeCustomSectionKind.playlist => tr('home.custom.playlist'),
    HomeCustomSectionKind.artist => tr('home.custom.artist'),
    HomeCustomSectionKind.smart => tr('home.custom.smart'),
    HomeCustomSectionKind.collection => tr('home.custom.collection'),
  };

  static HomeCustomSectionKind fromRaw(dynamic raw) {
    return switch (raw?.toString()) {
      'artist' => HomeCustomSectionKind.artist,
      'smart' => HomeCustomSectionKind.smart,
      'collection' => HomeCustomSectionKind.collection,
      _ => HomeCustomSectionKind.playlist,
    };
  }
}

class HomeCustomSection {
  const HomeCustomSection({
    required this.id,
    required this.kind,
    required this.targetId,
    required this.title,
    this.layout = HomeCustomSectionLayout.cards,
    this.enabled = true,
    this.beforeWidget,
  });

  final String id;
  final HomeCustomSectionKind kind;
  final String targetId;
  final String title;
  final HomeCustomSectionLayout layout;
  final bool enabled;
  final String? beforeWidget;

  HomeCustomSection withoutTargets(Iterable<String> removed) {
    final excluded = removed.toSet();
    return copyWith(
      targetId: targetId
          .split('|')
          .where((id) => id.isNotEmpty && !excluded.contains(id))
          .join('|'),
    );
  }

  factory HomeCustomSection.fromJson(Map<String, dynamic> json) {
    return HomeCustomSection(
      id: (json['id'] ?? '').toString(),
      kind: HomeCustomSectionKindX.fromRaw(json['kind']),
      targetId: (json['targetId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      layout: HomeCustomSectionLayoutX.fromRaw(json['layout']),
      enabled: json['enabled'] != false,
      beforeWidget: json['beforeWidget'] as String?,
    );
  }

  HomeCustomSection copyWith({
    String? targetId,
    HomeCustomSectionLayout? layout,
    bool? enabled,
    String? beforeWidget,
  }) {
    return HomeCustomSection(
      id: id,
      kind: kind,
      targetId: targetId ?? this.targetId,
      title: title,
      layout: layout ?? this.layout,
      enabled: enabled ?? this.enabled,
      beforeWidget: beforeWidget ?? this.beforeWidget,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.key,
    'targetId': targetId,
    'title': title,
    'layout': layout.key,
    'enabled': enabled,
    'beforeWidget': beforeWidget,
  };
}

List<Object> homeEditorEntries(
  List<HomeWidgetId> order,
  List<HomeCustomSection> custom,
) {
  final entries = <Object>[];
  for (final id in order) {
    entries.addAll(custom.where((section) => section.beforeWidget == id.key));
    entries.add(id);
  }
  entries.addAll(
    custom.where(
      (section) => !order.any((id) => id.key == section.beforeWidget),
    ),
  );
  return entries;
}

List<HomeCustomSection> homeCustomSectionsInEditorOrder(List<Object> entries) {
  final result = <HomeCustomSection>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    if (entry is! HomeCustomSection) continue;
    String nextKey = '';
    for (final next in entries.skip(i + 1)) {
      if (next is HomeWidgetId) {
        nextKey = next.key;
        break;
      }
    }
    result.add(entry.copyWith(beforeWidget: nextKey));
  }
  return result;
}

class HomeArtistChoice {
  const HomeArtistChoice({
    required this.key,
    required this.name,
    required this.count,
    this.thumbnail,
    this.kindKey,
    this.country,
    this.countryCode,
  });

  final String key;
  final String name;
  final int count;
  final String? thumbnail;
  final String? kindKey;
  final String? country;
  final String? countryCode;
}

class HomePlaylistChoice {
  const HomePlaylistChoice({
    required this.id,
    required this.name,
    required this.count,
    this.cover,
  });

  final String id;
  final String name;
  final int count;
  final String? cover;
}

class HomeCollectionChoice {
  const HomeCollectionChoice({
    required this.id,
    required this.themeId,
    required this.name,
    required this.count,
    this.cover,
  });

  final String id;
  final String themeId;
  final String name;
  final int count;
  final String? cover;
}
