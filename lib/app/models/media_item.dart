import 'package:collection/collection.dart';
import 'package:flutter_listenfy/Modules/sources/domain/source_origin.dart';
import 'package:flutter_listenfy/Modules/sources/domain/detect_source_origin.dart';

enum MediaSource { local, youtube }

enum MediaVariantKind { audio, video }

class TimedLyricCue {
  final String text;
  final int startMs;
  final int? endMs;

  const TimedLyricCue({required this.text, required this.startMs, this.endMs});

  factory TimedLyricCue.fromJson(Map<String, dynamic> json) {
    final text = (json['text'] as String? ?? '').trim();
    final startMs = _parseMilliseconds(json['startMs']);
    final endMs = _parseNullableMilliseconds(json['endMs']);
    return TimedLyricCue(text: text, startMs: startMs, endMs: endMs);
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'startMs': startMs,
    'endMs': endMs,
  };
}

// ============================================================================
// MediaItem
// ============================================================================

class MediaItem {
  // ============================
  // 🧾 CAMPOS
  // ============================
  final String id; // interno (hash/local)
  final String publicId; // id “estable” para backend/variantes
  final String title;
  final String subtitle;
  final String? country;
  final MediaSource source;

  /// Thumbnail remoto (URL)
  final String? thumbnail;

  /// Thumbnail local (ruta en disco) para offline (Opción B)
  final String? thumbnailLocalPath;

  final List<MediaVariant> variants;
  final SourceOrigin origin;

  /// Favorito en UI
  final bool isFavorite;

  /// Conteo de reproducciones
  final int playCount;

  /// Timestamp (ms) última reproducción
  final int? lastPlayedAt;

  /// Conteo de saltos de pista (skip manual o cambio temprano)
  final int skipCount;

  /// Conteo de reproducciones completadas
  final int fullListenCount;

  /// Progreso promedio de escucha [0..1]
  final double avgListenProgress;

  /// Timestamp (ms) de última reproducción completada
  final int? lastCompletedAt;

  /// Duración base del media (si viene del backend/metadata)
  final int? durationSeconds;
  final String? lyrics;
  final String? lyricsLanguage;
  final Map<String, String>? translations;
  final Map<String, List<TimedLyricCue>>? timedLyrics;

  const MediaItem({
    required this.id,
    required this.publicId,
    required this.title,
    required this.subtitle,
    this.country,
    required this.source,
    required this.variants,
    required this.origin,
    this.thumbnail,
    this.thumbnailLocalPath,
    this.durationSeconds,
    this.lyrics,
    this.lyricsLanguage,
    this.translations,
    this.timedLyrics,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPlayedAt,
    this.skipCount = 0,
    this.fullListenCount = 0,
    this.avgListenProgress = 0,
    this.lastCompletedAt,
  });

  // ============================
  // 🧬 COPY WITH
  // ============================
  MediaItem copyWith({
    String? id,
    String? publicId,
    String? title,
    String? subtitle,
    String? country,
    MediaSource? source,
    String? thumbnail,
    String? thumbnailLocalPath,
    List<MediaVariant>? variants,
    SourceOrigin? origin,
    int? durationSeconds,
    String? lyrics,
    String? lyricsLanguage,
    Map<String, String>? translations,
    Map<String, List<TimedLyricCue>>? timedLyrics,
    bool? isFavorite,
    int? playCount,
    int? lastPlayedAt,
    int? skipCount,
    int? fullListenCount,
    double? avgListenProgress,
    int? lastCompletedAt,
  }) {
    return MediaItem(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      country: country ?? this.country,
      source: source ?? this.source,
      thumbnail: thumbnail ?? this.thumbnail,
      thumbnailLocalPath: thumbnailLocalPath ?? this.thumbnailLocalPath,
      variants: variants ?? this.variants,
      origin: origin ?? this.origin,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lyrics: lyrics ?? this.lyrics,
      lyricsLanguage: lyricsLanguage ?? this.lyricsLanguage,
      translations: translations ?? this.translations,
      timedLyrics: timedLyrics ?? this.timedLyrics,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      skipCount: skipCount ?? this.skipCount,
      fullListenCount: fullListenCount ?? this.fullListenCount,
      avgListenProgress: avgListenProgress ?? this.avgListenProgress,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
    );
  }

