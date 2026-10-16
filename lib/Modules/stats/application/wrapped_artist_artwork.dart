import '../../../app/models/media_item.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../../artists/domain/artist_profile.dart';

/// Display-only snapshot: no artist is merged or assigned by this resolver.
MediaItem wrappedArtistArtwork(
  String name, {
  required List<ArtistProfile> profiles,
  required List<MediaItem> items,
}) {
  final key = ArtistCreditParser.normalizeKey(name);
  final matches = profiles
      .where((p) => ArtistCreditParser.normalizeKey(p.displayName) == key)
      .toList();
  String? local;
  String? remote;
  if (matches.length == 1) {
    local = matches.single.thumbnailLocalPath;
    remote = matches.single.thumbnail;
  }
  if (matches.length <= 1 &&
      (local?.trim().isEmpty ?? true) &&
      (remote?.trim().isEmpty ?? true)) {
    for (final item in items) {
      if (ArtistCreditParser.parse(item.displaySubtitle).allArtists.any(
            (artist) => ArtistCreditParser.normalizeKey(artist) == key,
          ) &&
          item.effectiveThumbnail != null) {
        local = item.thumbnailLocalPath;
        remote = item.thumbnail;
        break;
      }
    }
  }
  return MediaItem.fromJson({
    'id': 'wrapped-artist:$key',
    'title': name,
    'thumbnailLocalPath': local,
    'thumbnail': remote,
    'variants': [],
  });
}
