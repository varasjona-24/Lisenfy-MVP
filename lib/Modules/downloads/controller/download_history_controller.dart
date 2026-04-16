import 'package:get/get.dart';
import 'package:listenfy/Modules/downloads/domain/entities/download_day_group.dart';
import 'package:listenfy/Modules/downloads/domain/entities/download_history_filter.dart';
import 'package:listenfy/Modules/downloads/domain/usecases/load_download_history_items_usecase.dart';
import 'package:listenfy/Modules/downloads/state/download_history_state.dart';
import 'package:listenfy/app/core/presentation/getx_state_controller.dart';
import 'package:listenfy/app/core/presentation/view_status.dart';

import '../../../app/models/media_item.dart';
import '../../home/controller/home_controller.dart';

// ============================
// 📅 BLOC: HISTORIAL DE IMPORTS
// ============================
class DownloadHistoryController
    extends GetxStateController<DownloadHistoryState> {
  DownloadHistoryController({
    required LoadDownloadHistoryItemsUseCase loadHistoryItemsUseCase,
    HomeController? homeController,
  }) : _loadHistoryItemsUseCase = loadHistoryItemsUseCase,
       _homeController = homeController,
       super(DownloadHistoryState.initial());

  final LoadDownloadHistoryItemsUseCase _loadHistoryItemsUseCase;
  final HomeController? _homeController;
  Worker? _homeWorker;
  final RxBool gridView = false.obs;

  // ============================
  // 🚀 INIT
  // ============================
  @override
  void onInit() {
    super.onInit();
    final home = _homeController;
    if (home != null) {
      _syncFilterWithHome();
      _homeWorker = ever<HomeMode>(home.mode, (_) {
        _syncFilterWithHome();
      });
    }
    loadHistory();
  }

  @override
  void onClose() {
    _homeWorker?.dispose();
    super.onClose();
  }

  // ============================
  // 📥 LOAD
  // ============================
  Future<void> loadHistory() async {
    emit(state.value.copyWith(status: ViewStatus.loading, clearError: true));

    try {
      final downloaded = await _loadHistoryItemsUseCase();
      final projected = _project(
        allItems: downloaded,
        filter: state.value.filter,
        query: state.value.query,
      );

      emit(
        state.value.copyWith(
          status: ViewStatus.success,
          allItems: downloaded,
          filteredItems: projected.filteredItems,
          groups: projected.groups,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.value.copyWith(
          status: ViewStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  // ============================
  // 🧩 HELPERS
  // ============================
  void setFilter(DownloadHistoryFilter next) {
    if (state.value.filter == next) return;
    final projected = _project(
      allItems: state.value.allItems,
      filter: next,
      query: state.value.query,
    );
    emit(
      state.value.copyWith(
        filter: next,
        filteredItems: projected.filteredItems,
        groups: projected.groups,
      ),
    );
  }

  void setQuery(String value) {
    if (state.value.query == value) return;
    final projected = _project(
      allItems: state.value.allItems,
      filter: state.value.filter,
      query: value,
    );
    emit(
      state.value.copyWith(
        query: value,
        filteredItems: projected.filteredItems,
        groups: projected.groups,
      ),
    );
  }

  void toggleGridView() {
    gridView.value = !gridView.value;
  }

  void _syncFilterWithHome() {
    final home = _homeController;
    if (home == null) return;
    final desired = home.mode.value == HomeMode.audio
        ? DownloadHistoryFilter.audio
        : DownloadHistoryFilter.video;
    setFilter(desired);
  }

  _HistoryProjection _project({
    required List<MediaItem> allItems,
    required DownloadHistoryFilter filter,
    required String query,
  }) {
    final filtered = _filterItems(allItems, filter, query);
    final groups = _groupByDay(filtered);
    return _HistoryProjection(filteredItems: filtered, groups: groups);
  }

  List<MediaItem> _filterItems(
    List<MediaItem> list,
    DownloadHistoryFilter filter,
    String query,
  ) {
    final isAudio = filter == DownloadHistoryFilter.audio;
    final q = query.trim().toLowerCase();
    return list.where((item) {
      final matchesKind = isAudio ? item.hasAudioLocal : item.hasVideoLocal;
      if (!matchesKind) return false;
      if (q.isEmpty) return true;
      return item.title.toLowerCase().contains(q) ||
          item.subtitle.toLowerCase().contains(q);
    }).toList();
  }

  List<DownloadDayGroup> _groupByDay(List<MediaItem> list) {
    final Map<String, List<MediaItem>> bucket = {};

    for (final item in list) {
      final ts = _latestVariantCreatedAt(item);
      if (ts <= 0) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final key = _dayKey(dt);
      bucket.putIfAbsent(key, () => []).add(item);
    }

    final keys = bucket.keys.toList()..sort((a, b) => b.compareTo(a));

    return keys.map((k) {
      final date = _parseDayKey(k);
      final label = _dayLabel(date);
      return DownloadDayGroup(
        date: date,
        label: label,
        items: bucket[k] ?? const <MediaItem>[],
      );
    }).toList();
  }

  int _latestVariantCreatedAt(MediaItem item) {
    var latest = 0;
    for (final v in item.variants) {
      if (v.localPath?.trim().isEmpty ?? true) continue;
      if (v.createdAt > latest) latest = v.createdAt;
    }
    return latest;
  }

  String formatTime(MediaItem item) {
    final ts = _latestVariantCreatedAt(item);
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _dayKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime _parseDayKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return DateTime.now();
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    final d = int.tryParse(parts[2]) ?? DateTime.now().day;
    return DateTime(y, m, d);
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final other = DateTime(date.year, date.month, date.day);
    final diff = today.difference(other).inDays;

    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';

    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }
}

class _HistoryProjection {
  const _HistoryProjection({required this.filteredItems, required this.groups});

  final List<MediaItem> filteredItems;
  final List<DownloadDayGroup> groups;
}