  // ============================
  // ✅ GETTERS / ESTADO
  // ============================
  /// ID preferido para endpoints / archivos
  String get fileId => publicId.trim().isNotEmpty ? publicId.trim() : id.trim();

  bool _hasLocal(MediaVariant v) => (v.localPath?.trim().isNotEmpty ?? false);

  bool get hasAudioLocal =>
      variants.any((v) => v.kind == MediaVariantKind.audio && _hasLocal(v));

  bool get hasVideoLocal =>
      variants.any((v) => v.kind == MediaVariantKind.video && _hasLocal(v));

  MediaVariant? get localAudioVariant {
    final normal = variants.firstWhereOrNull(
      (v) =>
          v.kind == MediaVariantKind.audio && !v.isInstrumental && _hasLocal(v),
    );
    if (normal != null) return normal;
    return variants.firstWhereOrNull(
      (v) => v.kind == MediaVariantKind.audio && _hasLocal(v),
    );
  }

  MediaVariant? get localInstrumentalVariant => variants.firstWhereOrNull(
    (v) => v.kind == MediaVariantKind.audio && v.isInstrumental && _hasLocal(v),
  );

  MediaVariant? get localVideoVariant => variants.firstWhereOrNull(
    (v) => v.kind == MediaVariantKind.video && _hasLocal(v),
  );

  /// Duración preferida (mejor: audio -> video -> item)
  int? get effectiveDurationSeconds =>
      localAudioVariant?.durationSeconds ??
      localVideoVariant?.durationSeconds ??
      durationSeconds;

  /// Indica si alguna variante está almacenada offline
  bool get isOfflineStored => variants.any(_hasLocal);

  /// Thumbnail preferido: local -> remoto
  String? get effectiveThumbnail {
    final lp = thumbnailLocalPath?.trim();
    if (lp != null && lp.isNotEmpty) return lp;

    final t = thumbnail?.trim();
    if (t != null && t.isNotEmpty) return t;

    return null;
  }

  /// Subtitle legible en UI: usa subtitle; si no existe, vacío
  String get displaySubtitle {
    final s = subtitle.trim();
    if (s.isNotEmpty) return s;
    return '';
  }

  // ============================
  // ✅ FIX CLAVE: URL / PATH reproducible
  // ============================

  /// Mejor path local disponible (audio primero, luego video)
  String? get bestLocalPath =>
      localAudioVariant?.localPath?.trim().isNotEmpty == true
      ? localAudioVariant!.localPath!.trim()
      : (localVideoVariant?.localPath?.trim().isNotEmpty == true
            ? localVideoVariant!.localPath!.trim()
            : null);

  /// Si es local: devuelve **file:///...**
  /// Si no es local: intenta usar un URL remoto si existe en la data.
  ///
  /// Importante: esto evita que el player use `fileName` como si fuese link.
  String get playableUrl {
    final lp = bestLocalPath;
    if (lp != null && lp.isNotEmpty) {
      return Uri.file(lp).toString(); // ✅ aquí se arregla el "link"
    }

    // Fallback remoto (si en algún flujo `fileName` ya viene como URL)
    final anyUrl = variants
        .map((v) => v.fileName.trim())
        .firstWhereOrNull(
          (s) => s.startsWith('http://') || s.startsWith('https://'),
        );

    return anyUrl ?? '';
  }

  // ============================
  // 🧩 HELPERS
  // ============================
  static int? _parseDurationToSeconds(dynamic raw) {
    if (raw == null) return null;

    if (raw is num) {
      var v = raw.toInt();
      if (v > 100000) v = (v / 1000).round(); // ms -> s
      return v >= 0 ? v : null;
    }

    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;

      if (s.contains(':')) {
        final parts = s.split(':').map((p) => int.tryParse(p.trim())).toList();
        if (parts.any((e) => e == null)) return null;

        if (parts.length == 3) {
          return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
        }
        if (parts.length == 2) {
          return parts[0]! * 60 + parts[1]!;
        }
      }

      var v = int.tryParse(s);
      if (v == null) return null;
      if (v > 100000) v = (v / 1000).round();
      return v >= 0 ? v : null;
    }

