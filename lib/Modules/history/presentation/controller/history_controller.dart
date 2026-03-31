import 'package:get/get.dart';
import 'package:listenfy/Modules/history/domain/entities/history_day_group.dart';
import 'package:listenfy/Modules/history/domain/entities/history_kind_filter.dart';
import 'package:listenfy/Modules/history/domain/usecases/load_history_items_usecase.dart';
import 'package:listenfy/Modules/history/presentation/state/history_state.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import 'package:listenfy/app/core/presentation/getx_state_controller.dart';
import 'package:listenfy/app/core/presentation/view_status.dart';
import 'package:listenfy/app/models/media_item.dart';

class HistoryController extends GetxStateController<HistoryState> {
  HistoryController({
    required LoadHistoryItemsUseCase loadHistoryItemsUseCase,
    HomeController? homeController,
  })  : _loadHistoryItemsUseCase = loadHistoryItemsUseCase,
        _homeController = homeController,
        super(HistoryState.initial());

  final LoadHistoryItemsUseCase _loadHistoryItemsUseCase;
  final HomeController? _homeController;
  Worker? _homeWorker;

  @override
  void onInit() {
    super.onInit();
    if (_homeController != null) {
      _syncFilterWithHome();
      _homeWorker = ever<HomeMode>(_homeController!.mode, (_) {
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

  Future<void> loadHistory() async {
    emit(
      state.value.copyWith(
        status: ViewStatus.loading,
        clearError: true,
      ),
    );

    try {
      final recent = await _loadHistoryItemsUseCase();
      final nextFiltered = _filterItems(recent, state.value.filter);
      final nextGroups = _groupByDay(nextFiltered);

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

  void setFilter(HistoryKindFilter next) {
    if (state.value.filter == next) return;
    final nextFiltered = _filterItems(state.value.allItems, next);
    final nextGroups = _groupByDay(nextFiltered);
    emit(
      state.value.copyWith(
        filter: next,
        filteredItems: nextFiltered,
        groups: nextGroups,
      ),
    );
  }

  void _syncFilterWithHome() {
    final home = _homeController;
    if (home == null) return;
    final desired = home.mode.value == HomeMode.audio
        ? HistoryKindFilter.audio
        : HistoryKindFilter.video;
    setFilter(desired);
  }

  List<MediaItem> _filterItems(
    List<MediaItem> list,
    HistoryKindFilter kind,
  ) {
    return list.where((item) {
      if (kind == HistoryKindFilter.audio) return item.hasAudioLocal;
      return item.hasVideoLocal;
    }).toList(growable: false);
  }

  List<HistoryDayGroup> _groupByDay(List<MediaItem> list) {
    final bucket = <String, List<MediaItem>>{};

    for (final item in list) {
      final ts = item.lastPlayedAt ?? 0;
      if (ts <= 0) continue;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final key = _dayKey(dt);
      bucket.putIfAbsent(key, () => <MediaItem>[]).add(item);
    }

    final keys = bucket.keys.toList()..sort((a, b) => b.compareTo(a));
    return keys
        .map((key) {
          final date = _parseDayKey(key);
          return HistoryDayGroup(
            date: date,
            label: _dayLabel(date),
            items: bucket[key] ?? const <MediaItem>[],
          );
        })
        .toList(growable: false);
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

  String formatTime(MediaItem item) {
    final ts = item.lastPlayedAt ?? 0;
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

