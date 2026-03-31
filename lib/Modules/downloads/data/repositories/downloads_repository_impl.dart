import 'package:listenfy/Modules/downloads/domain/contracts/downloads_repository.dart';
import 'package:listenfy/app/data/repo/media_repository.dart';
import 'package:listenfy/app/models/media_item.dart';

// ============================
// 🗄️ REPOSITORY IMPL: IMPORTS
// ============================
class DownloadsRepositoryImpl implements DownloadsRepository {
  const DownloadsRepositoryImpl({required MediaRepository mediaRepository})
    : _mediaRepository = mediaRepository;

  final MediaRepository _mediaRepository;

  @override
  Future<List<MediaItem>> loadDownloadedItems() async {
    final library = await _mediaRepository.getLibrary();
    final list =
        library.where((item) {
          return item.variants.any((variant) {
            final path = (variant.localPath ?? '').trim();
            return path.isNotEmpty;
          });
        }).toList()..sort(
          (a, b) => _latestStoredVariantCreatedAt(
            b,
          ).compareTo(_latestStoredVariantCreatedAt(a)),
        );
    return list;
  }

  @override
  Future<List<MediaItem>> loadDownloadHistoryItems() async {
    final library = await _mediaRepository.getLibrary();
    final downloaded = library.where((e) => e.isOfflineStored).toList()
      ..sort(
        (a, b) => _latestStoredVariantCreatedAt(
          b,
        ).compareTo(_latestStoredVariantCreatedAt(a)),
      );
    return downloaded;
  }

  int _latestStoredVariantCreatedAt(MediaItem item) {
    var latest = 0;
    for (final variant in item.variants) {
      if (variant.localPath?.trim().isEmpty ?? true) continue;
      if (variant.createdAt > latest) latest = variant.createdAt;
    }
    return latest;
  }
}
