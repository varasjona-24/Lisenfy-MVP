import 'package:get/get.dart';
import '../../../app/data/local/catalog_storage.dart';
import '../../../app/models/media_item.dart';
import '../../../app/utils/artist_credit_parser.dart';

ArtistCredits resolveArtistCredits(MediaItem item) {
  if (Get.isRegistered<CatalogStorage>()) {
    final credits = Get.find<CatalogStorage>().creditsFor(
      item.id,
      item.subtitle,
    );
    if (credits != null) return credits;
  }
  // Legacy mode or an unsaved edit: never apply stale SQL credit roles.
  return ArtistCreditParser.parse(item.subtitle);
}
