import 'package:listenfy/Modules/history/domain/contracts/history_repository.dart';
import 'package:listenfy/app/models/media_item.dart';

class LoadHistoryItemsUseCase {
  const LoadHistoryItemsUseCase({
    required HistoryRepository repository,
  }) : _repository = repository;

  final HistoryRepository _repository;

  Future<List<MediaItem>> call() {
    return _repository.loadHistoryItems();
  }
}

