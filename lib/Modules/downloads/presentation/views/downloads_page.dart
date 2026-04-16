import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import 'package:listenfy/app/controllers/media_actions_controller.dart';
import 'package:listenfy/app/models/media_item.dart';
import 'package:listenfy/app/routes/app_routes.dart';
import 'package:listenfy/app/ui/themes/app_spacing.dart';
import 'package:listenfy/app/ui/widgets/branding/listenfy_logo.dart';
import 'package:listenfy/app/ui/widgets/layout/app_gradient_background.dart';
import 'package:listenfy/app/ui/widgets/navigation/app_bottom_nav.dart';
import 'package:listenfy/app/ui/widgets/navigation/app_top_bar.dart';

import '../../controller/downloads_controller.dart';
import '../widgets/download_tile.dart';
import '../widgets/downloads_header.dart';
import '../widgets/downloads_pill.dart';
import '../widgets/no_glow_scroll_behavior.dart';

class DownloadsPage extends GetView<DownloadsController> {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actions = Get.find<MediaActionsController>();

    final home = Get.find<HomeController>();
    final argUrl = (Get.arguments is Map)
        ? (Get.arguments as Map)['sharedUrl']?.toString().trim()
        : null;
    final argOpenLocalImport = (Get.arguments is Map)
        ? ((Get.arguments as Map)['openLocalImport'] == true)
        : false;

    return Obx(() {
      final mode = home.mode.value;
      final shared = controller.sharedUrl.value;
      final dialogOpen = controller.shareDialogOpen.value;
      final shouldOpenLocalImport = controller.openLocalImportRequested.value;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if ((controller.sharedUrl.value.isEmpty) &&
            (argUrl?.isNotEmpty ?? false) &&
            controller.sharedArgConsumed.value == false) {
          controller.sharedUrl.value = argUrl ?? '';
          controller.sharedArgConsumed.value = true;
        }

        if (shared.isNotEmpty && dialogOpen == false) {
          controller.shareDialogOpen.value = true;
          final url = shared;
          controller.sharedUrl.value = '';
          await DownloadsPill.showImportUrlDialog(
            context,
            controller,
            initialUrl: url,
            clearSharedOnClose: true,
          );
          controller.shareDialogOpen.value = false;
          if (!context.mounted) return;
        }

        final needsLocalDialog =
            (argOpenLocalImport &&
                controller.localImportArgConsumed.value == false) ||
            shouldOpenLocalImport;

        if (needsLocalDialog &&
            controller.localImportDialogOpen.value == false) {
          controller.localImportArgConsumed.value = true;
          controller.openLocalImportRequested.value = false;
          controller.localImportDialogOpen.value = true;
          if (!context.mounted) return;
          await DownloadsPill.showLocalImportDialog(context, controller);
          controller.localImportDialogOpen.value = false;
        }
      });

      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppTopBar(title: ListenfyLogo(size: 28, color: scheme.primary)),
        body: AppGradientBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: Obx(() {
                  if (controller.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final list = controller.downloads
                      .where(
                        (e) => mode == HomeMode.audio
                            ? e.hasAudioLocal
                            : e.hasVideoLocal,
                      )
                      .toList();

                  return RefreshIndicator(
                    onRefresh: controller.load,
                    child: ScrollConfiguration(
                      behavior: const NoGlowScrollBehavior(),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(
                          top: AppSpacing.md,
                          bottom: kBottomNavigationBarHeight + 18,
                          left: AppSpacing.md,
                          right: AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const DownloadsHeader(),
                            const SizedBox(height: AppSpacing.lg),
                            const DownloadsPill(),
                            const SizedBox(height: AppSpacing.lg),
                            if (list.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  child: Text(
                                    'No hay imports aún.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              )
                            else
                              _buildListResults(
                                theme,
                                mode,
                                list,
                                actions,
                                context,
                              ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomNav(
                  currentIndex: 3,
                  onTap: (index) {
                    switch (index) {
                      case 0:
                        home.enterHome();
                        break;
                      case 1:
                        home.goToPlaylists();
                        break;
                      case 2:
                        home.goToArtists();
                        break;
                      case 3:
                        home.goToDownloads();
                        break;
                      case 4:
                        home.goToSources();
                        break;
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _playItem(HomeMode mode, List<MediaItem> queue, MediaItem item) {
    final idx = queue.indexWhere((e) => e.id == item.id);
    final route = mode == HomeMode.audio
        ? AppRoutes.audioPlayer
        : AppRoutes.videoPlayer;

    Get.toNamed(route, arguments: {'queue': queue, 'index': idx < 0 ? 0 : idx});
  }

  Widget _buildListResults(
    ThemeData theme,
    HomeMode mode,
    List<MediaItem> list,
    MediaActionsController actions,
    BuildContext context,
  ) {
    return Column(
      children: List.generate(
        list.length,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DownloadTile(
            item: list[i],
            onPlay: (item) => _playItem(mode, list, item),
            onHold: (item) => actions.showItemActions(
              context,
              item,
              onChanged: controller.load,
              onStartMultiSelect: () {
                Get.toNamed(
                  AppRoutes.homeSectionList,
                  arguments: {
                    'title': 'Imports',
                    'items': list,
                    'onItemTap': (MediaItem tapped, int index) =>
                        _playItem(mode, list, tapped),
                    'onItemLongPress':
                        (
                          MediaItem target,
                          int _, {
                          VoidCallback? onStartMultiSelect,
                        }) => actions.showItemActions(
                          context,
                          target,
                          onChanged: controller.load,
                          onStartMultiSelect: onStartMultiSelect,
                        ),
                    'onDeleteSelected': (List<MediaItem> selected) async {
                      await actions.confirmDeleteMultiple(
                        context,
                        selected,
                        onChanged: controller.load,
                      );
                    },
                    'startInSelectionMode': true,
                    'initialSelectionItemId': item.id,
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
