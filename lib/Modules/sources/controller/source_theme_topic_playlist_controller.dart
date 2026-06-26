import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/data/repo/media_repository.dart';
import '../../../app/models/media_item.dart';
import '../domain/source_origin.dart';
import '../domain/source_theme.dart';
import '../domain/source_theme_topic_playlist.dart';
import 'sources_controller.dart';
import '../../../app/ui/widgets/dialogs/image_search_dialog.dart';

class SourceThemeTopicPlaylistController extends GetxController {
  SourceThemeTopicPlaylistController({
    required this.sources,
    required this.repo,
    required this.theme,
    required this.origins,
  });

  final SourcesController sources;
  final MediaRepository repo;
  final SourceTheme theme;
  final List<SourceOrigin>? origins;

  // =========================
  // DATA
  // =========================

  Future<List<MediaItem>> loadItems(SourceThemeTopicPlaylist playlist) {
    return sources.loadPlaylistItems(
      theme: theme,
      playlist: playlist,
      origins: origins,
    );
  }

  Future<List<MediaItem>> candidateItems() {
    return sources.loadCandidateItems(theme: theme, origins: origins);
  }

  // =========================
  // PLAYLIST ACTIONS
  // =========================

  Future<void> removeItem(
    SourceThemeTopicPlaylist playlist,
    MediaItem item,
  ) async {
    final key = sources.keyForItem(item);
    await sources.updateTopicPlaylist(
      playlist.copyWith(
        itemIds: playlist.itemIds.where((e) => e != key).toList(),
      ),
    );
  }

  Future<void> updatePlaylist(SourceThemeTopicPlaylist playlist) {
    return sources.updateTopicPlaylist(playlist);
  }

  // =========================
  // PICKERS / DIALOGS
  // =========================

  Future<String?> pickLocalImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    return res?.files.first.path;
  }

  Future<String?> pickWebImage(BuildContext context, String query) {
    return showDialog<String>(
      context: context,
      builder: (_) => ImageSearchDialog(initialQuery: query),
    );
  }

  Future<String?> cacheCover(String playlistId, String url) async {
    final cached = await repo.cacheThumbnailForItem(
      itemId: playlistId,
      thumbnailUrl: url,
    );
    return cached?.trim().isNotEmpty == true ? cached : null;
  }

  // =========================
  // FLOWS (casos de uso completos)
  // =========================

  Future<void> openEditPlaylistDialog({
    required BuildContext context,
    required SourceThemeTopicPlaylist playlist,
  }) async {
    String name = playlist.name;
    String? coverUrl = playlist.coverUrl;
    String? coverLocal = playlist.coverLocalPath;
    int? colorValue = playlist.colorValue;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(tr('sources.edit_list')),
          content: StatefulBuilder(
            builder: (ctx2, setState) {
              Future<void> pickWeb() async {
                final url = await pickWebImage(ctx2, name);
                if (url == null) return;
                setState(() {
                  coverUrl = url;
                  coverLocal = null;
                });
              }

              Future<void> pickLocal() async {
                final path = await pickLocalImage();
                if (path == null) return;
                setState(() {
                  coverLocal = path;
                  coverUrl = null;
                });
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: TextEditingController(text: name),
                    onChanged: (v) => name = v,
                    decoration: InputDecoration(hintText: tr('sources.name')),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: pickWeb,
                    icon: const Icon(Icons.public_rounded),
                    label: Text(tr('sources.image_search')),
                  ),
                  OutlinedButton.icon(
                    onPressed: pickLocal,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: Text(tr('sources.choose_local')),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('common.cancel')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);

                String? finalLocal = coverLocal;
                if (coverUrl != null) {
                  finalLocal =
                      await cacheCover(playlist.id, coverUrl!) ?? coverLocal;
                }

                await updatePlaylist(
                  playlist.copyWith(
                    name: name.trim(),
                    coverUrl: coverUrl,
                    coverLocalPath: finalLocal,
                    colorValue: colorValue,
                  ),
                );
              },
              child: Text(tr('common.save')),
            ),
          ],
        );
      },
    );
  }
}
