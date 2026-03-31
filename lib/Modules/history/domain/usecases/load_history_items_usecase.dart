import 'package:listenfy/Modules/history/domain/contracts/history_repository.dart';
import 'package:listenfy/app/models/media_item.dart';

// ============================
// 🧠 USE CASE: CARGAR HISTORIAL
// ============================
// Punto de entrada de dominio para cargar historial desde su contrato.
class LoadHistoryItemsUseCase {
  const LoadHistoryItemsUseCase({
    required HistoryRepository repository,
  }) : _repository = repository;

  final HistoryRepository _repository;

  /// Ejecuta el caso de uso.
  Future<List<MediaItem>> call() {
    return _repository.loadHistoryItems();
  }
}
