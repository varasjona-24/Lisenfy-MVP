import 'package:flutter/material.dart' show DateTimeRange;
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
  final Rx<DateTime> selectedDate = Rx<DateTime>(DateTime.now());
  final RxBool calendarMode = true.obs;
  final Rx<DateTime> visibleMonth = Rx<DateTime>(
    DateTime(DateTime.now().year, DateTime.now().month),
  );
  final Rx<String> dateFilterRange = Rx<String>('all');
  final Rx<DateTimeRange?> customDateRange = Rx<DateTimeRange?>(null);

  // ============================
  // 🚀 INIT
  // ============================
  @override
  void onInit() {
    super.onInit();
    gridView.value = _storage.read('download_history_grid_view') ?? true;
    calendarMode.value =
        _storage.read('download_history_calendar_mode') ?? true;
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
      // Al cargar de nuevo, el rango de fechas se reinicia a 'all',
      // así que baseItems == allItems.
      final projected = _project(
        baseItems: downloaded,
        filter: state.value.filter,
        query: state.value.query,
      );
      _ensureSelectedDate(projected.filteredItems);

      emit(
        state.value.copyWith(
          status: ViewStatus.success,
          allItems: downloaded,
          baseItems: downloaded,
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

  /// Filtra por tipo (audio/video) manteniendo el rango de fechas activo.
  void setFilter(DownloadHistoryFilter next) {
    if (state.value.filter == next) return;
    final projected = _project(
      baseItems: state.value.baseItems,
      filter: next,
      query: state.value.query,
    );
    _ensureSelectedDate(projected.filteredItems);
    emit(
      state.value.copyWith(
        filter: next,
        filteredItems: projected.filteredItems,
        groups: projected.groups,
      ),
    );
  }

  /// Filtra por texto de búsqueda, respetando el rango de fechas y tipo activos.
  void setQuery(String value) {
    if (state.value.query == value) return;
    final projected = _project(
      baseItems: state.value.baseItems,
      filter: state.value.filter,
      query: value,
    );
    _ensureSelectedDate(projected.filteredItems);
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

  void toggleCalendarMode() {
    calendarMode.value = !calendarMode.value;
    _storage.write('download_history_calendar_mode', calendarMode.value);
  }

  void selectDate(DateTime date) {
    selectedDate.value = DateTime(date.year, date.month, date.day);
    visibleMonth.value = DateTime(date.year, date.month);
  }

  void previousMonth() {
    final current = visibleMonth.value;
    visibleMonth.value = DateTime(current.year, current.month - 1);
  }

  void nextMonth() {
    final current = visibleMonth.value;
    visibleMonth.value = DateTime(current.year, current.month + 1);
  }

  List<DateTime> visibleMonthDays() {
    final month = visibleMonth.value;
    final totalDays = DateTime(month.year, month.month + 1, 0).day;
    return List<DateTime>.generate(
      totalDays,
      (index) => DateTime(month.year, month.month, index + 1),
    );
  }

  int importCountForDay(DateTime date) {
    final key = _dayKey(date);
    var count = 0;
    for (final item in state.value.filteredItems) {
      final ts = _latestVariantCreatedAt(item);
      if (ts <= 0) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      if (_dayKey(dt) == key) count++;
    }
    return count;
  }

  List<MediaItem> selectedDateItems() {
    final key = _dayKey(selectedDate.value);
    return state.value.filteredItems
        .where((item) {
          final ts = _latestVariantCreatedAt(item);
          if (ts <= 0) return false;
          final dt = DateTime.fromMillisecondsSinceEpoch(ts);
          return _dayKey(dt) == key;
        })
        .toList(growable: false);
  }

  String visibleMonthLabel() {
    return _monthLabel(visibleMonth.value, DateTime.now());
  }

  String selectedDateLabel() {
    return _dayLabel(selectedDate.value, DateTime.now());
  }

  void _syncFilterWithHome() {
    final home = _homeController;
    if (home == null) return;
    final desired = home.mode.value == HomeMode.audio
        ? DownloadHistoryFilter.audio
        : DownloadHistoryFilter.video;
    setFilter(desired);
  }

  // ============================
  // 🔍 PROYECCIÓN (tipo + query)
  // ============================
  _HistoryProjection _project({
    required List<MediaItem> baseItems,
    required DownloadHistoryFilter filter,
    required String query,
  }) {
    final filtered = _filterItems(baseItems, filter, query);
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

    final currentMonthItems = items.where((item) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        _latestVariantCreatedAt(item),
      );
      return dt.year == now.year && dt.month == now.month;
    }).toList();

    final olderItems = items.where((item) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        _latestVariantCreatedAt(item),
      );
      return !(dt.year == now.year && dt.month == now.month);
    }).toList();

    if (currentMonthItems.isNotEmpty) {
      finalGroups.addAll(_buildDailyGroups(currentMonthItems, now));
    }

    if (olderItems.isNotEmpty) {
      finalGroups.addAll(_buildNestedMonthlyGroups(olderItems));
    }

    return finalGroups;
  }

  List<HistoryGroup> _buildDailyGroups(List<MediaItem> items, DateTime now) {
    final Map<String, List<MediaItem>> bucket = {};
    for (final item in items) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        _latestVariantCreatedAt(item),
      );
      final key = _dayKey(dt);
      bucket.putIfAbsent(key, () => []).add(item);
    }

    final keys = bucket.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys.map((k) {
      final firstItem = bucket[k]!.first;
      final date = DateTime.fromMillisecondsSinceEpoch(
        _latestVariantCreatedAt(firstItem),
      );
      return HistoryGroup(
        id: k,
        label: _dayLabel(date, now),
        date: date,
        items: bucket[k],
      );
    }).toList();
  }

  List<HistoryGroup> _buildNestedMonthlyGroups(List<MediaItem> items) {
    final Map<String, List<MediaItem>> monthBucket = {};
    for (final item in items) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        _latestVariantCreatedAt(item),
      );
      final monthIndex = dt.month.toString().padLeft(2, '0');
      final key = '${dt.year}-$monthIndex';
      monthBucket.putIfAbsent(key, () => []).add(item);
    }

    final monthKeys = monthBucket.keys.toList()..sort((a, b) => b.compareTo(a));

    return monthKeys.map((mKey) {
      final monthItems = monthBucket[mKey]!;
      final date = DateTime.fromMillisecondsSinceEpoch(
        _latestVariantCreatedAt(monthItems.first),
      );

      return HistoryGroup(
        id: mKey,
        label: _monthLabel(date, DateTime.now()),
        date: date,
        subGroups: _buildWeeklyGroups(monthItems, mKey),
      );
    }).toList();
  }

  List<HistoryGroup> _buildWeeklyGroups(
    List<MediaItem> items,
    String monthKey,
  ) {
    final Map<int, List<MediaItem>> weekBucket = {};
    for (final item in items) {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        _latestVariantCreatedAt(item),
      );
      final weekNum = ((dt.day - 1) / 7).floor() + 1;
      weekBucket.putIfAbsent(weekNum, () => []).add(item);
    }

    final weekNums = weekBucket.keys.toList()..sort((a, b) => b.compareTo(a));

    return weekNums.map((wn) {
      final weekItems = weekBucket[wn]!;
      final date = DateTime.fromMillisecondsSinceEpoch(
        _latestVariantCreatedAt(weekItems.first),
      );

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

  void _ensureSelectedDate(List<MediaItem> items) {
    if (items.isEmpty) return;

    final selectedKey = _dayKey(selectedDate.value);
    final selectedHasItems = items.any((item) {
      final ts = _latestVariantCreatedAt(item);
      if (ts <= 0) return false;
      return _dayKey(DateTime.fromMillisecondsSinceEpoch(ts)) == selectedKey;
    });
    if (selectedHasItems) return;

    final latest = items
        .map(_latestVariantCreatedAt)
        .where((ts) => ts > 0)
        .fold<int>(0, (best, ts) => ts > best ? ts : best);
    if (latest <= 0) return;

    final dt = DateTime.fromMillisecondsSinceEpoch(latest);
    final day = DateTime(dt.year, dt.month, dt.day);
    selectedDate.value = day;
    visibleMonth.value = DateTime(day.year, day.month);
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

    final weekdays = [
      '',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final dayName = weekdays[date.weekday];
    return '$dayName ${date.day}/${date.month}';
  }

  String _monthLabel(DateTime date, DateTime now) {
    final months = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final monthName = months[date.month];

    if (date.year == now.year) {
      return monthName;
    } else {
      return '$monthName ${date.year}';
    }
  }

  // ============================
  // 📅 CALENDAR UTILITIES
  // ============================
  List<DateTime> daysWithImports() {
    final Set<String> daysSet = {};
    for (final item in state.value.filteredItems) {
      final ts = _latestVariantCreatedAt(item);
      if (ts <= 0) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      daysSet.add(_dayKey(dt));
    }
    return daysSet.map((key) {
      final parts = key.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }).toList()..sort();
  }

  bool hasImportsOnDay(DateTime day) {
    final key = _dayKey(day);
    return state.value.filteredItems.any((item) {
      final ts = _latestVariantCreatedAt(item);
      if (ts <= 0) return false;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      return _dayKey(dt) == key;
    });
  }

  // ============================
  // 📆 FILTRO POR RANGO DE FECHAS
  // ============================
  /// Aplica el filtro de rango de fechas sobre `allItems`,
  /// actualiza `baseItems` y re-proyecta con el tipo y query actuales.
  void filterByRange(String range) {
    if (dateFilterRange.value == range) return;

    dateFilterRange.value = range;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<MediaItem> newBase;

    switch (range) {
      case 'lastWeek':
        final sevenDaysStart = today.subtract(const Duration(days: 6));
        final tomorrowStart = today.add(const Duration(days: 1));
        newBase = state.value.allItems.where((item) {
          final ts = _latestVariantCreatedAt(item);
          if (ts <= 0) return false;
          final dt = DateTime.fromMillisecondsSinceEpoch(ts);
          return !dt.isBefore(sevenDaysStart) && dt.isBefore(tomorrowStart);
        }).toList();
        break;
      case 'lastMonth':
        final startOfMonth = DateTime(now.year, now.month, 1);
        final startOfNextMonth = DateTime(now.year, now.month + 1, 1);
        newBase = state.value.allItems.where((item) {
          final ts = _latestVariantCreatedAt(item);
          if (ts <= 0) return false;
          final dt = DateTime.fromMillisecondsSinceEpoch(ts);
          return !dt.isBefore(startOfMonth) && dt.isBefore(startOfNextMonth);
        }).toList();
        break;
      default: // 'all'
        newBase = state.value.allItems;
    }

    final projected = _project(
      baseItems: newBase,
      filter: state.value.filter,
      query: state.value.query,
    );
    _ensureSelectedDate(projected.filteredItems);
    emit(
      state.value.copyWith(
        baseItems: newBase,
        filteredItems: projected.filteredItems,
        groups: projected.groups,
      ),
    );
  }

  bool isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  // ============================
  // 📋 SIMPLE DAY GROUPING
  // ============================
  /// Agrupa items por día de forma simple: {fechaKey -> items}
  Map<String, List<MediaItem>> itemsGroupedByDay() {
    final Map<String, List<MediaItem>> groups = {};
    for (final item in state.value.filteredItems) {
      final ts = _latestVariantCreatedAt(item);
      if (ts <= 0) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final key = _dayKey(dt);
      groups.putIfAbsent(key, () => []).add(item);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final sorted = <String, List<MediaItem>>{};
    for (final key in sortedKeys) {
      sorted[key] = groups[key]!;
    }
    return sorted;
  }

  /// Obtiene label amigable para una fecha en formato día/mes
  String dayLabelSimple(DateTime date) {
    return '${date.day}/${date.month}';
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    const maxRange = Duration(days: 75); // ~2.5 meses
    final DateTimeRange range;
    if (end.difference(start).compareTo(maxRange) > 0) {
      range = DateTimeRange(start: start, end: start.add(maxRange));
    } else {
      range = DateTimeRange(start: start, end: end);
    }

    customDateRange.value = range;
    dateFilterRange.value = 'custom';

    final newBase = state.value.allItems.where((item) {
      final ts = _latestVariantCreatedAt(item);
      if (ts <= 0) return false;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final endExclusive = DateTime(
        range.end.year,
        range.end.month,
        range.end.day + 1,
      );
      return !dt.isBefore(start) && dt.isBefore(endExclusive);
    }).toList();

    final projected = _project(
      baseItems: newBase,
      filter: state.value.filter,
      query: state.value.query,
    );
    _ensureSelectedDate(projected.filteredItems);
    emit(
      state.value.copyWith(
        baseItems: newBase,
        filteredItems: projected.filteredItems,
        groups: projected.groups,
      ),
    );
  }

  String customDateRangeLabel() {
    final range = customDateRange.value;
    if (range == null) return 'Seleccionar rango';
    return '${dayLabelSimple(range.start)} - ${dayLabelSimple(range.end)}';
  }
}

class _HistoryProjection {
  const _HistoryProjection({required this.filteredItems, required this.groups});

  final List<MediaItem> filteredItems;
  final List<HistoryGroup> groups;
}
