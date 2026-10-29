import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../settings_manual_page.dart';
import '../../../../app/ui/widgets/navigation/app_bottom_nav.dart';

class GuideSection extends StatelessWidget {
  const GuideSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppBottomNav.desktopSidebarEnabled) {
      final scheme = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: scheme.surfaceContainer.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: Text(tr('settings.guide.read_manual')),
            tilePadding: const EdgeInsets.all(18),
            childrenPadding: const EdgeInsets.all(8),
            children: const [SettingsManualPage(embedded: true)],
          ),
        ),
      );
    }
    return Padding(
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
}
