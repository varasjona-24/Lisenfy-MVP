import 'dart:io';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/ui/widgets/dialogs/image_search_dialog.dart';
import '../../controller/settings_controller.dart';
import 'section_header.dart';
import 'value_pill.dart';
import 'palette_tile.dart';

class AppearanceSection extends GetView<SettingsController> {
  const AppearanceSection({super.key});

  Future<void> _searchWebBackground(BuildContext context) async {
    final pickedUrl = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ImageSearchDialog(
        initialQuery: 'vertical wallpaper background',
      ),
    );
    final cleaned = (pickedUrl ?? '').trim();
    if (cleaned.isEmpty) return;
    await controller.selectAppBackgroundImageFromWeb(cleaned);
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
              const Icon(Icons.palette_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                tr('settings.appearance.title'),
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
                // Theme mode
                Row(
                  children: [
                    Expanded(
                      child: SectionHeader(
                        title: tr('settings.appearance.mode_title'),
                        subtitle: tr('settings.appearance.mode_subtitle'),
                      ),
                    ),
                    Obx(
                      () => SegmentedButton<Brightness>(
                        segments: [
                          ButtonSegment(
                            value: Brightness.light,
                            label: Text(tr('settings.appearance.light')),
                            icon: const Icon(Icons.light_mode_rounded),
                          ),
                          ButtonSegment(
                            value: Brightness.dark,
                            label: Text(tr('settings.appearance.dark')),
                            icon: const Icon(Icons.dark_mode_rounded),
                          ),
                        ],
                        selected: {controller.brightness.value},
                        onSelectionChanged: (selection) {
                          controller.setBrightness(selection.first);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(color: theme.dividerColor.withValues(alpha: .12)),
                const SizedBox(height: 12),

                // Palette selector
                Obx(() {
                  final selected = controller.selectedPalette.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SectionHeader(
                              title: tr('settings.appearance.palette_title'),
                              subtitle: tr(
                                'settings.appearance.palette_subtitle',
                              ),
                            ),
                          ),
                          ValuePill(text: selected.toUpperCase()),
                        ],
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        height: 54,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            PaletteTile(
                              label: tr('settings.appearance.colors.red'),
                              color: const Color.fromARGB(255, 170, 88, 60),
                              selected: selected == 'red',
                              onTap: () => controller.setPalette('red'),
                            ),
                            PaletteTile(
                              label: tr('settings.appearance.colors.green'),
                              color: const Color.fromARGB(255, 62, 86, 66),
                              selected: selected == 'green',
                              onTap: () => controller.setPalette('green'),
                            ),
                            PaletteTile(
                              label: tr('settings.appearance.colors.blue'),
                              color: const Color.fromARGB(255, 54, 90, 150),
                              selected: selected == 'blue',
                              onTap: () => controller.setPalette('blue'),
                            ),
                            PaletteTile(
                              label: tr('settings.appearance.colors.yellow'),
                              color: const Color.fromARGB(255, 196, 154, 92),
                              selected: selected == 'yellow',
                              onTap: () => controller.setPalette('yellow'),
                            ),
                            PaletteTile(
                              label: tr('settings.appearance.colors.gray'),
                              color: const Color(0xFF4F4F4F),
                              selected: selected == 'gray',
                              onTap: () => controller.setPalette('gray'),
                            ),
                            PaletteTile(
                              label: tr('settings.appearance.colors.purple'),
                              color: const Color(0xFF6A4FA3),
                              selected: selected == 'purple',
                              onTap: () => controller.setPalette('purple'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                Divider(color: theme.dividerColor.withValues(alpha: .12)),
                const SizedBox(height: 12),

                Obx(() {
                  final imagePaths = controller.appBackgroundImagePaths
                      .where((path) => File(path).existsSync())
                      .toList();
                  final activePath = controller.appBackgroundImagePath.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: tr('settings.appearance.wallpaper_title'),
                        subtitle: tr('settings.appearance.wallpaper_subtitle'),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('settings.appearance.smart_carousel')),
                        subtitle: Text(
                          tr('settings.appearance.smart_carousel_subtitle'),
                        ),
                        value: controller.smartBackgroundCarouselEnabled.value,
                        onChanged: controller.setSmartBackgroundCarouselEnabled,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('settings.appearance.ordered_carousel')),
                        subtitle: Text(
                          controller.orderedBackgroundCarouselEnabled.value
                              ? tr('settings.appearance.ordered_carousel_on')
                              : tr('settings.appearance.ordered_carousel_off'),
                        ),
                        value:
                            controller.orderedBackgroundCarouselEnabled.value,
                        onChanged:
                            controller.smartBackgroundCarouselEnabled.value
                            ? controller.setOrderedBackgroundCarouselEnabled
                            : null,
                      ),
                      const SizedBox(height: 8),
                      _BackgroundCarousel(
                        imagePaths: imagePaths,
                        activePath: activePath,
                        onSelected: controller.setActiveAppBackgroundImage,
                        onDelete: controller.removeAppBackgroundImage,
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final useColumn = constraints.maxWidth < 390;
                          final buttons = [
                            FilledButton.tonalIcon(
                              onPressed: controller.selectAppBackgroundImage,
                              icon: const Icon(Icons.folder_open_rounded),
                              label: Text(
                                tr('settings.appearance.choose_file'),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _searchWebBackground(context),
                              icon: const Icon(Icons.public_rounded),
                              label: Text(tr('settings.appearance.search_web')),
                            ),
                          ];

                          if (useColumn) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                buttons.first,
                                const SizedBox(height: 8),
                                buttons.last,
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(child: buttons.first),
                              const SizedBox(width: 8),
                              Expanded(child: buttons.last),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BackgroundCarousel extends StatefulWidget {
  const _BackgroundCarousel({
    required this.imagePaths,
    required this.activePath,
    required this.onSelected,
    required this.onDelete,
  });

  final List<String> imagePaths;
  final String activePath;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onDelete;

  @override
  State<_BackgroundCarousel> createState() => _BackgroundCarouselState();
}

class _BackgroundCarouselState extends State<_BackgroundCarousel> {
  late final PageController _pageController;

  int get _activeIndex {
    final index = widget.imagePaths.indexOf(widget.activePath);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _activeIndex);
  }

  @override
  void didUpdateWidget(covariant _BackgroundCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imagePaths.isEmpty || !_pageController.hasClients) return;
    final activeIndex = _activeIndex;
    if (_pageController.page?.round() != activeIndex) {
      _pageController.animateToPage(
        activeIndex,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.imagePaths.isEmpty) {
      return Container(
        height: 112,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.image_outlined,
          size: 34,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 112,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.imagePaths.length,
            onPageChanged: (index) =>
                widget.onSelected(widget.imagePaths[index]),
            itemBuilder: (context, index) {
              final imagePath = widget.imagePaths[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    image: DecorationImage(
                      image: FileImage(File(imagePath)),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: .38),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: Center(
                    child: IconButton(
                      tooltip: tr('settings.appearance.remove_wallpaper'),
                      onPressed: () => widget.onDelete(imagePath),
                      icon: const Icon(Icons.delete_outline_rounded),
                      iconSize: 34,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.imagePaths.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              for (final path in widget.imagePaths)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: path == widget.activePath ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: path == widget.activePath
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
