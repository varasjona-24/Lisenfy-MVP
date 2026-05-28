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
    HomeWidgetId.favorites => 'Mis favoritos',
    HomeWidgetId.recommendations => 'Para ti hoy',
    HomeWidgetId.continueWatching => 'Seguir viendo',
    HomeWidgetId.mostPlayed => 'Más reproducido',
    HomeWidgetId.recentlyPlayed => 'Reproducciones recientes',
    HomeWidgetId.featured => 'Destacado',
    HomeWidgetId.latestDownloads => 'Últimos imports',
    HomeWidgetId.notPlayed => 'Por escuchar',
    HomeWidgetId.randomMix => 'Mix aleatorio',
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

  bool get videoHomeSupported =>
      this == HomeWidgetId.continueWatching ||
      this == HomeWidgetId.latestDownloads ||
      this == HomeWidgetId.featured ||
      this == HomeWidgetId.mostPlayed ||
      this == HomeWidgetId.recentlyPlayed;

  bool get hasFixedLayout =>
      this == HomeWidgetId.recommendations || this == HomeWidgetId.mostPlayed;

  static HomeWidgetId? fromKey(String key) {
    for (final value in HomeWidgetId.values) {
      if (value.key == key) return value;
    }
    return null;
  }
}

enum HomeMediaSort { title, artist, importedAt, size, plays, duration, recent }

extension HomeMediaSortX on HomeMediaSort {
  String get key => name;

  String get label => switch (this) {
    HomeMediaSort.title => 'Nombre de canción',
    HomeMediaSort.artist => 'Nombre del artista',
    HomeMediaSort.importedAt => 'Tiempo añadido',
    HomeMediaSort.size => 'Tamaño',
    HomeMediaSort.plays => 'Reproducciones',
    HomeMediaSort.duration => 'Duración',
    HomeMediaSort.recent => 'Última reproducción',
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
    HomeCustomSectionLayout.cards => 'Cards',
    HomeCustomSectionLayout.list => 'Lista',
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
    HomeCustomSectionKind.playlist => 'Playlist',
    HomeCustomSectionKind.artist => 'Artista',
    HomeCustomSectionKind.smart => 'Sugerida',
    HomeCustomSectionKind.collection => 'Collection',
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
  });

  final String id;
  final HomeCustomSectionKind kind;
  final String targetId;
  final String title;
  final HomeCustomSectionLayout layout;

  factory HomeCustomSection.fromJson(Map<String, dynamic> json) {
    return HomeCustomSection(
      id: (json['id'] ?? '').toString(),
      kind: HomeCustomSectionKindX.fromRaw(json['kind']),
      targetId: (json['targetId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      layout: HomeCustomSectionLayoutX.fromRaw(json['layout']),
    );
  }

  HomeCustomSection copyWith({
    String? targetId,
    HomeCustomSectionLayout? layout,
  }) {
    return HomeCustomSection(
      id: id,
      kind: kind,
      targetId: targetId ?? this.targetId,
      title: title,
      layout: layout ?? this.layout,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.key,
    'targetId': targetId,
    'title': title,
    'layout': layout.key,
  };
}

class HomeArtistChoice {
  const HomeArtistChoice({
    required this.key,
    required this.name,
    required this.count,
    this.thumbnail,
  });

  final String key;
  final String name;
  final int count;
  final String? thumbnail;
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
