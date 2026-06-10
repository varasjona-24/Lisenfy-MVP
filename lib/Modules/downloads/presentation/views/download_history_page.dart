import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../app/controllers/media_actions_controller.dart';
import '../../../../app/models/media_item.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/themes/app_spacing.dart';
import '../../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../../app/ui/widgets/media/app_media_items_view.dart';
import '../../../../app/ui/widgets/media/media_history_item_tile.dart';
import '../../../home/controller/home_controller.dart';
import '../../controller/download_history_controller.dart';
import '../widgets/download_history_filter_row.dart';
import '../widgets/download_history_search_field.dart';

// ============================
// 🧭 PAGE: HISTORIAL DE IMPORTS
// ============================
class DownloadHistoryPage extends GetView<DownloadHistoryController> {
  const DownloadHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actions = Get.find<MediaActionsController>();
    final home = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: ListenfyLogo(size: 28, color: scheme.primary),
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: AppGradientBackground(
        child: Obx(() {
          final vm = controller.state.value;
          final isGrid = controller.gridView.value;
          final dateRange = controller.dateFilterRange.value;

          final selectedItems = dateRange == 'byDay'
              ? controller.selectedDateItems()
              : controller.state.value.filteredItems;

          if (vm.status.isLoading && vm.groups.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          void openItem(MediaItem item, List<MediaItem> list) {
            final idx = list.indexWhere((e) => e.id == item.id);
            home.openMedia(item, idx < 0 ? 0 : idx, list);
          }

          void showActions(MediaItem item, List<MediaItem> list) {
            actions.showItemActions(
              context,
              item,
              onChanged: controller.loadHistory,
              onStartMultiSelect: () {
                final initialIndex = list.indexWhere((e) => e.id == item.id);
                Get.toNamed(
                  AppRoutes.homeSectionList,
                  arguments: {
                    'title': 'Historial de imports',
                    'items': list,
                    'onItemTap': (MediaItem tapped, int index) =>
                        home.openMedia(
                          tapped,
                          index < 0
                              ? (initialIndex < 0 ? 0 : initialIndex)
                              : index,
                          list,
                        ),
                    'onItemLongPress':
                        (
                          MediaItem target,
                          int _, {
                          VoidCallback? onStartMultiSelect,
                        }) => actions.showItemActions(
                          context,
                          target,
                          onChanged: controller.loadHistory,
                          onStartMultiSelect: onStartMultiSelect,
                        ),
                    'onDeleteSelected': (List<MediaItem> selected) async {
                      await actions.confirmDeleteMultiple(
                        context,
                        selected,
                        onChanged: controller.loadHistory,
                      );
                    },
                    'startInSelectionMode': true,
                    'initialSelectionItemId': item.id,
                  },
                );
              },
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadHistory,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              scrollCacheExtent: const ScrollCacheExtent.pixels(900),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Historial de imports',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: controller.toggleGridView,
                              style: IconButton.styleFrom(
                                backgroundColor: scheme.surfaceContainerHigh,
                              ),
                              icon: Icon(
                                isGrid
                                    ? Icons.grid_view_rounded
                                    : Icons.view_list_rounded,
                                color: scheme.primary,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DownloadHistorySearchField(
                          onChanged: controller.setQuery,
                          initialValue: vm.query,
                        ),
                        const SizedBox(height: 16),
                        DownloadHistoryFilterRow(
                          selected: vm.filter,
                          onSelect: controller.setFilter,
                        ),
                        const SizedBox(height: 16),
                        _BankingCalendarSection(controller: controller),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                ..._calendarSlivers(
                  context: context,
                  items: selectedItems,
                  isGrid: isGrid,
                  onTap: (item) => openItem(item, selectedItems),
                  onLongPress: (item) => showActions(item, selectedItems),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _calendarSlivers({
    required BuildContext context,
    required List<MediaItem> items,
    required bool isGrid,
    required ValueChanged<MediaItem> onTap,
    required ValueChanged<MediaItem> onLongPress,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  size: 56,
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  'No hay imports en este rango.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final groupedByDay = controller.itemsGroupedByDay(items);
    final sortedDays = groupedByDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final slivers = <Widget>[];
    for (var index = 0; index < sortedDays.length; index++) {
      final dayKey = sortedDays[index];
      final dayItems = groupedByDay[dayKey]!;
      final parts = dayKey.split('-');
      final dayDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            8,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              controller.dayLabelSimple(dayDate),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );

      if (isGrid) {
        slivers.add(
          AppMediaItemsSliver(
            items: dayItems,
            gridView: true,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              index == sortedDays.length - 1 ? AppSpacing.xl : 18,
            ),
            onTap: (item, _) => onTap(item),
            onLongPress: (item, _) => onLongPress(item),
            footerBuilder: (item, _) => controller.formatTime(item),
            fallbackIcon: Icons.cloud_download_rounded,
          ),
        );
      } else {
        slivers.add(
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              index == sortedDays.length - 1 ? AppSpacing.xl : 18,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, itemIndex) {
                final item = dayItems[itemIndex];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MediaHistoryItemTile(
                    item: item,
                    time: controller.formatTime(item),
                    onTap: () => onTap(item),
                    onLongPress: () => onLongPress(item),
                    fallbackIcon: Icons.cloud_download_rounded,
                  ),
                );
              }, childCount: dayItems.length),
            ),
          ),
        );
      }
    }

    return slivers;
  }
}

class _BankingCalendarSection extends StatelessWidget {
  const _BankingCalendarSection({required this.controller});

  final DownloadHistoryController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Filtro de fecha',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ),
        Obx(() {
          final currentFilter = controller.dateFilterRange.value;
          return DropdownButtonFormField<String>(
            initialValue: currentFilter,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.date_range_rounded, color: scheme.primary),
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: [
              const DropdownMenuItem(value: 'byDay', child: Text('Por día')),
              const DropdownMenuItem(value: 'all', child: Text('Todo')),
              const DropdownMenuItem(
                value: 'lastWeek',
                child: Text('Última semana'),
              ),
              const DropdownMenuItem(
                value: 'lastMonth',
                child: Text('Último mes'),
              ),
              DropdownMenuItem(
                value: 'custom',
                child: Text(
                  currentFilter == 'custom'
                      ? 'Personalizado (${controller.customDateRangeLabel()})'
                      : 'Personalizado',
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              if (value == 'custom') {
                _showDateRangePicker(context);
                return;
              }
              controller.filterByRange(value);
            },
          );
        }),
        const SizedBox(height: 16),
        // TableCalendar
        Obx(() {
          final selectedDate = controller.selectedDate.value;

          return TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: selectedDate,
            selectedDayPredicate: (day) => isSameDay(selectedDate, day),
            currentDay: DateTime.now(),
            weekendDays: const [6, 7],
            calendarFormat: CalendarFormat.month,
            availableGestures: AvailableGestures.horizontalSwipe,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle:
                  theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ) ??
                  TextStyle(fontWeight: FontWeight.w700),
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: scheme.primary,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: scheme.primary,
              ),
              headerPadding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Colors.transparent),
            ),
            calendarStyle: CalendarStyle(
              cellMargin: const EdgeInsets.all(4),
              cellPadding: EdgeInsets.zero,
              defaultDecoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              weekendDecoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              selectedDecoration: BoxDecoration(
                color: scheme.primary,
                border: Border.all(color: scheme.primary, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              todayDecoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.15),
                border: Border.all(color: scheme.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              outsideDecoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.1),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              defaultTextStyle: theme.textTheme.bodySmall ?? const TextStyle(),
              weekendTextStyle: theme.textTheme.bodySmall ?? const TextStyle(),
              selectedTextStyle:
                  theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ) ??
                  TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
              todayTextStyle:
                  theme.textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ) ??
                  TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
              outsideTextStyle:
                  theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ) ??
                  TextStyle(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekendStyle:
                  theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ) ??
                  TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
              weekdayStyle:
                  theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ) ??
                  TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              controller.selectDate(selectedDay);
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                final hasImports = controller.hasImportsOnDay(day);
                final count = controller.importCountForDay(day);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        '${day.day}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    if (hasImports)
                      Positioned(
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style:
                                theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ) ??
                                TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                  ],
                );
              },
              todayBuilder: (context, day, focusedDay) {
                final hasImports = controller.hasImportsOnDay(day);
                final count = controller.importCountForDay(day);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        '${day.day}',
                        style:
                            theme.textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ) ??
                            TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (hasImports)
                      Positioned(
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style:
                                theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ) ??
                                TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                  ],
                );
              },
              selectedBuilder: (context, day, focusedDay) {
                final hasImports = controller.hasImportsOnDay(day);
                final count = controller.importCountForDay(day);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        '${day.day}',
                        style:
                            theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ) ??
                            TextStyle(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (hasImports)
                      Positioned(
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.onPrimary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style:
                                theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ) ??
                                TextStyle(
                                  color: scheme.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        }),
      ],
    );
  }

  void _showDateRangePicker(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      currentDate: DateTime.now(),
      saveText: 'Aplicar',
      cancelText: 'Cancelar',
    );

    if (picked != null) {
      // Validar que no exceda 2.5 meses (75 días)
      final diff = picked.end.difference(picked.start).inDays;
      if (diff > 75) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Máximo 2.5 meses (75 días)'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      controller.setCustomDateRange(picked.start, picked.end);
    }
  }
}
