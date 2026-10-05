import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/data/repo/media_repository.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/ui/themes/app_spacing.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';

import '../../../app/ui/widgets/dialogs/image_search_dialog.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../app/models/media_item.dart';

import '../../edit/controller/edit_entity_controller.dart';
import '../../edit/view/desktop_image_cropper_dialog.dart';

import '../../Home/Controller/home_controller.dart';
import '../../player/audio/controller/audio_player_controller.dart';
import '../controller/playlists_controller.dart';
import '../domain/playlist.dart';

class PlaylistsPage extends GetView<PlaylistsController> {
  const PlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final home = Get.find<HomeController>();

    return Obx(() {
      final list = controller.playlists;
      final total = list.length;
      final totalSongs = _totalSongs(list);
      final featured = _featuredPlaylist(list);

      return Scaffold(
        extendBody: true,
        appBar: AppTopBar(title: ListenfyLogo(size: 28, color: scheme.primary)),
        body: AppGradientBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: controller.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: controller.load,
                        child: ScrollConfiguration(
                          behavior: const _NoGlowScrollBehavior(),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.md,
                                  AppSpacing.md,
                                  AppSpacing.md,
                                  AppSpacing.lg,
                                ),
                                sliver: SliverList.list(
                                  children: [
                                    _libraryHeader(
                                      theme: theme,
                                      total: total,
                                      totalSongs: totalSongs,
                                      onAdd: () => _createPlaylist(context),
                                    ),
                                    if (featured != null) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      _FeaturedPlaylistCard(
                                        playlist: featured,
                                        resolveItems:
                                            controller.resolvePlaylistItems,
                                        onOpen: () => Get.toNamed(
                                          AppRoutes.playlistDetail,
                                          arguments: {
                                            'playlistId': featured.id,
                                            'isSmart': false,
                                          },
                                        ),
                                        onPlay: () => _playPlaylist(
                                          controller.resolvePlaylistItems(
                                            featured,
                                          ),
                                        ),
                                        onMenu: () => _openPlaylistActions(
                                          Get.context!,
                                          featured,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: AppSpacing.lg),
                                    _myPlaylistsHeader(theme, list.length),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                              _myPlaylistsSliver(list),
                              const SliverToBoxAdapter(
                                child: SizedBox(
                                  height: kBottomNavigationBarHeight + 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomNav(
                  currentIndex: 1,
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
                        home.goToAtlas();
                        break;
                      case 4:
                        home.goToDownloads();
                        break;
                      case 5:
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

  int _totalSongs(List<Playlist> playlists) {
    var total = 0;
    for (final playlist in playlists) {
      total += controller.resolvePlaylistItems(playlist).length;
    }
    return total;
  }

  Playlist? _featuredPlaylist(List<Playlist> playlists) {
    if (playlists.isEmpty) return null;
    Playlist? best;
    var bestCount = -1;
    for (final playlist in playlists) {
      final count = controller.resolvePlaylistItems(playlist).length;
      if (count > bestCount) {
        best = playlist;
        bestCount = count;
      }
    }
    return best;
  }

  Widget _libraryHeader({
    required ThemeData theme,
    required int total,
    required int totalSongs,
    required VoidCallback onAdd,
  }) {
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('playlists.title'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            tr('playlists.library_subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.46),
          ),
          const SizedBox(height: 14),
          _HeaderActionPanel(
            total: total,
            totalSongs: totalSongs,
            onAdd: onAdd,
          ),
        ],
      ),
    );
  }

  Widget _myPlaylistsHeader(ThemeData theme, int count) {
    return Text(
      tr('playlists.mine', args: ['$count']),
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _myPlaylistsSliver(List<Playlist> list) {
    if (list.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        sliver: SliverToBoxAdapter(
          child: _EmptyPlaylistsCard(
            onCreate: () => _createPlaylist(Get.context!),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.crossAxisExtent >= 720;
          if (!isWide) {
            return SliverGrid.builder(
              itemCount: list.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 198,
                mainAxisSpacing: 24,
                crossAxisSpacing: 28,
              ),
              itemBuilder: (context, index) {
                final playlist = list[index];
                return _PlaylistTile(
                  playlist: playlist,
                  resolveItems: controller.resolvePlaylistItems,
                  onOpen: () => Get.toNamed(
                    AppRoutes.playlistDetail,
                    arguments: {'playlistId': playlist.id, 'isSmart': false},
                  ),
                  onMenu: () => _openPlaylistActions(Get.context!, playlist),
                );
              },
            );
          }

          return SliverGrid.builder(
            itemCount: list.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 380,
              mainAxisExtent: 132,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final playlist = list[index];
              return _PlaylistTile(
                playlist: playlist,
                resolveItems: controller.resolvePlaylistItems,
                onOpen: () => Get.toNamed(
                  AppRoutes.playlistDetail,
                  arguments: {'playlistId': playlist.id, 'isSmart': false},
                ),
                onMenu: () => _openPlaylistActions(Get.context!, playlist),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    await Get.toNamed(
      AppRoutes.createEntity,
      arguments: const CreateEntityArgs.playlist(storageId: 'pl_create'),
    );
  }

  Future<void> _openPlaylistActions(
    BuildContext context,
    Playlist playlist,
  ) async {
    final items = controller.resolvePlaylistItems(playlist);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded),
                title: Text(tr('playlists.play')),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _playPlaylist(items);
                },
              ),
              ListTile(
                leading: const Icon(Icons.skip_next_rounded),
                title: Text(tr('playlists.play_next')),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _playNext(items);
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_music_rounded),
                title: Text(tr('playlists.add_queue')),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _addToQueue(items);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(tr('common.edit')),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Get.toNamed(
                    AppRoutes.editEntity,
                    arguments: EditEntityArgs.playlist(playlist),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(tr('playlists.delete_playlist')),
                textColor: Theme.of(ctx).colorScheme.error,
                iconColor: Theme.of(ctx).colorScheme.error,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDelete(context, playlist);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _playPlaylist(List<MediaItem> items) {
    if (items.isEmpty) return;
    Get.toNamed(AppRoutes.audioPlayer, arguments: {'queue': items, 'index': 0});
  }

  Future<void> _playNext(List<MediaItem> items) async {
    if (items.isEmpty) return;
    if (Get.isRegistered<AudioPlayerController>()) {
      final audio = Get.find<AudioPlayerController>();
      await audio.insertNext(items);
      Get.snackbar(tr('playlists.queue'), tr('playlists.queued_next'));
      return;
    }
    Get.snackbar(tr('playlists.queue'), tr('playlists.open_player_required'));
  }

  Future<void> _addToQueue(List<MediaItem> items) async {
    if (items.isEmpty) return;
    if (Get.isRegistered<AudioPlayerController>()) {
      final audio = Get.find<AudioPlayerController>();
      await audio.addToQueue(items);
      Get.snackbar(tr('playlists.queue'), tr('playlists.queued'));
      return;
    }
    Get.snackbar(tr('playlists.queue'), tr('playlists.open_player_required'));
  }

  // ignore: unused_element
  Future<void> _renamePlaylist(BuildContext context, Playlist playlist) async {
    String name = playlist.name;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('playlists.rename')),
        content: TextFormField(
          initialValue: playlist.name,
          onChanged: (value) => name = value,
          decoration: InputDecoration(hintText: tr('playlists.new_name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('common.save')),
          ),
        ],
      ),
    );

    if (ok == true) {
      await controller.renamePlaylist(playlist.id, name);
    }
  }

  // ignore: unused_element
  Future<void> _changeCover(BuildContext context, Playlist playlist) async {
    final repo = Get.find<MediaRepository>();
    final urlCtrl = TextEditingController(text: playlist.coverUrl ?? '');
    String? localPath = playlist.coverLocalPath;
    bool confirmed = false;

    Future<void> pickLocal() async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
      final file = (res != null && res.files.isNotEmpty)
          ? res.files.first
          : null;
      if (file?.path == null) return;
      final prevLocal = localPath;

      final cropped = await _cropToSquare(file!.path!);
      if (cropped == null || cropped.trim().isEmpty) return;

      final persisted = await _persistCroppedCover(playlist.id, cropped);
      if (persisted == null || persisted.trim().isEmpty) return;

      localPath = persisted;
      urlCtrl.text = '';

      if (prevLocal != null &&
          prevLocal.trim().isNotEmpty &&
          prevLocal.trim() != persisted.trim()) {
        await _deleteFile(prevLocal);
      }
    }

    Future<void> pickWeb() async {
      final pickedUrl = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ImageSearchDialog(initialQuery: playlist.name),
      );
      final cleaned = (pickedUrl ?? '').trim();
      if (cleaned.isEmpty) return;

      final prevLocal = localPath;

      String? baseLocal;
      try {
        baseLocal = await repo.cacheThumbnailForItem(
          itemId: '${playlist.id}-raw',
          thumbnailUrl: cleaned,
        );
      } catch (_) {
        baseLocal = null;
      }
      if (baseLocal == null || baseLocal.trim().isEmpty) return;

      final cropped = await _cropToSquare(baseLocal);
      if (cropped == null || cropped.trim().isEmpty) {
        await _deleteFile(baseLocal);
        return;
      }

      final persisted = await _persistCroppedCover(playlist.id, cropped);
      if (persisted == null || persisted.trim().isEmpty) return;

      if (baseLocal != persisted) {
        await _deleteFile(baseLocal);
      }

      localPath = persisted;
      urlCtrl.text = '';

      if (prevLocal != null &&
          prevLocal.trim().isNotEmpty &&
          prevLocal.trim() != persisted.trim()) {
        await _deleteFile(prevLocal);
      }
    }

    Future<void> deleteCurrentCover() async {
      await _deleteFile(localPath);
      localPath = null;
      urlCtrl.text = '';
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('playlists.change_cover')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: tr('playlists.selected_web_image'),
              ),
              onTap: () async {
                await pickWeb();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await pickLocal();
                    },
                    icon: const Icon(Icons.folder_open_rounded),
                    label: Text(tr('playlists.choose_file')),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await pickWeb();
                  },
                  icon: const Icon(Icons.public_rounded),
                  label: Text(tr('common.search')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: deleteCurrentCover,
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text(tr('playlists.clear_cover')),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              confirmed = true;
              Navigator.of(ctx).pop();
            },
            child: Text(tr('common.save')),
          ),
        ],
      ),
    );

    if (!confirmed) {
      urlCtrl.dispose();
      return;
    }

    final url = urlCtrl.text.trim();
    final hasLocal = localPath?.trim().isNotEmpty == true;
    final cleared = !hasLocal && url.isEmpty;
    await controller.updateCover(
      playlist.id,
      coverUrl: hasLocal ? null : (url.isNotEmpty ? url : null),
      coverLocalPath: hasLocal ? localPath : null,
      coverCleared: cleared,
    );
    urlCtrl.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, Playlist playlist) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('playlists.delete_title')),
        content: Text(tr('playlists.delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('common.cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('common.delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.deletePlaylist(playlist.id);
    }
  }

  Future<String?> _cropToSquare(String sourcePath) async {
    if (!kIsWeb &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      return Get.dialog<String>(
        DesktopImageCropperDialog(sourcePath: sourcePath, ratioX: 1, ratioY: 1),
        barrierDismissible: false,
      );
    }

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: tr('playlists.crop'),
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: tr('playlists.crop'),
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      return cropped?.path;
    } catch (_) {
      return sourcePath;
    }
  }

  Future<String?> _persistCroppedCover(String id, String croppedPath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'downloads', 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final extension = p.extension(croppedPath).toLowerCase() == '.png'
          ? '.png'
          : '.jpg';
      final targetPath = p.join(coversDir.path, '$id-crop$extension');
      final src = File(croppedPath);
      if (!await src.exists()) return null;

      final out = await src.copy(targetPath);

      final sourceInsideAppDir = p.isWithin(appDir.path, src.path);
      if (croppedPath != targetPath && sourceInsideAppDir) {
        try {
          await src.delete();
        } catch (_) {}
      }

      return out.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteFile(String? path) async {
    final pth = path?.trim();
    if (pth == null || pth.isEmpty) return;
    try {
      final f = File(pth);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.onOpen,
    required this.onMenu,
    required this.resolveItems,
  });

  final Playlist playlist;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  final List<MediaItem> Function(Playlist) resolveItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final items = resolveItems(playlist);
    final covers = _playlistCovers(playlist, items, limit: 4);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 240;
        final songCount = tr(
          items.length == 1 ? 'common.songs.one' : 'common.songs.other',
          args: ['${items.length}'],
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              padding: EdgeInsets.all(compact ? 8 : 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SizedBox.expand(
                            child: _PlaylistCoverMosaic(
                              covers: covers,
                              size: double.infinity,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    playlist.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    songCount,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 20,
                                icon: const Icon(Icons.more_vert_rounded),
                                tooltip: tr('playlists.options'),
                                onPressed: onMenu,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _PlaylistCoverMosaic(covers: covers, size: 74),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playlist.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                songCount,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded),
                          tooltip: tr('playlists.options'),
                          onPressed: onMenu,
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _FeaturedPlaylistCard extends StatelessWidget {
  const _FeaturedPlaylistCard({
    required this.playlist,
    required this.resolveItems,
    required this.onOpen,
    required this.onPlay,
    required this.onMenu,
  });

  final Playlist playlist;
  final List<MediaItem> Function(Playlist) resolveItems;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = resolveItems(playlist);
    final covers = _playlistCovers(playlist, items, limit: 4);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              _PlaylistCoverMosaic(covers: covers, size: 112),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('playlists.featured'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      playlist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      tr(
                        items.length == 1
                            ? 'common.songs.one'
                            : 'common.songs.other',
                        args: ['${items.length}'],
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: items.isEmpty ? null : onPlay,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(tr('playlists.play')),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: onMenu,
                          icon: const Icon(Icons.more_horiz_rounded),
                          tooltip: tr('playlists.options'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistCoverMosaic extends StatelessWidget {
  const _PlaylistCoverMosaic({required this.covers, required this.size});

  final List<ImageProvider> covers;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = size.isFinite && size >= 100 ? 20.0 : 16.0;
    final iconSize = size.isFinite ? size * 0.38 : 42.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size.isFinite ? size : double.infinity,
        height: size.isFinite ? size : double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: 0.24),
                scheme.tertiary.withValues(alpha: 0.14),
                scheme.surfaceContainerHighest,
              ],
            ),
          ),
          child: covers.isEmpty
              ? Icon(
                  Icons.queue_music_rounded,
                  color: scheme.onSurfaceVariant,
                  size: iconSize,
                )
              : covers.length == 1
              ? Image(image: covers.first, fit: BoxFit.cover)
              : GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                  ),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    final provider = covers[index % covers.length];
                    return Image(image: provider, fit: BoxFit.cover);
                  },
                ),
        ),
      ),
    );
  }
}

