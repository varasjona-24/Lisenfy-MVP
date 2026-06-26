import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

import '../domain/capture_cover_target.dart';

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
  bool _showVideos = true;
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
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text(tr('captures.cover.videos')),
                        icon: const Icon(Icons.videocam_rounded),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text(tr('captures.cover.collections')),
                        icon: const Icon(Icons.folder_rounded),
                      ),
                    ],
                    selected: {_showVideos},
                    onSelectionChanged: (value) {
                      setState(() => _showVideos = value.first);
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
                      hintText: _showVideos
                          ? tr('captures.cover.search_video')
                          : tr('captures.cover.search_collection'),
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
                        if (_showVideos != target.isVideo) return false;
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
                        _showVideos
                            ? 'No hay videos disponibles.'
                            : 'No hay collections disponibles.',
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
      CaptureCoverTargetType.topic => Icons.folder_rounded,
      CaptureCoverTargetType.playlist => Icons.video_library_rounded,
    };
  }
}

class _SelectableCoverTarget extends StatelessWidget {
  const _SelectableCoverTarget({
    required this.target,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final CaptureCoverTarget target;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final image = _imageProvider();

    return Material(
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
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 42, 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72,
                      height: 44,
                      child: image == null
                          ? ColoredBox(
                              color: scheme.primary.withValues(alpha: .12),
                              child: Icon(icon, color: scheme.primary),
                            )
                          : Image(image: image, fit: BoxFit.cover),
                    ),
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
                child: Checkbox(value: selected, onChanged: (_) => onTap()),
              ),
            ),
          ],
        ),
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
