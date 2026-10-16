import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';

/// Identity choices remain explicit: matching names never imply a merge.
class ArtistMergeDialog extends StatelessWidget {
  const ArtistMergeDialog({super.key, required this.candidates});

  final List<Map<String, dynamic>> candidates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget option(
      String result,
      IconData icon,
      String title, {
      String? subtitle,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: Icon(icon, color: scheme.primary),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: subtitle == null || subtitle.trim().isEmpty
                ? null
                : Text(subtitle),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
            ),
            onTap: () => Navigator.of(context).pop(result),
          ),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      icon: Icon(Icons.people_alt_rounded, color: scheme.primary, size: 32),
      title: Text(tr('artist_identity.collision_title')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('artist_identity.collision_message'),
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 20),
              option(
                'separate',
                Icons.call_split_rounded,
                tr('artist_identity.keep_separate'),
              ),
              for (final candidate in candidates)
                option(
                  candidate['id'] as String,
                  Icons.merge_rounded,
                  tr(
                    'artist_identity.merge_with',
                    args: [candidate['name'] as String],
                  ),
                  subtitle: candidate['country'] as String?,
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
