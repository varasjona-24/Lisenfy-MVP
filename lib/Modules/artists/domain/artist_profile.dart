import '../../../app/utils/artist_credit_parser.dart';

enum ArtistProfileKind { singer, band }

extension ArtistProfileKindX on ArtistProfileKind {
  String get key => switch (this) {
    ArtistProfileKind.singer => 'singer',
    ArtistProfileKind.band => 'band',
  };

  String get label => switch (this) {
    ArtistProfileKind.singer => 'Musico',
    ArtistProfileKind.band => 'Grupo musical',
  };

  String get sectionLabel => switch (this) {
    ArtistProfileKind.singer => 'Solistas, DJ o Músicos',
    ArtistProfileKind.band => 'Duetos, bandas o grupos musicales',
  };

  static ArtistProfileKind fromRaw(dynamic raw) {
    final key = (raw ?? '').toString().trim().toLowerCase();
    if (key == 'band') return ArtistProfileKind.band;
    return ArtistProfileKind.singer;
  }
}

enum ArtistMainRegion {
  none,
  latino,
  asiatico,
  anglo,
  europeo,
  africano,
  medioOriente,
  oceania,
  global,
}

extension ArtistMainRegionX on ArtistMainRegion {
  String get key => switch (this) {
    ArtistMainRegion.none => 'none',
    ArtistMainRegion.latino => 'latino',
    ArtistMainRegion.asiatico => 'asiatico',
    ArtistMainRegion.anglo => 'anglo',
    ArtistMainRegion.europeo => 'europeo',
    ArtistMainRegion.africano => 'africano',
    ArtistMainRegion.medioOriente => 'medio_oriente',
    ArtistMainRegion.oceania => 'oceania',
    ArtistMainRegion.global => 'global',
  };

  String get label => switch (this) {
    ArtistMainRegion.none => 'Sin region',
    ArtistMainRegion.latino => 'Mix latino',
    ArtistMainRegion.asiatico => 'Mix asiatico',
    ArtistMainRegion.anglo => 'Mix anglo',
    ArtistMainRegion.europeo => 'Mix euro',
    ArtistMainRegion.africano => 'Mix africano',
    ArtistMainRegion.medioOriente => 'Mix medio oriente',
    ArtistMainRegion.oceania => 'Mix oceania',
    ArtistMainRegion.global => 'Mix global',
  };

  String get simpleLabel => switch (this) {
    ArtistMainRegion.none => 'Sin region',
    ArtistMainRegion.latino => 'Latino',
    ArtistMainRegion.asiatico => 'Asiatico',
    ArtistMainRegion.anglo => 'Anglo',
    ArtistMainRegion.europeo => 'Europeo',
    ArtistMainRegion.africano => 'Africano',
    ArtistMainRegion.medioOriente => 'Medio oriente',
    ArtistMainRegion.oceania => 'Oceania',
    ArtistMainRegion.global => 'Global',
  };

  static ArtistMainRegion fromRaw(dynamic raw) {
    final key = (raw ?? '').toString().trim().toLowerCase();
    switch (key) {
      case 'latino':
        return ArtistMainRegion.latino;
      case 'asiatico':
      case 'asiatica':
        return ArtistMainRegion.asiatico;
      case 'anglo':
        return ArtistMainRegion.anglo;
      case 'europeo':
      case 'europea':
      case 'euro':
        return ArtistMainRegion.europeo;
      case 'africano':
      case 'africa':
        return ArtistMainRegion.africano;
      case 'medio_oriente':
      case 'medio oriente':
      case 'mideast':
        return ArtistMainRegion.medioOriente;
      case 'oceania':
      case 'oceánico':
      case 'oceanico':
        return ArtistMainRegion.oceania;
      case 'global':
        return ArtistMainRegion.global;
      default:
        return ArtistMainRegion.none;
    }
  }
}

class ArtistProfile {
  final String key;
  final String displayName;
  final String? country;
  final String? countryCode;
  final ArtistMainRegion mainRegion;
  final String? thumbnail;
  final String? thumbnailLocalPath;
  final ArtistProfileKind kind;
  final List<String> memberKeys;

  const ArtistProfile({
    required this.key,
    required this.displayName,
    this.country,
    this.countryCode,
    this.mainRegion = ArtistMainRegion.none,
    this.thumbnail,
    this.thumbnailLocalPath,
    this.kind = ArtistProfileKind.singer,
    this.memberKeys = const <String>[],
  });

  ArtistProfile copyWith({
    String? key,
    String? displayName,
    String? country,
    String? countryCode,
    ArtistMainRegion? mainRegion,
    String? thumbnail,
    String? thumbnailLocalPath,
    ArtistProfileKind? kind,
    List<String>? memberKeys,
  }) {
    return ArtistProfile(
      key: key ?? this.key,
      displayName: displayName ?? this.displayName,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      mainRegion: mainRegion ?? this.mainRegion,
      thumbnail: thumbnail ?? this.thumbnail,
      thumbnailLocalPath: thumbnailLocalPath ?? this.thumbnailLocalPath,
      kind: kind ?? this.kind,
      memberKeys: memberKeys ?? this.memberKeys,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'displayName': displayName,
    'country': country,
    'countryCode': countryCode,
    'mainRegion': mainRegion.key,
    'thumbnail': thumbnail,
    'thumbnailLocalPath': thumbnailLocalPath,
    'kind': kind.key,
    'memberKeys': memberKeys,
  };

  factory ArtistProfile.fromJson(Map<String, dynamic> json) {
    final rawMemberKeys = json['memberKeys'] as List?;
    final members =
        rawMemberKeys
            ?.map((e) => ArtistCreditParser.normalizeKey(e?.toString() ?? ''))
            .where((e) => e.isNotEmpty && e != 'unknown')
            .toSet()
            .toList(growable: false) ??
        const <String>[];
    final rawCountryCode =
        (json['countryCode'] ?? json['country_code'] ?? json['iso2'])
            ?.toString()
            .trim()
            .toUpperCase() ??
        '';
    final countryCode = RegExp(r'^[A-Z]{2}$').hasMatch(rawCountryCode)
        ? rawCountryCode
        : null;

    return ArtistProfile(
      key: (json['key'] as String?)?.trim() ?? '',
      displayName: (json['displayName'] as String?)?.trim() ?? '',
      country:
          (json['country'] as String?)?.trim() ??
          (json['pais'] as String?)?.trim(),
      countryCode: countryCode,
      mainRegion: ArtistMainRegionX.fromRaw(
        json['mainRegion'] ?? json['region'],
      ),
      thumbnail: (json['thumbnail'] as String?)?.trim(),
      thumbnailLocalPath: (json['thumbnailLocalPath'] as String?)?.trim(),
      kind: ArtistProfileKindX.fromRaw(json['kind']),
      memberKeys: members,
    );
  }

  static String normalizeKey(String raw) {
    return ArtistCreditParser.normalizeKey(raw);
  }
}