    return null;
  }

  // ============================
  // 🔁 JSON
  // ============================
  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final variantsJson = (json['variants'] as List?) ?? const [];
    final variants = variantsJson
        .whereType<Map>()
        .map((m) => MediaVariant.fromJson(Map<String, dynamic>.from(m)))
        .where((v) => v.isValid)
        .toList();

    final id = (json['id'] as String?)?.trim() ?? '';
    final publicId = (json['publicId'] as String?)?.trim() ?? '';

    final titleRaw = (json['title'] as String?)?.trim();
    final title = (titleRaw != null && titleRaw.isNotEmpty)
        ? titleRaw
        : 'Unknown title';

    final subtitle =
        (json['artist'] as String?)?.trim() ??
        (json['subtitle'] as String?)?.trim() ??
        '';
    final country =
        (json['country'] as String?)?.trim() ??
        (json['pais'] as String?)?.trim();

    final sourceStr = (json['source'] as String?)?.toLowerCase().trim();
    final source = sourceStr == 'local'
        ? MediaSource.local
        : MediaSource.youtube;

    final durationSeconds = _parseDurationToSeconds(
      json['duration'] ??
          json['durationSeconds'] ??
          json['length'] ??
          json['lengthSeconds'],
    );

    final origin = _parseOrigin(json);
    final isFavorite = (json['isFavorite'] as bool?) ?? false;
    final playCount = (json['playCount'] as num?)?.toInt() ?? 0;
    final lastPlayedAt = (json['lastPlayedAt'] as num?)?.toInt();
    final skipCount = (json['skipCount'] as num?)?.toInt() ?? 0;
    final fullListenCount = (json['fullListenCount'] as num?)?.toInt() ?? 0;
    final avgListenProgress = _parseProgress(
      json['avgListenProgress'],
      fallback: (json['averageListenProgress'] is num)
          ? (json['averageListenProgress'] as num).toDouble()
          : null,
    );
    final lastCompletedAt = (json['lastCompletedAt'] as num?)?.toInt();

    final lyrics = json['lyrics'] as String?;
    final lyricsLanguage = json['lyricsLanguage'] as String?;
    final translationsJson = json['translations'] as Map<String, dynamic>?;
    final translations = translationsJson?.map(
      (k, v) => MapEntry(k, v as String),
    );
    final timedLyrics = _parseTimedLyricsMap(json['timedLyrics']);

    return MediaItem(
      id: id,
      publicId: publicId,
      title: title,
      subtitle: subtitle,
      country: country,
      source: source,
      thumbnail: (json['thumbnail'] as String?)?.trim(),
      thumbnailLocalPath: (json['thumbnailLocalPath'] as String?)?.trim(),
      variants: variants,
      durationSeconds: durationSeconds,
      origin: origin,
      lyrics: lyrics,
      lyricsLanguage: lyricsLanguage,
      translations: translations,
      timedLyrics: timedLyrics,
      isFavorite: isFavorite,
      playCount: playCount,
      lastPlayedAt: lastPlayedAt,
      skipCount: skipCount < 0 ? 0 : skipCount,
      fullListenCount: fullListenCount < 0 ? 0 : fullListenCount,
      avgListenProgress: avgListenProgress,
      lastCompletedAt: lastCompletedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'publicId': publicId,
    'title': title,
    'artist': subtitle,
    'country': country,
    'source': source == MediaSource.local ? 'local' : 'youtube',
    'origin': origin.key,
    'thumbnail': thumbnail,
    'thumbnailLocalPath': thumbnailLocalPath,
    'duration': durationSeconds,
    'isFavorite': isFavorite,
    'playCount': playCount,
    'lastPlayedAt': lastPlayedAt,
    'skipCount': skipCount,
    'fullListenCount': fullListenCount,
    'avgListenProgress': avgListenProgress,
    'lastCompletedAt': lastCompletedAt,
    'lyrics': lyrics,
    'lyricsLanguage': lyricsLanguage,
    'translations': translations,
    'timedLyrics': _timedLyricsToJson(timedLyrics),
    'variants': variants.map((v) => v.toJson()).toList(),
  };
}

