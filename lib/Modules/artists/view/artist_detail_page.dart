import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/models/media_item.dart';
import '../../../app/controllers/media_actions_controller.dart';
import '../../../app/utils/artist_credit_parser.dart';
import '../../../app/utils/country_catalog.dart';
import 'package:listenfy/Modules/home/controller/home_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../controller/artists_controller.dart';
import '../domain/artist_profile.dart';
import '../../edit/controller/edit_entity_controller.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';
import 'widgets/artist_avatar.dart';
import '../../../app/ui/widgets/branding/listenfy_logo.dart';

class ArtistDetailPage extends GetView<ArtistsController> {
  const ArtistDetailPage({super.key, required this.artistKey});

  final String artistKey;

  List<MediaItem> _dedupeById(Iterable<MediaItem> input) {
    final out = <MediaItem>[];
    final seen = <String>{};
    for (final item in input) {
      if (!seen.add(item.id)) continue;
      out.add(item);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final home = Get.find<HomeController>();
    final actions = Get.find<MediaActionsController>();

    return Obx(() {
      ArtistGroup? artist;
      for (final entry in controller.artists) {
        if (entry.key == artistKey) {
          artist = entry;
          break;
        }
      }

      if (artist == null) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Artista'),
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            elevation: 0,
          ),
          body: const Center(child: Text('Artista no encontrado')),
        );
      }

      final resolved = artist;
      final artistsByKey = <String, ArtistGroup>{
        for (final entry in controller.artists) entry.key: entry,
      };
      final isBand = resolved.kind == ArtistProfileKind.band;

      final primarySongs = resolved.items
          .where((item) {
            final credits = ArtistCreditParser.parse(item.subtitle);
            return credits.isPrimaryArtistKey(resolved.key);
          })
          .toList(growable: false);
      final collaborationSongs = resolved.items
          .where((item) {
            final credits = ArtistCreditParser.parse(item.subtitle);
            return credits.isCollaborationForArtistKey(resolved.key);
          })
          .toList(growable: false);

      final memberArtists = resolved.memberKeys
          .map((key) => artistsByKey[key])
          .whereType<ArtistGroup>()
          .toList(growable: false);
      final memberKeySet = memberArtists.map((e) => e.key).toSet();

      final memberSingles = <MediaItem>[];
      final memberCollaborations = <MediaItem>[];
      if (isBand && memberKeySet.isNotEmpty) {
        final memberPool = _dedupeById(
          memberArtists.expand((entry) => entry.items),
        );
        for (final item in memberPool) {
          final credits = ArtistCreditParser.parse(item.subtitle);
          if (credits.containsArtistKey(resolved.key)) continue;

          final memberAsPrimary = memberKeySet.any(credits.isPrimaryArtistKey);
          final memberAsCollab =
              !memberAsPrimary &&
              memberKeySet.any(credits.isCollaborationForArtistKey);

          if (memberAsPrimary) {
            memberSingles.add(item);
          } else if (memberAsCollab) {
            memberCollaborations.add(item);
          }
        }
      }

      final displayQueue = _dedupeById([
        ...primarySongs,
        ...collaborationSongs,
        ...memberSingles,
        ...memberCollaborations,
      ]);

      final thumb = resolved.thumbnailLocalPath ?? resolved.thumbnail;
      final country = (resolved.country ?? '').trim();
      final countryFlag = CountryCatalog.flagFromIso(resolved.countryCode);
      final typeLabel = isBand ? 'Banda' : 'Cantante';
      final typeCountryLine = country.isNotEmpty
          ? '$typeLabel - ${countryFlag.isEmpty ? country : '$countryFlag $country'}'
          : typeLabel;

      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: ListenfyLogo(size: 28, color: theme.colorScheme.primary),
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => Get.toNamed(
                AppRoutes.editEntity,
                arguments: EditEntityArgs.artist(resolved),
              ),
            ),
          ],
        ),
        body: AppGradientBackground(
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ArtistAvatar(thumb: thumb, radius: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                resolved.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                typeCountryLine,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '${resolved.count} canciones',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (isBand && memberArtists.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${memberArtists.length} integrantes',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (isBand && memberArtists.isNotEmpty) ...[
                  _MemberSection(
                    members: memberArtists,
                    onOpen: (member) => Get.toNamed(
                      AppRoutes.artistDetail,
                      arguments: member.key,
                      preventDuplicates: false,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _SongSection(
                  title: isBand ? 'Canciones de la banda' : 'Canciones',
                  subtitle: '${primarySongs.length} como artista principal',
                  items: primarySongs,
                  onPlay: (item) => home.openMedia(
                    item,
                    displayQueue.indexWhere((entry) => entry.id == item.id),
                    displayQueue,
                  ),
                  onMore: (item) => actions.showItemActions(
                    context,
                    item,
                    onChanged: controller.load,
                  ),
                ),
                if (collaborationSongs.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SongSection(
                    title: isBand
                        ? 'Colaboraciones de la banda'
                        : 'Colaboraciones',
                    subtitle: '${collaborationSongs.length} como invitado',
                    items: collaborationSongs,
                    onPlay: (item) => home.openMedia(
                      item,
                      displayQueue.indexWhere((entry) => entry.id == item.id),
                      displayQueue,
                    ),
                    onMore: (item) => actions.showItemActions(
                      context,
                      item,
                      onChanged: controller.load,
                    ),
                  ),
                ],
                if (isBand && memberSingles.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SongSection(
                    title: 'Singles de integrantes',
                    subtitle:
                        '${memberSingles.length} canciones como principal',
                    items: memberSingles,
                    onPlay: (item) => home.openMedia(
                      item,
                      displayQueue.indexWhere((entry) => entry.id == item.id),
                      displayQueue,
                    ),
                    onMore: (item) => actions.showItemActions(
                      context,
                      item,
                      onChanged: controller.load,
                    ),
                  ),
                ],
                if (isBand && memberCollaborations.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SongSection(
                    title: 'Colaboraciones de integrantes',
                    subtitle:
                        '${memberCollaborations.length} canciones como invitados',
                    items: memberCollaborations,
                    onPlay: (item) => home.openMedia(
                      item,
                      displayQueue.indexWhere((entry) => entry.id == item.id),
                      displayQueue,
                    ),
                    onMore: (item) => actions.showItemActions(
                      context,
                      item,
                      onChanged: controller.load,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _MemberSection extends StatelessWidget {
  const _MemberSection({required this.members, required this.onOpen});

  final List<ArtistGroup> members;
  final ValueChanged<ArtistGroup> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Integrantes',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (_, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final member = members[index];
              return _MemberArtistCard(
                member: member,
                onTap: () => onOpen(member),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MemberArtistCard extends StatelessWidget {
  const _MemberArtistCard({required this.member, required this.onTap});

  final ArtistGroup member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final thumb = member.thumbnailLocalPath ?? member.thumbnail;
    final imageProvider = (thumb != null && thumb.isNotEmpty)
        ? (thumb.startsWith('http')
              ? NetworkImage(thumb)
              : FileImage(File(thumb)) as ImageProvider)
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
                image: imageProvider != null
                    ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                    : null,
              ),
              child: imageProvider == null
                  ? Icon(
                      Icons.person_rounded,
                      size: 34,
                      color: scheme.onSurfaceVariant,
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Cantante',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongSection extends StatelessWidget {
  const _SongSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onPlay,
    required this.onMore,
  });

  final String title;
  final String subtitle;
  final List<MediaItem> items;
  final ValueChanged<MediaItem> onPlay;
  final ValueChanged<MediaItem> onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in items)
          _SongTile(
            item: item,
            onPlay: () => onPlay(item),
            onMore: () => onMore(item),
          ),
      ],
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.item,
    required this.onPlay,
    required this.onMore,
  });

  final MediaItem item;
  final VoidCallback onPlay;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVideo = item.hasVideoLocal || item.localVideoVariant != null;
    final thumb = item.effectiveThumbnail ?? '';
    final hasThumb = thumb.isNotEmpty;
    final isLocal = hasThumb && thumb.startsWith('/');

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: hasThumb
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isLocal
                    ? Image.file(
                        File(thumb),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        thumb,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
              )
            : Icon(isVideo ? Icons.videocam_rounded : Icons.music_note_rounded),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          item.displaySubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: onMore,
        ),
        onTap: onPlay,
      ),
    );
  }
}