class _HeaderActionPanel extends StatelessWidget {
  const _HeaderActionPanel({
    required this.total,
    required this.totalSongs,
    required this.onAdd,
  });

  final int total;
  final int totalSongs;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _HeaderInfoMetric(
                  icon: Icons.queue_music_rounded,
                  value: total,
                  label: tr('playlists.metric_lists'),
                ),
              ),
              Expanded(
                child: _HeaderInfoMetric(
                  icon: Icons.music_note_rounded,
                  value: totalSongs,
                  label: tr('playlists.metric_songs'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(tr('playlists.new')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderInfoMetric extends StatelessWidget {
  const _HeaderInfoMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: scheme.onSurface),
        const SizedBox(height: 6),
        Text(
          NumberFormat.compact(
            locale: context.locale.toLanguageTag(),
          ).format(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyPlaylistsCard extends StatelessWidget {
  const _EmptyPlaylistsCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.playlist_add_rounded, color: scheme.primary, size: 34),
          const SizedBox(height: 10),
          Text(
            tr('playlists.empty_title'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            tr('playlists.empty'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(tr('playlists.new')),
          ),
        ],
      ),
    );
  }
}

List<ImageProvider> _playlistCovers(
  Playlist playlist,
  List<MediaItem> items, {
  required int limit,
}) {
  final explicit = _playlistExplicitCover(playlist);
  if (explicit != null) return <ImageProvider>[explicit];

  final covers = <ImageProvider>[];
  if (!playlist.coverCleared) {
    for (final item in items) {
      final thumb = item.effectiveThumbnail?.trim() ?? '';
      if (thumb.isEmpty) continue;
      try {
        covers.add(_playlistImageProvider(thumb));
      } catch (_) {}
      if (covers.length >= limit) break;
    }
  }

  return covers.take(limit).toList(growable: false);
}

ImageProvider? _playlistExplicitCover(Playlist playlist) {
  final localPath = playlist.coverLocalPath?.trim();
  final isAssetCover = localPath?.startsWith('assets/') == true;
  final localExists =
      localPath != null &&
      localPath.isNotEmpty &&
      (isAssetCover || File(localPath).existsSync());
  if (localExists) return _playlistImageProvider(localPath);

  final url = playlist.coverUrl?.trim();
  if (url != null && url.isNotEmpty) return _playlistImageProvider(url);
  return null;
}

ImageProvider _playlistImageProvider(String raw) {
  final value = raw.trim();
  if (value.startsWith('assets/')) return AssetImage(value);
  if (value.startsWith('http')) return NetworkImage(value);
  return FileImage(File(value));
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
