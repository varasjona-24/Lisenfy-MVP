import 'package:listenfy/Modules/downloads/domain/contracts/downloads_repository.dart';
import 'package:listenfy/app/models/media_item.dart';

// ============================
// 🧠 USE CASE: CARGAR HISTORIAL DE IMPORTS
// ============================
class LoadDownloadHistoryItemsUseCase {
  const LoadDownloadHistoryItemsUseCase({
    required DownloadsRepository repository,
  }) : _repository = repository;

  final DownloadsRepository _repository;

  Future<List<MediaItem>> call() {
    return _repository.loadDownloadHistoryItems();
  }
}
