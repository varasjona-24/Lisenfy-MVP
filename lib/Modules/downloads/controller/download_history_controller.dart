import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/app/models/history_group.dart';
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
  final GetStorage _storage = GetStorage();
  final RxBool gridView = true.obs;

  // ============================
  // 🚀 INIT
  // ============================
  @override
  void onInit() {
    super.onInit();
    gridView.value = _storage.read('download_history_grid_view') ?? true;
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

  void toggleSection(String sectionId) {
    final current = Set<String>.from(state.value.expandedSections);
    if (current.contains(sectionId)) {
      current.remove(sectionId);
    } else {
      current.add(sectionId);
    }
    emit(state.value.copyWith(expandedSections: current));
  }

  void toggleGridView() {
    gridView.value = !gridView.value;
    _storage.write('download_history_grid_view', gridView.value);
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
    final groups = _groupHistory(filtered);
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

  List<HistoryGroup> _groupHistory(List<MediaItem> items) {
    if (items.isEmpty) return [];

    final now = DateTime.now();
    final List<HistoryGroup> finalGroups = [];

    // Separate current month items from older ones
    final currentMonthItems = items.where((item) {
      final dt = DateTime.fromMillisecondsSinceEpoch(_latestVariantCreatedAt(item));
      return dt.year == now.year && dt.month == now.month;
    }).toList();

    final olderItems = items.where((item) {
      final dt = DateTime.fromMillisecondsSinceEpoch(_latestVariantCreatedAt(item));
      return !(dt.year == now.year && dt.month == now.month);
    }).toList();

    // 1. Current Month: Flat Daily Detail
    if (currentMonthItems.isNotEmpty) {
      finalGroups.addAll(_buildDailyGroups(currentMonthItems, now));
    }

    // 2. Older Items: Nested Month > Week > Day
    if (olderItems.isNotEmpty) {
      finalGroups.addAll(_buildNestedMonthlyGroups(olderItems));
    }

    return finalGroups;
  }

  List<HistoryGroup> _buildDailyGroups(List<MediaItem> items, DateTime now) {
    final Map<String, List<MediaItem>> bucket = {};
    for (final item in items) {
      final dt = DateTime.fromMillisecondsSinceEpoch(_latestVariantCreatedAt(item));
      final key = _dayKey(dt);
      bucket.putIfAbsent(key, () => []).add(item);
    }

    final keys = bucket.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys.map((k) {
      final firstItem = bucket[k]!.first;
      final date = DateTime.fromMillisecondsSinceEpoch(_latestVariantCreatedAt(firstItem));
      return HistoryGroup(
        id: k,
        label: _dayLabel(date, now),
        date: date,
        items: bucket[k],
      );
    }).toList();
  }

  List<HistoryGroup> _buildNestedMonthlyGroups(List<MediaItem> items) {
    // Group 1: By Month
    final Map<String, List<MediaItem>> monthBucket = {};
    for (final item in items) {
      final dt = DateTime.fromMillisecondsSinceEpoch(_latestVariantCreatedAt(item));
      final monthIndex = dt.month.toString().padLeft(2, '0');
      final key = '${dt.year}-$monthIndex';
      monthBucket.putIfAbsent(key, () => []).add(item);
    }

    final monthKeys = monthBucket.keys.toList()..sort((a, b) => b.compareTo(a));

    return monthKeys.map((mKey) {
      final monthItems = monthBucket[mKey]!;
      final date = DateTime.fromMillisecondsSinceEpoch(_latestVariantCreatedAt(monthItems.first));

      return HistoryGroup(
        id: mKey,
        label: _monthLabel(date, DateTime.now()),
        date: date,
        subGroups: _buildWeeklyGroups(monthItems, mKey),
      );
    }).toList();
  }

  List<HistoryGroup> _buildWeeklyGroups(List<MediaItem> items, String monthKey) {
    final Map<int, List<MediaItem>> weekBucket = {};
    for (final item in items) {
      final dt = DateTime.fromMillisecondsSinceEpoch(_latestVariantCreatedAt(item));
      // Calculate week of month roughly
      final weekNum = ((dt.day - 1) / 7).floor() + 1;
      weekBucket.putIfAbsent(weekNum, () => []).add(item);
    }

    final weekNums = weekBucket.keys.toList()..sort((a, b) => b.compareTo(a));

    return weekNums.map((wn) {
      final weekItems = weekBucket[wn]!;
      final date = DateTime.fromMillisecondsSinceEpoch(_latestVariantCreatedAt(weekItems.first));

      return HistoryGroup(
        id: '$monthKey-W$wn',
        label: 'Semana $wn',
        date: date,
        subGroups: _buildDailyGroups(weekItems, DateTime.now()),
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

  String _dayLabel(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final other = DateTime(date.year, date.month, date.day);
    final diff = today.difference(other).inDays;

    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';

    final weekdays = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final dayName = weekdays[date.weekday];
    return '$dayName ${date.day}/${date.month}';
  }

  String _monthLabel(DateTime date, DateTime now) {
    final months = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    final monthName = months[date.month];

    if (date.year == now.year) {
      return monthName;
    } else {
      return '$monthName ${date.year}';
    }
  }
}

class _HistoryProjection {
  const _HistoryProjection({required this.filteredItems, required this.groups});

  final List<MediaItem> filteredItems;
  final List<HistoryGroup> groups;
}
