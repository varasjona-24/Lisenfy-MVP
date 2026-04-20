import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:listenfy/app/models/history_group.dart';
import 'package:listenfy/Modules/history/domain/entities/history_kind_filter.dart';
import 'package:listenfy/Modules/history/domain/usecases/load_history_items_usecase.dart';
import 'package:listenfy/Modules/history/state/history_state.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import 'package:listenfy/app/core/presentation/getx_state_controller.dart';
import 'package:listenfy/app/core/presentation/view_status.dart';
import 'package:listenfy/app/models/media_item.dart';

// ============================
// 🎛️ CONTROLLER: HISTORIAL
// ============================
class HistoryController extends GetxStateController<HistoryState> {
  HistoryController({
    required LoadHistoryItemsUseCase loadHistoryItemsUseCase,
    HomeController? homeController,
  }) : _loadHistoryItemsUseCase = loadHistoryItemsUseCase,
       _homeController = homeController,
       super(HistoryState.initial());

  final LoadHistoryItemsUseCase _loadHistoryItemsUseCase;
  final HomeController? _homeController;
  Worker? _homeWorker;
  final GetStorage _storage = GetStorage();
  final RxBool gridView = true.obs;

  // ============================
  // 🔁 LIFECYCLE
  // ============================
  @override
  void onInit() {
    super.onInit();
    gridView.value = _storage.read('history_grid_view') ?? true;
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
      final recent = await _loadHistoryItemsUseCase();
      final nextFiltered = _filterItems(recent, state.value.filter);
      final nextGroups = _groupHistory(nextFiltered);

      emit(
        state.value.copyWith(
          status: ViewStatus.success,
          allItems: recent,
          filteredItems: nextFiltered,
          groups: nextGroups,
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
  // 🎚️ FILTROS
  // ============================
  void setFilter(HistoryKindFilter next) {
    if (state.value.filter == next) return;
    final nextFiltered = _filterItems(state.value.allItems, next);
    final nextGroups = _groupHistory(nextFiltered);
    emit(
      state.value.copyWith(
        filter: next,
        filteredItems: nextFiltered,
        groups: nextGroups,
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
    _storage.write('history_grid_view', gridView.value);
  }

  // Sincroniza el filtro de historial con el modo actual del Home.
  void _syncFilterWithHome() {
    final home = _homeController;
    if (home == null) return;
    final desired = home.mode.value == HomeMode.audio
        ? HistoryKindFilter.audio
        : HistoryKindFilter.video;
    setFilter(desired);
  }
  // 🧩 HELPERS DE TRANSFORMACIÓN
  // ============================
  List<MediaItem> _filterItems(List<MediaItem> list, HistoryKindFilter kind) {
    return list
        .where((item) {
          if (kind == HistoryKindFilter.audio) return item.hasAudioLocal;
          return item.hasVideoLocal;
        })
        .toList(growable: false);
  }

  List<HistoryGroup> _groupHistory(List<MediaItem> items) {
    if (items.isEmpty) return [];

    final now = DateTime.now();
    final List<HistoryGroup> finalGroups = [];

    // Separate current month items from older ones
    final currentMonthItems = items.where((item) {
      final ts = item.lastPlayedAt ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      return dt.year == now.year && dt.month == now.month;
    }).toList();

    final olderItems = items.where((item) {
      final ts = item.lastPlayedAt ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
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
      final ts = item.lastPlayedAt ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final key = _dayKey(dt);
      bucket.putIfAbsent(key, () => []).add(item);
    }

    final keys = bucket.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys.map((k) {
      final firstItem = bucket[k]!.first;
      final ts = firstItem.lastPlayedAt ?? 0;
      final date = DateTime.fromMillisecondsSinceEpoch(ts);
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
      final ts = item.lastPlayedAt ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final mKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      monthBucket.putIfAbsent(mKey, () => []).add(item);
    }

    final monthKeys = monthBucket.keys.toList()..sort((a, b) => b.compareTo(a));

    return monthKeys.map((mKey) {
      final monthItems = monthBucket[mKey]!;
      final date = DateTime.fromMillisecondsSinceEpoch(monthItems.first.lastPlayedAt ?? 0);

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
      final ts = item.lastPlayedAt ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final weekNum = ((dt.day - 1) / 7).floor() + 1;
      weekBucket.putIfAbsent(weekNum, () => []).add(item);
    }

    final weekNums = weekBucket.keys.toList()..sort((a, b) => b.compareTo(a));

    return weekNums.map((wn) {
      final weekItems = weekBucket[wn]!;
      final date = DateTime.fromMillisecondsSinceEpoch(weekItems.first.lastPlayedAt ?? 0);

      return HistoryGroup(
        id: '$monthKey-W$wn',
        label: 'Semana $wn',
        date: date,
        subGroups: _buildDailyGroups(weekItems, DateTime.now()),
      );
    }).toList();
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

  String formatTime(MediaItem item) {
    final ts = item.lastPlayedAt ?? 0;
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
