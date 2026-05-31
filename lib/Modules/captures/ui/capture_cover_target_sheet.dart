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
        height: MediaQuery.sizeOf(context).height * .78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Usar como portada',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Videos'),
                        icon: Icon(Icons.videocam_rounded),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Collections'),
                        icon: Icon(Icons.folder_rounded),
                      ),
                    ],
                    selected: {_showVideos},
                    onSelectionChanged: (value) {
                      setState(() => _showVideos = value.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  SearchBar(
                    controller: _queryCtrl,
                    hintText: _showVideos
                        ? 'Buscar video'
                        : 'Buscar collection',
                    leading: const Icon(Icons.search_rounded),
                    elevation: const WidgetStatePropertyAll(0),
                    backgroundColor: WidgetStatePropertyAll(
                      scheme.surfaceContainerHigh,
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final target = filtered[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor: scheme.surfaceContainerHighest.withValues(
                          alpha: .55,
                        ),
                        leading: Icon(_iconFor(target), color: scheme.primary),
                        title: Text(
                          target.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          target.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(context).pop(target),
                      );
                    },
                  );
                },
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
