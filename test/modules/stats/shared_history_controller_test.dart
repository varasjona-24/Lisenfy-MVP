import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/Modules/downloads/controller/download_history_controller.dart';
import 'package:listenfy/Modules/downloads/domain/contracts/downloads_repository.dart';
import 'package:listenfy/Modules/downloads/domain/usecases/load_download_history_items_usecase.dart';
import 'package:listenfy/Modules/history/domain/contracts/history_repository.dart';
import 'package:listenfy/Modules/history/domain/usecases/load_history_items_usecase.dart';
import 'package:listenfy/app/models/media_item.dart';

class _Storage implements GetStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Items implements DownloadsRepository, HistoryRepository {
  final List<MediaItem> items;
  _Items(this.items);
  @override
  Future<List<MediaItem>> loadDownloadedItems() async => items;
  @override
  Future<List<MediaItem>> loadDownloadHistoryItems() async => items;
  @override
  Future<List<MediaItem>> loadHistoryItems() async =>
      items.where((item) => (item.lastPlayedAt ?? 0) > 0).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => Localization.load(
      const Locale('en'),
      translations: Translations(
        jsonDecode(File('assets/translations/en.json').readAsStringSync())
            as Map<String, dynamic>,
      ),
    ),
  );
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 12);
  final old = today.subtract(const Duration(days: 90));
  MediaItem item(String id, DateTime imported, DateTime? played) =>
      MediaItem.fromJson({
        'id': id,
        'title': id,
        'subtitle': 'Artist',
        'importedAt': imported.millisecondsSinceEpoch,
        'lastPlayedAt': played?.millisecondsSinceEpoch,
        'variants': [
          {
            'kind': 'audio',
            'format': 'mp3',
            'fileName': '$id.mp3',
            'localPath': '/$id.mp3',
            'createdAt': imported.millisecondsSinceEpoch,
          },
        ],
      });
  DownloadHistoryController controller(List<MediaItem> items) {
    final repository = _Items(items);
    return DownloadHistoryController(
      loadHistoryItemsUseCase: LoadDownloadHistoryItemsUseCase(
        repository: repository,
      ),
      loadPlayedItemsUseCase: LoadHistoryItemsUseCase(repository: repository),
      storage: _Storage(),
    );
  }

  test(
    'source changes calendar dates, ordering and time without duplicating songs',
    () async {
      final c = controller([
        item('old import', old, today),
        item('new import', today, old),
        item('unplayed', today, null),
      ]);
      await c.loadHistory();
      c.selectDate(today);
      expect(
        c.selectedDateItems().map((item) => item.id),
        containsAll(['new import', 'unplayed']),
      );
      await c.setSource(HistorySource.played);
      c.selectDate(today);
      expect(c.selectedDateItems().map((item) => item.id), ['old import']);
      expect(c.state.value.filteredItems.map((item) => item.id), [
        'old import',
        'new import',
      ]);
      expect(c.formatTime(c.state.value.filteredItems.first), '12:00');
      expect(c.importCountForDay(today), 1);
      expect(
        c.itemsGroupedByDay().values.expand((items) => items),
        hasLength(2),
      );
    },
  );

  test(
    'search and active range are preserved across source switches and refresh',
    () async {
      final c = controller([
        item('target', old, today),
        item('other', today, old),
      ]);
      await c.loadHistory();
      c.filterByRange('lastWeek');
      c.setQuery('target');
      expect(c.state.value.filteredItems, isEmpty);
      await c.setSource(HistorySource.played);
      expect(c.state.value.filteredItems.single.id, 'target');
      await c.loadHistory();
      expect(c.state.value.filteredItems.single.id, 'target');
      await c.setSource(HistorySource.imports);
      expect(c.state.value.filteredItems, isEmpty);
      c.setCustomDateRange(old, old);
      expect(c.state.value.filteredItems.single.id, 'target');
      await c.setSource(HistorySource.played);
      expect(c.state.value.filteredItems, isEmpty);
      await c.loadHistory();
      expect(c.state.value.filteredItems, isEmpty);
    },
  );
}
