import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:get/get.dart';

import '../../controller/settings_controller.dart';
import '../widgets/info_tile.dart';
import '../widgets/value_pill.dart';

class AboutSection extends GetView<SettingsController> {
  const AboutSection({super.key});

  static final Uri _kofiUri = Uri.parse('https://ko-fi.com/jonyssa24');
  static final Uri _privacyPolicyUri = Uri.parse(
    'https://github.com/varasjona-24/Lisenfy-MVP/blob/main/PRIVACY_POLICY.md',
  );

  Future<void> _openExternalLink(
    BuildContext context,
    Uri uri, {
    required String fallbackMessage,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await launchUrl(
        uri,
        prefersDeepLink: false,
        customTabsOptions: CustomTabsOptions(
          browser: const CustomTabsBrowserConfiguration(
            prefersDefaultBrowser: true,
          ),
          colorSchemes: CustomTabsColorSchemes.defaults(
            toolbarColor: scheme.surface,
          ),
          showTitle: true,
          urlBarHidingEnabled: true,
          shareState: CustomTabsShareState.on,
          instantAppsEnabled: false,
          closeButton: CustomTabsCloseButton(
            icon: CustomTabsCloseButtonIcons.back,
          ),
          animations: CustomTabsSystemAnimations.slideIn(),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(fallbackMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                tr('settings.about.title'),
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
                // Version (aquí sigue fijo porque pediste misma lógica)
                InfoTile(
                  icon: Icons.verified_rounded,
                  title: tr('settings.about.version'),
                  subtitle: '1.0.0',
                ),

                const SizedBox(height: 10),

                // Storage
                Obx(() {
                  controller.storageTick.value;
                  return FutureBuilder<String>(
                    future: controller.getStorageInfo(),
                    builder: (context, snap) {
                      final loading =
                          snap.connectionState != ConnectionState.done;
                      final value = snap.data;

                      if (loading) {
                        return InfoTile(
                          icon: Icons.storage_rounded,
                          title: tr('settings.about.storage'),
                          subtitle: tr('settings.about.calculating'),
                          trailing: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      return InfoTile(
                        icon: Icons.storage_rounded,
                        title: tr('settings.about.storage'),
                        subtitle: value ?? '—',
                        trailing: ValuePill(text: tr('common.local')),
                      );
                    },
                  );
                }),

                const SizedBox(height: 10),

                // Last update (si no es real, idealmente quítalo o automatízalo luego)
                InfoTile(
                  icon: Icons.update_rounded,
                  title: tr('settings.about.last_update'),
                  subtitle: tr('settings.about.last_update_value'),
                ),

                const SizedBox(height: 14),
                Divider(color: theme.dividerColor.withValues(alpha: .12)),
                const SizedBox(height: 12),

                InfoTile(
                  icon: Icons.volunteer_activism_rounded,
                  title: tr('settings.about.support_title'),
                  subtitle: tr('settings.about.support_subtitle'),
                  trailing: FilledButton.tonalIcon(
                    onPressed: () => _openExternalLink(
                      context,
                      _kofiUri,
                      fallbackMessage: tr('settings.about.kofi_error'),
                    ),
                    icon: const Icon(Icons.local_cafe_rounded, size: 18),
                    label: const Text('Ko-fi'),
                  ),
                ),

                const SizedBox(height: 10),

                InfoTile(
                  icon: Icons.privacy_tip_rounded,
                  title: tr('settings.about.privacy_title'),
                  subtitle: tr('settings.about.privacy_subtitle'),
                  trailing: OutlinedButton.icon(
                    onPressed: () => _openExternalLink(
                      context,
                      _privacyPolicyUri,
                      fallbackMessage: tr('settings.about.privacy_error'),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(tr('common.see')),
                  ),
                ),

                const SizedBox(height: 14),
                Divider(color: theme.dividerColor.withValues(alpha: .12)),
                const SizedBox(height: 12),

                // Reset settings (misma lógica, pero con confirmación)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(tr('settings.about.reset_title')),
                          content: Text(tr('settings.about.reset_body')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(tr('common.cancel')),
                            ),
                            FilledButton.icon(
                              onPressed: () => Navigator.pop(ctx, true),
                              icon: const Icon(Icons.restart_alt_rounded),
                              label: Text(tr('common.reset')),
                            ),
                          ],
                        ),
                      );

                      if (ok == true) {
                        controller.resetSettings();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr('settings.about.reset_done')),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(tr('settings.about.reset_title')),
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
