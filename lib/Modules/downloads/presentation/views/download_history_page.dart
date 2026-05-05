import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../app/controllers/media_actions_controller.dart';
import '../../../../app/models/media_item.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/themes/app_spacing.dart';
import '../../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../../app/ui/widgets/media/media_history_group_section.dart';
import '../../../../app/ui/widgets/media/media_history_item_tile.dart';
import '../../../../app/ui/widgets/media/media_item_grid.dart';
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
      backgroundColor: Colors.transparent,
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
          final isCalendar = controller.calendarMode.value;
          final dateRange = controller.dateFilterRange.value;

          final selectedDayItems = isCalendar
              ? (dateRange == 'all'
                    ? controller.selectedDateItems()
                    : controller.state.value.filteredItems)
              : const <MediaItem>[];

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
                              onPressed: controller.toggleCalendarMode,
                              style: IconButton.styleFrom(
                                backgroundColor: scheme.surfaceContainerHigh,
                              ),
                              icon: Icon(
                                isCalendar
                                    ? Icons.calendar_month_rounded
                                    : Icons.view_agenda_rounded,
                                color: scheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
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
                        if (isCalendar) ...[
                          const SizedBox(height: 16),
                          _BankingCalendarSection(controller: controller),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                if (isCalendar)
                  ..._calendarSlivers(
                    context: context,
                    items: selectedDayItems,
                    isGrid: isGrid,
                    onTap: (item) => openItem(item, selectedDayItems),
                    onLongPress: (item) => showActions(item, selectedDayItems),
                  )
                else if (vm.groups.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 64,
                            color: scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron registros.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final group = vm.groups[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: MediaHistoryGroupSection(
                            group: group,
                            expandedSections: vm.expandedSections,
                            onToggle: controller.toggleSection,
                            onTap: (item) {
                              final list = vm.filteredItems.toList();
                              openItem(item, list);
                            },
                            onLongPress: (item) => showActions(
                              item,
                              vm.filteredItems.toList(growable: false),
                            ),
                            timeBuilder: controller.formatTime,
                            fallbackIcon: Icons.cloud_download_rounded,
                            gridMode: isGrid,
                          ),
                        );
                      }, childCount: vm.groups.length),
                    ),
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

    final groupedByDay = controller.itemsGroupedByDay();
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
          MediaItemSliverGrid(
            items: dayItems,
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
        // Date Range Filter Buttons
        Obx(() {
          final currentFilter = controller.dateFilterRange.value;
          return Wrap(
            spacing: 8,
            children: [
              _FilterButton(
                label: 'Todo',
                isActive: currentFilter == 'all',
                onPressed: () => controller.filterByRange('all'),
              ),
              _FilterButton(
                label: 'Última semana',
                isActive: currentFilter == 'lastWeek',
                onPressed: () => controller.filterByRange('lastWeek'),
              ),
              _FilterButton(
                label: 'Último mes',
                isActive: currentFilter == 'lastMonth',
                onPressed: () => controller.filterByRange('lastMonth'),
              ),
              _FilterButton(
                label: 'Personalizado',
                isActive: currentFilter == 'custom',
                onPressed: () => _showDateRangePicker(context),
              ),
            ],
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? null
                : Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                    width: 1,
                  ),
          ),
          child: Text(
            label,
            style:
                theme.textTheme.labelSmall?.copyWith(
                  color: isActive ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ) ??
                TextStyle(
                  color: isActive ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
