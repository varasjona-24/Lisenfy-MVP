import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;

import '../../../app/utils/artist_credit_parser.dart';

enum ArtistProfileKind { singer, band }

extension ArtistProfileKindX on ArtistProfileKind {
  String get key => switch (this) {
    ArtistProfileKind.singer => 'singer',
    ArtistProfileKind.band => 'band',
  };

  String get label => switch (this) {
    ArtistProfileKind.singer => tr('artists.profile.kind.singer'),
    ArtistProfileKind.band => tr('artists.profile.kind.band'),
  };

  String get sectionLabel => switch (this) {
    ArtistProfileKind.singer => tr('artists.profile.sections.singer'),
    ArtistProfileKind.band => tr('artists.profile.sections.band'),
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
    ArtistMainRegion.none => tr('artists.profile.region.label.none'),
    ArtistMainRegion.latino => tr('artists.profile.region.label.latino'),
    ArtistMainRegion.asiatico => tr('artists.profile.region.label.asiatico'),
    ArtistMainRegion.anglo => tr('artists.profile.region.label.anglo'),
    ArtistMainRegion.europeo => tr('artists.profile.region.label.europeo'),
    ArtistMainRegion.africano => tr('artists.profile.region.label.africano'),
    ArtistMainRegion.medioOriente => tr(
      'artists.profile.region.label.medio_oriente',
    ),
    ArtistMainRegion.oceania => tr('artists.profile.region.label.oceania'),
    ArtistMainRegion.global => tr('artists.profile.region.label.global'),
  };

  String get simpleLabel => switch (this) {
    ArtistMainRegion.none => tr('artists.profile.region.simple.none'),
    ArtistMainRegion.latino => tr('artists.profile.region.simple.latino'),
    ArtistMainRegion.asiatico => tr('artists.profile.region.simple.asiatico'),
    ArtistMainRegion.anglo => tr('artists.profile.region.simple.anglo'),
    ArtistMainRegion.europeo => tr('artists.profile.region.simple.europeo'),
    ArtistMainRegion.africano => tr('artists.profile.region.simple.africano'),
    ArtistMainRegion.medioOriente => tr(
      'artists.profile.region.simple.medio_oriente',
    ),
    ArtistMainRegion.oceania => tr('artists.profile.region.simple.oceania'),
    ArtistMainRegion.global => tr('artists.profile.region.simple.global'),
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
