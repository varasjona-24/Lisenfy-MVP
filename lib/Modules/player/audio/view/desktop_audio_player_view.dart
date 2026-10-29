import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:get/get.dart';

import '../../../../app/controllers/media_actions_controller.dart';
import '../../../../app/data/local/local_library_store.dart';
import '../../../../app/models/media_item.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../app/ui/widgets/player/player_instrumental_sheet.dart';
import '../../../../app/ui/widgets/player/player_lyrics_sheet.dart';
import '../../../../app/ui/widgets/player/player_desktop_dialog.dart';
import '../../../playlists/controller/playlists_controller.dart';
import '../../../playlists/data/playlist_store.dart';
import '../../../playlists/domain/playlist.dart';
import '../../../settings/controller/playback_settings_controller.dart';
import '../controller/audio_player_controller.dart';
import '../widgets/cover_art.dart';
import '../widgets/progress_bar.dart';

bool usesDesktopAudioPlayer(TargetPlatform target) =>
    !kIsWeb &&
    (target == TargetPlatform.macOS ||
        target == TargetPlatform.windows ||
        target == TargetPlatform.linux);

/// Desktop-only composition; the audio engine and mobile player are unchanged.
class DesktopAudioPlayerView extends StatelessWidget {
  const DesktopAudioPlayerView({
    super.key,
    required this.controller,
    required this.item,
    required this.style,
    required this.onVisual,
    required this.instrumental,
    required this.spatial8d,
  });
  final AudioPlayerController controller;
  final MediaItem item;
  final CoverStyle style;
  final VoidCallback onVisual;
  final bool instrumental, spatial8d;

  Future<void> _refreshItem() async {
    final library = Get.find<LocalLibraryStore>();
    final items = await library.readAll();
    for (final latest in items) {
      if (latest.id == item.id ||
          (item.publicId.isNotEmpty && latest.publicId == item.publicId)) {
        controller.audioService.applyUpdatedMediaItem(latest);
        controller.updateQueueItem(latest);
        return;
      }
    }
  }

