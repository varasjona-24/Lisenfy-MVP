import 'package:listenfy/Modules/history/domain/contracts/history_repository.dart';
import 'package:listenfy/app/data/repo/media_repository.dart';
import 'package:listenfy/app/models/media_item.dart';

// ============================
// 🗄️ REPOSITORY IMPL: HISTORIAL
// ============================
// Implementa el contrato de dominio usando MediaRepository.
class HistoryRepositoryImpl implements HistoryRepository {
  const HistoryRepositoryImpl({
    required MediaRepository mediaRepository,
  }) : _mediaRepository = mediaRepository;

  final MediaRepository _mediaRepository;

  @override
  Future<List<MediaItem>> loadHistoryItems() async {
    // Toma la librería y conserva solo elementos reproducidos.
    final library = await _mediaRepository.getLibrary();
    final recent = library.where((e) => (e.lastPlayedAt ?? 0) > 0).toList()
      // Orden descendente por última reproducción.
      ..sort((a, b) => (b.lastPlayedAt ?? 0).compareTo(a.lastPlayedAt ?? 0));
    return recent;
  }
}
