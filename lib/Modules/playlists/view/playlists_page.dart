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
                                    _header(theme),
                                    const SizedBox(height: 10),
                                    _summaryRow(
                                      theme: theme,
                                      total: total,
                                      onAdd: () => _createPlaylist(context),
                                    ),
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

  Widget _header(ThemeData theme) {
    return Text(
      tr('playlists.title'),
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _summaryRow({
    required ThemeData theme,
    required int total,
    required VoidCallback onAdd,
  }) {
    return Row(
      children: [
        Text(
          tr('playlists.summary', args: ['$total']),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: tr('playlists.new'),
          onPressed: onAdd,
        ),
      ],
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
          child: Text(
            tr('playlists.empty'),
            style: Get.textTheme.bodyMedium?.copyWith(
              color: Get.theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      sliver: SliverList.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          final playlist = list[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlaylistTile(
              playlist: playlist,
              resolveItems: controller.resolvePlaylistItems,
              onOpen: () => Get.toNamed(
                AppRoutes.playlistDetail,
                arguments: {'playlistId': playlist.id, 'isSmart': false},
              ),
              onMenu: () => _openPlaylistActions(Get.context!, playlist),
            ),
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

  void _playNext(List<MediaItem> items) {
    if (items.isEmpty) return;
    if (Get.isRegistered<AudioPlayerController>()) {
      final audio = Get.find<AudioPlayerController>();
      audio.insertNext(items);
      Get.snackbar(tr('playlists.queue'), tr('playlists.queued_next'));
      return;
    }
    Get.snackbar(tr('playlists.queue'), tr('playlists.open_player_required'));
  }

  void _addToQueue(List<MediaItem> items) {
    if (items.isEmpty) return;
    if (Get.isRegistered<AudioPlayerController>()) {
      final audio = Get.find<AudioPlayerController>();
      audio.addToQueue(items);
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
    final localPath = playlist.coverLocalPath?.trim();
    final localExists =
        localPath != null &&
        localPath.isNotEmpty &&
        File(localPath).existsSync();
    final thumb = localExists
        ? localPath
        : (playlist.coverUrl?.trim().isNotEmpty == true
              ? playlist.coverUrl
              : (playlist.coverCleared
                    ? null
                    : (items.isNotEmpty
                          ? items.first.effectiveThumbnail
                          : null)));

    ImageProvider? provider;
    if (thumb != null && thumb.isNotEmpty) {
      provider = thumb.startsWith('http')
          ? NetworkImage(thumb)
          : FileImage(File(thumb));
    }

    return Card(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onOpen,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 54,
            height: 54,
            color: scheme.surfaceContainerHighest,
            child: provider != null
                ? Image(image: provider, fit: BoxFit.cover)
                : Icon(
                    Icons.music_note_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
          ),
        ),
        title: Text(
          playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          tr(
            items.length == 1 ? 'common.songs.one' : 'common.songs.other',
            args: ['${items.length}'],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: tr('playlists.options'),
          onPressed: onMenu,
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
