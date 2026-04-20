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
          final isGrid = controller.gridView.value;

          if (vm.status.isLoading && vm.groups.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: controller.loadHistory,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
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
                                  letterSpacing: -0.5,
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
                        ),
                        const SizedBox(height: 16),
                        DownloadHistoryFilterRow(
                          selected: vm.filter,
                          onSelect: controller.setFilter,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                if (vm.groups.isEmpty)
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
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final group = vm.groups[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: MediaHistoryGroupSection(
                              group: group,
                              expandedSections: vm.expandedSections,
                              onToggle: controller.toggleSection,
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
                              gridMode: isGrid,
                            ),
                          );
                        },
                        childCount: vm.groups.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