double _parseProgress(dynamic raw, {double? fallback}) {
  double? value;
  if (raw is num) {
    value = raw.toDouble();
  } else if (raw is String) {
    value = double.tryParse(raw.trim());
  } else {
    value = fallback;
  }

  if (value == null || value.isNaN || value.isInfinite) return 0;
  if (value > 1 && value <= 100) value = value / 100;
  return value.clamp(0, 1).toDouble();
}

int _parseMilliseconds(dynamic raw) {
  if (raw is num) return raw.toInt().clamp(0, 1 << 31).toInt();
  if (raw is String) {
    final value = int.tryParse(raw.trim());
    if (value != null) return value.clamp(0, 1 << 31).toInt();
  }
  return 0;
}

int? _parseNullableMilliseconds(dynamic raw) {
  if (raw == null) return null;
  return _parseMilliseconds(raw);
}

Map<String, List<TimedLyricCue>>? _parseTimedLyricsMap(dynamic raw) {
  if (raw is! Map) return null;
  final out = <String, List<TimedLyricCue>>{};
  for (final entry in raw.entries) {
    final lang = entry.key.toString().trim().toLowerCase();
    if (lang.isEmpty) continue;
    final cuesRaw = entry.value;
    if (cuesRaw is! List) continue;

    final cues = <TimedLyricCue>[];
    for (final cueRaw in cuesRaw) {
      if (cueRaw is! Map) continue;
      final cue = TimedLyricCue.fromJson(Map<String, dynamic>.from(cueRaw));
      if (cue.text.trim().isEmpty) continue;
      if (cue.startMs < 0) continue;
      cues.add(cue);
    }

    if (cues.isEmpty) continue;
    cues.sort((a, b) => a.startMs.compareTo(b.startMs));
    out[lang] = cues;
  }
  return out.isEmpty ? null : out;
}

Map<String, dynamic>? _timedLyricsToJson(
  Map<String, List<TimedLyricCue>>? timedLyrics,
) {
  if (timedLyrics == null || timedLyrics.isEmpty) return null;
  final out = <String, dynamic>{};
  for (final entry in timedLyrics.entries) {
    final lang = entry.key.trim().toLowerCase();
    if (lang.isEmpty) continue;
    final cues = entry.value;
    if (cues.isEmpty) continue;
    out[lang] = cues.map((cue) => cue.toJson()).toList(growable: false);
  }
  return out.isEmpty ? null : out;
}

SourceOrigin _parseOrigin(Map<String, dynamic> json) {
  final originRaw = json['origin'] as String?;
  var origin = SourceOriginX.fromKey(originRaw);
  if (origin != SourceOrigin.generic) return origin;

  final sourceRaw = (json['source'] as String?)?.toLowerCase().trim();
  if (sourceRaw != null && sourceRaw.isNotEmpty) {
    origin = SourceOriginX.fromKey(sourceRaw);
    if (origin != SourceOrigin.generic) return origin;
  }

  final candidates = [
    json['url'],
    json['webpageUrl'],
    json['webpage_url'],
    json['sourceUrl'],
    json['source_url'],
    json['originalUrl'],
    json['original_url'],
    json['thumbnail'],
  ];

  for (final c in candidates) {
    if (c is! String) continue;
    final s = c.trim();
    if (s.isEmpty) continue;
    origin = detectSourceOriginFromUrl(s);
    if (origin != SourceOrigin.generic) return origin;
  }

  return SourceOrigin.generic;
}

// ============================================================================
// MediaVariant
// ============================================================================

class MediaVariant {
  // ============================
  // 🧾 CAMPOS
  // ============================
  final MediaVariantKind kind;
  final String format;

  /// Nombre del archivo (ej: song.mp3) o en algunos flujos un URL remoto
  final String fileName;

  /// Ruta REAL del archivo en el dispositivo (picker o storage interno)
  final String? localPath;

