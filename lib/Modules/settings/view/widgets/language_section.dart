import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;

import 'info_tile.dart';

class LanguageSection extends StatelessWidget {
  const LanguageSection({super.key});

  static const _spanish = Locale('es');
  static const _english = Locale('en');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentLocale = context.locale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.language_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                tr('settings.language.title'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withValues(alpha: .12)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                InfoTile(
                  icon: Icons.translate_rounded,
                  title: tr('settings.language.title'),
                  subtitle: tr('settings.language.subtitle'),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<Locale>(
                    segments: [
                      ButtonSegment<Locale>(
                        value: _spanish,
                        label: Text(tr('settings.language.spanish')),
                      ),
                      ButtonSegment<Locale>(
                        value: _english,
                        label: Text(tr('settings.language.english')),
                      ),
                    ],
                    selected: {
                      currentLocale.languageCode == _english.languageCode
                          ? _english
                          : _spanish,
                    },
                    onSelectionChanged: (selection) async {
                      final locale = selection.first;
                      if (locale == context.locale) return;
                      await context.setLocale(locale);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('settings.language.system_note'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
