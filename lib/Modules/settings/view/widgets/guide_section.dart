import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../settings_manual_page.dart';

class GuideSection extends StatelessWidget {
  const GuideSection({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor:
              Theme.of(context).cardTheme.color ??
              Theme.of(context).colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SettingsManualPage()),
        ),
        icon: const Icon(Icons.menu_book_rounded),
        label: Text(tr('settings.guide.read_manual')),
      ),
    ),
  );
}