  final int createdAt;
  final int? size;
  final int? durationSeconds;
  final String? role;

  const MediaVariant({
    required this.kind,
    required this.format,
    required this.fileName,
    required this.createdAt,
    this.localPath,
    this.size,
    this.durationSeconds,
    this.role,
  });

  // ============================
  // 🔁 JSON
  // ============================
  factory MediaVariant.fromJson(Map<String, dynamic> json) {
    final fileName =
        (json['fileName'] as String?)?.trim() ??
        (json['path'] as String?)?.split('/').last.trim() ??
        '';

    final localPath = (json['localPath'] as String?)?.trim();

    final kindStr = (json['kind'] as String?)?.toLowerCase().trim();
    final kind = kindStr == 'video'
        ? MediaVariantKind.video
        : MediaVariantKind.audio;

    final format = (json['format'] as String?)?.trim() ?? '';
    final createdAt = (json['createdAt'] as num?)?.toInt() ?? 0;
    final size = (json['size'] as num?)?.toInt();
    final role = _normalizeRole(
      (json['role'] as String?) ?? (json['variantRole'] as String?),
    );

    final rawDur =
        json['durationSeconds'] ??
        json['duration'] ??
        json['lengthSeconds'] ??
        json['length'] ??
        json['durationMs'];

    final durationSeconds = MediaItem._parseDurationToSeconds(rawDur);

    return MediaVariant(
      kind: kind,
      format: format,
      fileName: fileName,
      localPath: localPath,
      createdAt: createdAt,
      size: size,
      durationSeconds: durationSeconds,
      role: role,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind == MediaVariantKind.video ? 'video' : 'audio',
    'format': format,
    'fileName': fileName,
    'localPath': localPath,
    'createdAt': createdAt,
    'size': size,
    'durationSeconds': durationSeconds,
    'role': role,
  };

  // ============================
  // ✅ VALIDACIÓN / HELPERS
  // ============================
  bool get isValid => fileName.isNotEmpty && format.isNotEmpty;

  String get roleKey {
    final normalized = _normalizeRole(role);
    if (normalized != null) return normalized;

    final lowerFile = fileName.toLowerCase();
    final lowerPath = (localPath ?? '').toLowerCase();
    final looksInstrumental =
        lowerFile.contains('_inst') ||
        lowerFile.contains('instrumental') ||
        lowerPath.contains('_inst') ||
        lowerPath.contains('/instrumental');
    return looksInstrumental ? 'instrumental' : 'main';
  }

  bool get isInstrumental =>
      kind == MediaVariantKind.audio && roleKey == 'instrumental';

  bool sameSlotAs(MediaVariant other) {
    return kind == other.kind &&
        format.toLowerCase().trim() == other.format.toLowerCase().trim() &&
        roleKey == other.roleKey;
  }

  bool sameIdentityAs(MediaVariant other) {
    if (!sameSlotAs(other)) return false;

    final aLocal = localPath?.trim() ?? '';
    final bLocal = other.localPath?.trim() ?? '';
    if (aLocal.isNotEmpty && bLocal.isNotEmpty) return aLocal == bLocal;

    final aFile = fileName.trim().toLowerCase();
    final bFile = other.fileName.trim().toLowerCase();
    if (aFile.isNotEmpty && bFile.isNotEmpty) return aFile == bFile;

    return true;
  }

  /// Path local “limpio”
  String? get playablePath {
    final lp = localPath?.trim();
    return (lp != null && lp.isNotEmpty) ? lp : null;
  }

  /// URL reproducible:
  /// - si localPath existe => file:///...
  /// - si no => si fileName ya es URL remoto => lo devuelve
  String get playableUrl {
    final lp = playablePath;
    if (lp != null) return Uri.file(lp).toString();

    final f = fileName.trim();
    if (f.startsWith('http://') || f.startsWith('https://')) return f;

    return '';
  }

  static String? _normalizeRole(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return null;
    if (value == 'instrumental' || value == 'inst') return 'instrumental';
    if (value == 'main' || value == 'normal' || value == 'original') {
      return 'main';
    }
    return value;
  }
}
