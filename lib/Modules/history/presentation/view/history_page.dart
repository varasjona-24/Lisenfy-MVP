import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listenfy/Modules/history/presentation/controller/history_controller.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import 'package:listenfy/app/controllers/media_actions_controller.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/ui/themes/app_spacing.dart';
import 'package:listenfy/app/ui/widgets/layout/app_gradient_background.dart';

class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actions = Get.find<MediaActionsController>();
    final home = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Historial'),
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
                'Aún no hay historial.',
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Historial',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }

                final group = vm.groups[index - 1];
                return _HistoryGroupSection(
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
                  ),
                  timeBuilder: controller.formatTime,
                );
              },
            ),
          );
        }),
      ),
    );
  }
}

class _HistoryGroupSection extends StatelessWidget {
  const _HistoryGroupSection({
    required this.label,
    required this.items,
    required this.onTap,
    required this.onLongPress,
    required this.timeBuilder,
  });

  final String label;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onTap;
  final ValueChanged<MediaItem> onLongPress;
  final String Function(MediaItem item) timeBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 6),
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _HistoryItemTile(
              item: item,
              time: timeBuilder(item),
              onTap: () => onTap(item),
              onLongPress: () => onLongPress(item),
            ),
          );
        }),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _HistoryItemTile extends StatelessWidget {
  const _HistoryItemTile({
    required this.item,
    required this.time,
    required this.onTap,
    required this.onLongPress,
  });

  final MediaItem item;
  final String time;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _Thumb(
              path: item.thumbnailLocalPath,
              url: item.thumbnail,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.path, this.url});

  final String? path;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLocal = path != null && path!.trim().isNotEmpty;
    final hasUrl = url != null && url!.trim().isNotEmpty;

    ImageProvider? provider;
    if (hasLocal) {
      provider = FileImage(File(path!.trim()));
    } else if (hasUrl) {
      provider = NetworkImage(url!.trim());
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 54,
        height: 54,
        color: scheme.surfaceContainerHigh,
        child: provider != null
            ? Image(image: provider, fit: BoxFit.cover)
            : Icon(Icons.music_note_rounded, color: scheme.primary),
      ),
    );
  }
}

