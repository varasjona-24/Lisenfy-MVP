import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import '../controller/downloads_controller.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import 'widgets/downloads_pill.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/controllers/media_actions_controller.dart';

class DownloadsPage extends GetView<DownloadsController> {
  const DownloadsPage({super.key});

  // ============================
  // 🎨 UI
  // ============================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final actions = Get.find<MediaActionsController>();

    final barBg = Color.alphaBlend(
      scheme.primary.withOpacity(isDark ? 0.24 : 0.28),
      scheme.surface,
    );

    final HomeController home = Get.find<HomeController>();
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
        }

        final needsLocalDialog =
            (argOpenLocalImport &&
                controller.localImportArgConsumed.value == false) ||
            shouldOpenLocalImport;

        if (needsLocalDialog && controller.localImportDialogOpen.value == false) {
          controller.localImportArgConsumed.value = true;
          controller.openLocalImportRequested.value = false;
          controller.localImportDialogOpen.value = true;
          await DownloadsPill.showLocalImportDialog(context, controller);
          controller.localImportDialogOpen.value = false;
        }
      });

      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppTopBar(
          title: ListenfyLogo(size: 28, color: scheme.primary),
                  ),

        // ============================
        // 📄 LISTA
        // ============================
        body: AppGradientBackground(
          child: Stack(
            children: [
            Positioned.fill(
              child: Obx(() {
                if (controller.isLoading.value) {
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
                    behavior: const _NoGlowScrollBehavior(),
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
                          _header(theme: theme, context: context),
                          const SizedBox(height: AppSpacing.lg),

                          // 📥 Pill de Imports (Online + Dispositivo)
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
                            Column(
                              children: List.generate(
                                list.length,
                                (i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _DownloadTile(
                                    item: list[i],
                                    onPlay: (item) =>
                                        _playItem(mode, list, item),
                                    onHold: (item) => actions.showItemActions(
                                          context,
                                          item,
                                          onChanged: controller.load,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),

            _bottomNav(
              barBg: barBg,
              scheme: scheme,
              isDark: isDark,
              home: home,
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

    Get.toNamed(
      route,
      arguments: {
        'queue': queue,
        'index': idx < 0 ? 0 : idx,
      },
    );
  }

  // ============================
  // UI SECTIONS
  // ============================
  Widget _header({required ThemeData theme, required BuildContext context}) {
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imports',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Archivos importados en tu dispositivo',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Get.toNamed(AppRoutes.downloadsHistory),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant.withAlpha(80)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historial de imports',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ver todo lo que descargaste',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomNav({
    required Color barBg,
    required ColorScheme scheme,
    required bool isDark,
    required HomeController home,
  }) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: barBg,
          border: Border(
            top: BorderSide(
              color: scheme.primary.withOpacity(isDark ? 0.22 : 0.18),
              width: 56,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
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
      ),
    );
  }
}

// ============================================================================
// Tile
// ============================================================================

class _DownloadTile extends StatefulWidget {
  final MediaItem item;
  final void Function(MediaItem item) onPlay;
  final void Function(MediaItem item) onHold;

  const _DownloadTile({
    required this.item,
    required this.onPlay,
    required this.onHold,
  });

  @override
  State<_DownloadTile> createState() => _DownloadTileState();
}

class _DownloadTileState extends State<_DownloadTile> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = widget.item.variants.isNotEmpty
        ? widget.item.variants.first
        : null;

    final isVideo = v?.kind == MediaVariantKind.video;
    final icon = isVideo ? Icons.videocam_rounded : Icons.music_note_rounded;

    final subtitle = widget.item.displaySubtitle;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => widget.onPlay(widget.item),
        leading: Icon(icon),
        title: Text(
          widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'Más opciones',
          onPressed: () => widget.onHold(widget.item),
        ),
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
