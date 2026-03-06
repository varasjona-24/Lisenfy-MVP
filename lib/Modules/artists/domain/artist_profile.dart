import '../../../app/utils/artist_credit_parser.dart';

enum ArtistProfileKind { singer, band }

extension ArtistProfileKindX on ArtistProfileKind {
  String get key => switch (this) {
    ArtistProfileKind.singer => 'singer',
    ArtistProfileKind.band => 'band',
  };

  static ArtistProfileKind fromRaw(dynamic raw) {
    final key = (raw ?? '').toString().trim().toLowerCase();
    if (key == 'band') return ArtistProfileKind.band;
    return ArtistProfileKind.singer;
  }
}

class ArtistProfile {
  final String key;
  final String displayName;
  final String? thumbnail;
  final String? thumbnailLocalPath;
  final ArtistProfileKind kind;
  final List<String> memberKeys;

  const ArtistProfile({
    required this.key,
    required this.displayName,
    this.thumbnail,
    this.thumbnailLocalPath,
    this.kind = ArtistProfileKind.singer,
    this.memberKeys = const <String>[],
  });

  ArtistProfile copyWith({
    String? key,
    String? displayName,
    String? thumbnail,
    String? thumbnailLocalPath,
    ArtistProfileKind? kind,
    List<String>? memberKeys,
  }) {
    return ArtistProfile(
      key: key ?? this.key,
      displayName: displayName ?? this.displayName,
      thumbnail: thumbnail ?? this.thumbnail,
      thumbnailLocalPath: thumbnailLocalPath ?? this.thumbnailLocalPath,
      kind: kind ?? this.kind,
      memberKeys: memberKeys ?? this.memberKeys,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'displayName': displayName,
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

    return ArtistProfile(
      key: (json['key'] as String?)?.trim() ?? '',
      displayName: (json['displayName'] as String?)?.trim() ?? '',
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