  Future<void> _addToPlaylist(BuildContext context) async {
    try {
      await _pickPlaylist(context);
    } catch (_) {
      Get.snackbar(
        tr('player.desktop.add_playlist'),
        tr('player.desktop.save_failed'),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  bool _playlistContainsTrack(Playlist playlist) {
    final keys = {item.id.trim(), item.publicId.trim()}..remove('');
    return playlist.itemIds.any((id) => keys.contains(id.trim()));
  }

  Future<void> _pickPlaylist(BuildContext context) async {
    final store = Get.find<PlaylistStore>();
    final playlists = (await store.readAll())
        .where((list) => !list.isTemporary)
        .toList();
    if (!context.mounted) return;
    final selected = await showDialog<Playlist>(
      context: context,
      builder: (context) => PlayerDesktopDialog(
        reading: true,
        maxWidth: 620,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('player.desktop.add_playlist'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: playlists.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(tr('playlists.empty')),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: playlists.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _PlaylistPickerCard(
                            playlist: playlists[index],
                            alreadyAdded: _playlistContainsTrack(
                              playlists[index],
                            ),
                            onTap: () =>
                                Navigator.of(context).pop(playlists[index]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null) return;
    // Re-read after the picker so edits made elsewhere are not overwritten.
    final current = (await store.readAll())
        .where((list) => list.id == selected.id)
        .firstOrNull;
    if (current == null) return;
    final key = item.publicId.trim().isNotEmpty
        ? item.publicId.trim()
        : item.id;
    if (_playlistContainsTrack(current)) {
      Get.snackbar(
        tr('player.desktop.add_playlist'),
        tr('player.desktop.playlist_already_contains'),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    {
      final now = DateTime.now().millisecondsSinceEpoch;
      await store.upsert(
        current.copyWith(
          itemIds: [...current.itemIds, key],
          itemAddedAt: {...current.itemAddedAt, key: now},
          updatedAt: now,
        ),
      );
      if (Get.isRegistered<PlaylistsController>()) {
        await Get.find<PlaylistsController>().load();
      }
    }
    Get.snackbar(
      tr('player.desktop.add_playlist'),
      tr('player.desktop.playlist_added'),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final actions = Get.find<MediaActionsController>();
    final audio = controller.audioService;
    final landscape = style == CoverStyle.landscape;
    final surface = Color.alphaBlend(
      scheme.primary.withValues(alpha: .035),
      scheme.surface,
    );
    return Material(
      color: surface.withValues(alpha: .96),
      child: Stack(
        children: [
          if (landscape)
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: theme.brightness == Brightness.dark ? .12 : .07,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: _DesktopArtwork(item: item),
                    ),
                  ),
                ),
              ),
            ),
          DesktopPlayerLayout(
            header: Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Get.back(),
                ),
                Expanded(
                  child: Text(
                    tr('player.now_playing'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr('player.view_queue'),
                  icon: const Icon(Icons.queue_music_rounded),
                  onPressed: () => Get.toNamed(AppRoutes.audioQueue),
                ),
              ],
            ),
            artwork: style == CoverStyle.vinyl
                ? LayoutBuilder(
                    builder: (_, box) => CoverArt(
                      controller: controller,
                      item: item,
                      size: math.min(box.maxWidth, box.maxHeight),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _DesktopArtwork(item: item),
                  ),
            details: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  item.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 12),
                if (item.displaySubtitle.isNotEmpty)
                  Text(
                    item.displaySubtitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: tr('player.desktop.favorite'),
                      icon: Icon(
                        item.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: item.isFavorite ? scheme.primary : null,
                      ),
                      onPressed: () =>
                          actions.toggleFavorite(item, onChanged: _refreshItem),
                    ),
                    IconButton(
                      tooltip: tr('player.desktop.add_playlist'),
                      icon: const Icon(Icons.playlist_add_rounded),
                      onPressed: () => _addToPlaylist(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Obx(
                  () => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: tr('player.shuffle'),
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 48,
                        ),
                        padding: EdgeInsets.zero,
                        isSelected: controller.isShuffling.value,
                        selectedIcon: Icon(
                          Icons.shuffle_rounded,
                          color: scheme.primary,
                        ),
                        icon: const Icon(Icons.shuffle_rounded),
                        onPressed: audio.isLoading.value
                            ? null
                            : controller.toggleShuffle,
                      ),
                      IconButton(
                        tooltip: tr('player.desktop.previous'),
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 48,
                        ),
                        padding: EdgeInsets.zero,
                        iconSize: 32,
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: audio.isLoading.value
                            ? null
                            : controller.previous,
                      ),
                      SizedBox.square(
                        dimension: 72,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: audio.isLoading.value
                              ? null
                              : controller.togglePlay,
                          child: audio.isLoading.value
                              ? SizedBox.square(
                                  dimension: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: scheme.primary,
                                  ),
                                )
                              : Icon(
                                  audio.isPlaying.value
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 38,
                                  semanticLabel: tr(
                                    audio.isPlaying.value
                                        ? 'player.pause'
                                        : 'player.play',
                                  ),
                                ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('player.desktop.next'),
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 48,
                        ),
                        padding: EdgeInsets.zero,
                        iconSize: 32,
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: audio.isLoading.value
                            ? null
                            : controller.next,
                      ),
                      SizedBox(
                        width: 64,
                        child: TextButton(
                          onPressed: audio.isLoading.value
                              ? null
                              : controller.cyclePlaybackSpeed,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${audio.speed.value.toStringAsFixed(2)}×',
                              semanticsLabel: tr('player.speed'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const ProgressBar(),
                const SizedBox(height: 18),
                Obx(
                  () => Row(
                    children: [
                      Icon(
                        Icons.volume_up_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr('player.desktop.volume'),
                        style: theme.textTheme.labelMedium,
                      ),
                      Expanded(
                        child: Slider(
                          value: audio.volume.value.clamp(0, 1),
                          onChanged: audio.setVolume,
                          onChangeEnd: (value) =>
                              Get.find<PlaybackSettingsController>()
                                  .setDefaultVolume(value * 100),
                          semanticFormatterCallback: (value) =>
                              '${(value * 100).round()}%',
                        ),
                      ),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${(audio.volume.value * 100).round()}%',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            footer: Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 24,
              runSpacing: 8,
              children: [
                _DesktopOption(
                  icon: Icons.image_rounded,
                  label: tr('player.quick.visual'),
                  value: tr('player.visualizer.styles.${style.name}'),
                  onTap: onVisual,
                ),
                _DesktopOption(
                  icon: Icons.lyrics_rounded,
                  label: tr('player.quick.lyrics'),
                  value: tr('player.desktop.view_lyrics'),
                  onTap: () => openPlayerLyricsSheet(item, heightFactor: .8),
                ),
                _DesktopOption(
                  icon: Icons.graphic_eq_rounded,
                  label: tr('player.quick.mode'),
                  value: instrumental
                      ? tr('player.quick.instrumental')
                      : spatial8d
                      ? '8D'
                      : tr('player.quick.normal'),
                  onTap: () => openPlayerInstrumentalSheet(item),
                ),
                Obx(
                  () => _DesktopOption(
                    icon: controller.repeatMode.value == RepeatMode.once
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    label: tr('player.quick.repeat'),
                    value: controller.repeatMode.value == RepeatMode.off
                        ? tr('common.off')
                        : controller.repeatMode.value == RepeatMode.once
                        ? tr('player.quick.repeat_one')
                        : tr('player.quick.repeat_once'),
                    onTap: controller.cycleRepeatMode,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slot layout kept independent of GetX/services so resize behavior is testable.
class DesktopPlayerLayout extends StatelessWidget {
  const DesktopPlayerLayout({
    super.key,
    required this.header,
    required this.artwork,
    required this.details,
    required this.footer,
  });
  final Widget header, artwork, details, footer;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 920;
      // Reserve room for the header and secondary actions before sizing art.
      // Details may grow beyond this budget and remain reachable by scrolling.
      final bodyHeight = math.max(320.0, box.maxHeight - 360);
      final artSize = wide
          ? math.min(640.0, math.min((box.maxWidth - 112) * .48, bodyHeight))
          : math.min(380.0, math.max(120.0, box.maxWidth - 48));
      return SingleChildScrollView(
        key: const ValueKey('desktop-player-scroll'),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1560),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 28 : 20,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    header,
                    const SizedBox(height: 24),
                    if (wide)
                      Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: SizedBox.square(
                                dimension: artSize,
                                child: artwork,
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                          Expanded(child: Center(child: details)),
                        ],
                      )
                    else ...[
                      SizedBox.square(dimension: artSize, child: artwork),
                      const SizedBox(height: 28),
                      details,
                    ],
                    const SizedBox(height: 28),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: SizedBox(width: double.infinity, child: footer),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _DesktopArtwork extends StatelessWidget {
  const _DesktopArtwork({required this.item});
  final MediaItem item;
  @override
  Widget build(BuildContext context) {
    final source = item.effectiveThumbnail;
    Widget fallback() => ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
    if (source == null || source.isEmpty) return fallback();
    return Image(
      image: source.startsWith('http')
          ? NetworkImage(source)
          : FileImage(File(source)) as ImageProvider,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => fallback(),
    );
  }
}

class _DesktopOption extends StatelessWidget {
  const _DesktopOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 155,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PlaylistPickerCard extends StatelessWidget {
  const _PlaylistPickerCard({
    required this.playlist,
    required this.onTap,
    this.alreadyAdded = false,
  });
  final Playlist playlist;
  final VoidCallback onTap;
  final bool alreadyAdded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final local = playlist.coverLocalPath?.trim() ?? '';
    final remote = playlist.coverUrl?.trim() ?? '';
    final source = playlist.coverCleared
        ? ''
        : local.isNotEmpty
        ? local
        : remote;
    final ImageProvider? provider = source.isEmpty
        ? null
        : source.startsWith('assets/')
        ? AssetImage(source)
        : source.startsWith('http')
        ? NetworkImage(source)
        : FileImage(File(source));
    final fallback = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.queue_music_rounded, color: scheme.primary, size: 30),
    );
    final count = playlist.itemIds.toSet().length;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alreadyAdded ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox.square(
                  dimension: 64,
                  child: provider == null
                      ? fallback
                      : Image(
                          image: provider,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => fallback,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (alreadyAdded) ...[
                      const SizedBox(height: 4),
                      Text(
                        tr('player.desktop.playlist_already_contains'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        count == 1 ? 'common.songs.one' : 'common.songs.other',
                        args: ['$count'],
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                alreadyAdded
                    ? Icons.check_circle_rounded
                    : Icons.playlist_add_rounded,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
