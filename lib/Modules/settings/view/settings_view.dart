import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:get/get.dart';

import '../controller/settings_controller.dart';
import '../../../app/ui/widgets/navigation/app_navigation_scaffold.dart';
import '../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../../app/ui/widgets/layout/app_library_header.dart';
import 'widgets/appearance_section.dart';
import 'widgets/audio_section.dart';
import 'widgets/data_section.dart';
import 'widgets/video_section.dart';
import 'widgets/about_section.dart';
import 'widgets/guide_section.dart';
import 'widgets/notifications_section.dart';
import 'widgets/language_section.dart';
import '../../../app/ui/widgets/layout/app_gradient_background.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final barColor = isDark ? Colors.black : Colors.white;

    return AppNavigationScaffold(
      navigationIndex: -1,
      appBar: AppBottomNav.desktopSidebarEnabled
          ? null
          : AppBar(
              title: Text(tr('settings.title')),
              centerTitle: true,
              elevation: 0,
              backgroundColor: barColor,
              surfaceTintColor: barColor,
              foregroundColor: scheme.onSurface,
            ),
      backgroundColor: Colors.transparent,
      body: AppGradientBackground(
        child: AppBottomNav.desktopSidebarEnabled
            ? const _DesktopSettings()
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    children: [
                      // 🎨 Sección de Apariencia
                      const AppearanceSection(),
                      const SizedBox(height: 24),

                      // 🌐 Sección de idioma
                      const LanguageSection(),
                      const SizedBox(height: 24),

                      // 🔊 Sección de Audio
                      const AudioSection(),
                      const SizedBox(height: 24),

                      // 🎬 Sección de Video
                      const VideoSection(),
                      const SizedBox(height: 24),

                      // 📡 Sección de Datos
                      const DataSection(),
                      const SizedBox(height: 24),

                      // 🔔 Sección de notificaciones
                      const NotificationsSection(),
                      const SizedBox(height: 24),

                      // 📘 Guía rápida
                      const GuideSection(),
                      const SizedBox(height: 24),

                      // ℹ️ Sección de Información
                      const AboutSection(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _DesktopSettings extends StatefulWidget {
  const _DesktopSettings();

  @override
  State<_DesktopSettings> createState() => _DesktopSettingsState();
}

class _DesktopSettingsState extends State<_DesktopSettings> {
  int selected = 0;
  final scrollController = ScrollController();
  static const categories = [
    ('appearance', Icons.palette_rounded, AppearanceSection()),
    ('language', Icons.language_rounded, LanguageSection()),
    ('audio', Icons.volume_up_rounded, AudioSection()),
    ('video', Icons.movie_rounded, VideoSection()),
    ('data', Icons.download_rounded, DataSection()),
    ('notifications', Icons.notifications_rounded, NotificationsSection()),
    ('guide', Icons.help_outline_rounded, GuideSection()),
    ('about', Icons.info_outline_rounded, AboutSection()),
  ];

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppLibraryHeader(
                title: tr('settings.title'),
                subtitle: tr('nav.settings_subtitle'),
                metrics: const [],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer.withValues(alpha: .85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: .35),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < categories.length; i++)
                      ChoiceChip(
                        avatar: Icon(categories[i].$2, size: 20),
                        label: Text(tr('settings.${categories[i].$1}.title')),
                        selected: selected == i,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => selected = i),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: SizedBox(
                    width: double.infinity,
                    child: KeyedSubtree(
                      key: ValueKey(selected),
                      child: categories[selected].$3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
