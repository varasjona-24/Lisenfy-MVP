import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

import '../domain/capture_cover_target.dart';

enum _CoverTargetCategory { video, audio, collection }

class CaptureCoverTargetSheet extends StatefulWidget {
  const CaptureCoverTargetSheet({super.key, required this.targets});

  final Future<List<CaptureCoverTarget>> targets;

  @override
  State<CaptureCoverTargetSheet> createState() =>
      _CaptureCoverTargetSheetState();
}

class _CaptureCoverTargetSheetState extends State<CaptureCoverTargetSheet> {
  final TextEditingController _queryCtrl = TextEditingController();
  String _query = '';
  _CoverTargetCategory _category = _CoverTargetCategory.video;
  CaptureCoverTarget? _selected;

  @override
  void initState() {
    super.initState();
    _queryCtrl.addListener(() {
      setState(() => _query = _queryCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_photo_alternate_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('captures.actions.use_as_cover'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(tr('common.close')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<_CoverTargetCategory>(
                    segments: [
                      ButtonSegment(
                        value: _CoverTargetCategory.video,
                        label: Text(tr('captures.cover.videos')),
                        icon: const Icon(Icons.videocam_rounded),
                      ),
                      ButtonSegment(
                        value: _CoverTargetCategory.audio,
                        label: Text(tr('captures.cover.audio')),
                        icon: const Icon(Icons.music_note_rounded),
                      ),
                      ButtonSegment(
                        value: _CoverTargetCategory.collection,
                        label: Text(tr('captures.cover.collections')),
                        icon: const Icon(Icons.folder_rounded),
                      ),
                    ],
                    selected: {_category},
                    onSelectionChanged: (value) {
                      setState(() => _category = value.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _queryCtrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _queryCtrl.clear();
                              },
                            ),
                      hintText: switch (_category) {
                        _CoverTargetCategory.video => tr(
                          'captures.cover.search_video',
                        ),
                        _CoverTargetCategory.audio => tr(
                          'captures.cover.search_audio',
                        ),
                        _CoverTargetCategory.collection => tr(
                          'captures.cover.search_collection',
                        ),
                      },
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CaptureCoverTarget>>(
                future: widget.targets,
                builder: (context, snapshot) {
                  final all = snapshot.data ?? const <CaptureCoverTarget>[];
                  final filtered = all
                      .where((target) {
                        final matchesCategory = switch (_category) {
                          _CoverTargetCategory.video => target.isVideo,
                          _CoverTargetCategory.audio => target.isAudio,
                          _CoverTargetCategory.collection =>
                            target.isCollection,
                        };
                        if (!matchesCategory) return false;
                        if (_query.isEmpty) return true;
                        return target.label.toLowerCase().contains(_query) ||
                            target.subtitle.toLowerCase().contains(_query);
                      })
                      .toList(growable: false);

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        switch (_category) {
                          _CoverTargetCategory.video => tr(
                            'captures.cover.no_videos',
                          ),
                          _CoverTargetCategory.audio => tr(
                            'captures.cover.no_audio',
                          ),
                          _CoverTargetCategory.collection => tr(
                            'captures.cover.no_collections',
                          ),
                        },
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final target = filtered[index];
                      return _SelectableCoverTarget(
                        target: target,
                        compact: target.isAudio,
                        selected:
                            _selected?.id == target.id &&
                            _selected?.type == target.type,
                        icon: _iconFor(target),
                        onTap: () => setState(() {
                          _selected = target;
                        }),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(tr('captures.cover.apply')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(CaptureCoverTarget target) {
    return switch (target.type) {
      CaptureCoverTargetType.video => Icons.videocam_rounded,
      CaptureCoverTargetType.audio => Icons.music_note_rounded,
      CaptureCoverTargetType.topic => Icons.folder_rounded,
      CaptureCoverTargetType.playlist => Icons.video_library_rounded,
    };
  }
}

class _SelectableCoverTarget extends StatelessWidget {
  const _SelectableCoverTarget({
    required this.target,
    required this.compact,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final CaptureCoverTarget target;
  final bool compact;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final image = _imageProvider();

    final material = Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.48)
          : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: compact
          ? ListTile(
              onTap: onTap,
              leading: _coverImage(
                image: image,
                scheme: scheme,
                width: 48,
                height: 48,
              ),
              title: Text(
                target.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                target.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Checkbox(value: selected, onChanged: (_) => onTap()),
            )
          : InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 42, 10),
                    child: Row(
                      children: [
                        _coverImage(
                          image: image,
                          scheme: scheme,
                          width: 72,
                          height: 44,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                target.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                target.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) => onTap(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
    return material;
  }

  Widget _coverImage({
    required ImageProvider? image,
    required ColorScheme scheme,
    required double width,
    required double height,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: image == null
            ? ColoredBox(
                color: scheme.primary.withValues(alpha: .12),
                child: Icon(icon, color: scheme.primary),
              )
            : Image(image: image, fit: BoxFit.cover),
      ),
    );
  }

  ImageProvider? _imageProvider() {
    final local = target.thumbnailLocalPath?.trim();
    if (local != null && local.isNotEmpty) {
      return FileImage(File(local));
    }
    final remote = target.thumbnailUrl?.trim();
    if (remote != null && remote.isNotEmpty) {
      return NetworkImage(remote);
    }
    return null;
  }
}
