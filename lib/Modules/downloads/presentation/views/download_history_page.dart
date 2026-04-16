import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/controllers/media_actions_controller.dart';
import '../../../../app/models/media_item.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/themes/app_spacing.dart';
import '../../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../../app/ui/widgets/media/media_history_group_section.dart';
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

          if (vm.status.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.groups.isEmpty) {
            return Center(
              child: Text(
                'Aún no hay imports.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.loadHistory,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              itemCount: vm.groups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Historial de imports',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: controller.gridView.value
                                  ? 'Ver como lista'
                                  : 'Ver como cuadrícula',
                              onPressed: controller.toggleGridView,
                              icon: Icon(
                                controller.gridView.value
                                    ? Icons.view_list_rounded
                                    : Icons.grid_view_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DownloadHistoryFilterRow(
                        selected: vm.filter,
                        onSelect: controller.setFilter,
                      ),
                      const SizedBox(height: 10),
                      DownloadHistorySearchField(
                        onChanged: controller.setQuery,
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                }

                final group = vm.groups[index - 1];
                return MediaHistoryGroupSection(
                  label: group.label,
                  items: group.items,
                  onTap: (item) {
                    final list = vm.filteredItems.toList();
                    final idx = list.indexWhere((e) => e.id == item.id);
                    home.openMedia(item, idx < 0 ? 0 : idx, list);
                  },
                  onLongPress: (item) => actions.showItemActions(
                    context,
                    item,
                    onChanged: controller.loadHistory,
                    onStartMultiSelect: () {
                      final list = vm.filteredItems.toList(growable: false);
                      final initialIndex = list.indexWhere(
                        (e) => e.id == item.id,
                      );
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
                  ),
                  timeBuilder: controller.formatTime,
                  fallbackIcon: Icons.cloud_download_rounded,
                  gridMode: controller.gridView.value,
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
