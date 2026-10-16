import 'dart:io';
import '../../domain/artist_profile.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

class ArtistIdentityDialog extends StatelessWidget {
  const ArtistIdentityDialog({
    super.key,
    required this.title,
    required this.candidates,
    this.allowCreate = true,
  });
  final String title;
  final List<Map<String, dynamic>> candidates;
  final bool allowCreate;

  Widget _avatar(Map<String, dynamic> candidate, Color color) {
    final local = candidate['thumbnailLocalPath'] as String?;
    final remote = candidate['thumbnail'] as String?;
    final fallback = Icon(
      allowCreate ? Icons.person_rounded : Icons.music_note_rounded,
      color: color,
    );
    final Widget image =
        local != null && local.isNotEmpty && File(local).existsSync()
        ? Image.file(
            File(local),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : remote != null && remote.isNotEmpty
        ? Image.network(
            remote,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 44, height: 44, child: image),
    );
  }

  String _description(Map<String, dynamic> candidate) {
    final region = ArtistMainRegionX.fromRaw(candidate['mainRegion']);
    return [
      if ((candidate['country'] as String? ?? '').isNotEmpty)
        candidate['country'] as String,
      if (region != ArtistMainRegion.none) region.simpleLabel,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant),
      ),
      icon: Icon(Icons.person_search_rounded, color: colors.primary, size: 32),
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('artist_identity.resolve_message'),
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 16),
              for (final candidate in candidates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: _avatar(candidate, colors.primary),
                      title: Text(
                        candidate['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: _description(candidate).isEmpty
                          ? null
                          : Text(_description(candidate)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).pop(candidate),
                    ),
                  ),
                ),
              if (allowCreate)
                OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(<String, dynamic>{}),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(tr('artist_identity.create_separate')),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('common.cancel')),
        ),
      ],
    );
  }
}
