import 'dart:ui';

import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/services/audio_service.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../../../app/ui/widgets/branding/listenfy_logo.dart';
import '../../../../app/ui/widgets/navigation/app_top_bar.dart';
import '../../../../app/ui/widgets/navigation/app_bottom_nav.dart';
import '../../controller/world_mode_controller.dart';
import '../widgets/country_station_card.dart';
import '../widgets/world_globe_canvas.dart';
import '../widgets/world_map_canvas.dart';

class WorldModePage extends GetView<WorldModeController> {
  const WorldModePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _ImmersiveAtlasView(ctrl: controller);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTA INMERSIVA estilo Radio Garden
// ─────────────────────────────────────────────────────────────────────────────

class _ImmersiveAtlasView extends StatefulWidget {
  const _ImmersiveAtlasView({required this.ctrl});

  final WorldModeController ctrl;

  @override
  State<_ImmersiveAtlasView> createState() => _ImmersiveAtlasViewState();
}

class _ImmersiveAtlasViewState extends State<_ImmersiveAtlasView> {
  static const double _collapsedSheetExtent = 0.0;
  static const double _stationsSheetExtent = 0.40;

  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();
  double _sheetExtent = _collapsedSheetExtent;
  bool _restoreMiniPlayerWhenStationsClose = false;

  @override
  void initState() {
    super.initState();
    _sheetCtrl.addListener(_syncSheetExtent);
  }

  void _syncSheetExtent() {
    if (!mounted || !_sheetCtrl.isAttached) return;
    final nextExtent = _sheetCtrl.size;
    if ((nextExtent - _sheetExtent).abs() < 0.01) return;

    final wasOpen = _sheetExtent >= 0.20;
    final isOpen = nextExtent >= 0.20;
    if (!wasOpen && isOpen) {
      _hideMiniPlayerForStations();
    } else if (wasOpen && !isOpen) {
      _restoreMiniPlayerAfterStations();
    }
    setState(() => _sheetExtent = nextExtent);
  }

  void _hideMiniPlayerForStations() {
    if (!Get.isRegistered<AudioService>()) return;
    final audio = Get.find<AudioService>();
    final wasVisible =
        !audio.miniPlayerDismissed.value &&
        (audio.state.value != PlaybackState.stopped || audio.keepLastItem);
    if (!wasVisible) return;
    audio.miniPlayerDismissed.value = true;
    _restoreMiniPlayerWhenStationsClose = true;
  }

  void _restoreMiniPlayerAfterStations() {
    if (!_restoreMiniPlayerWhenStationsClose ||
        !Get.isRegistered<AudioService>()) {
      return;
    }
    Get.find<AudioService>().revealMiniPlayer();
    _restoreMiniPlayerWhenStationsClose = false;
  }

  void _showAvailableStations() {
    if (!_sheetCtrl.isAttached) return;
    _sheetCtrl.animateTo(
      _stationsSheetExtent,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _restoreMiniPlayerAfterStations();
    _sheetCtrl.removeListener(_syncSheetExtent);
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppTopBar(
        title: ListenfyLogo(
          size: 28,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      body: AppGradientBackground(
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              // ── Mapa/globo interactivo a pantalla completa ──
              Positioned.fill(
                child: Obx(() {
                  final countries = ctrl.filteredCountries.toList(
                    growable: false,
                  );
                  final selectedCode = ctrl.selectedCountry.value?.code;
                  final mode = ctrl.worldViewMode.value;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.975,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: mode == WorldViewMode.globe
                        ? WorldGlobeCanvas(
                            key: const ValueKey<String>('world-globe'),
                            countries: countries,
                            selectedCountryCode: selectedCode,
                            onCountryTap: ctrl.selectCountry,
                            interactive: true,
                            showHint: false,
                          )
                        : WorldMapCanvas(
                            key: const ValueKey<String>('world-map'),
                            countries: countries,
                            selectedCountryCode: selectedCode,
                            onCountryTap: ctrl.selectCountry,
                            interactive: true,
                            showHint: false,
                          ),
                  );
                }),
              ),

              Positioned(
                top: 12,
                right: 12,
                child: Obx(
                  () => _ViewModeToggle(
                    mode: ctrl.worldViewMode.value,
                    onChanged: ctrl.setWorldViewMode,
                  ),
                ),
              ),

              // La carga de estaciones no modifica el panel: el usuario decide
              // cuándo abrir la lista después de enfocar una región.
              Positioned(
                left: 16,
                right: 16,
                bottom: (constraints.maxHeight * _sheetExtent) + 16,
                child: Obx(() {
                  final country = ctrl.selectedCountry.value;
                  final hasStations = ctrl.stations.isNotEmpty;
                  final isSheetOpen = _sheetExtent >= 0.20;
                  if (country == null || !hasStations || isSheetOpen) {
                    return const SizedBox.shrink();
                  }
                  return FilledButton.icon(
                    onPressed: _showAvailableStations,
                    icon: const Icon(Icons.radio_rounded),
                    label: Text(tr('world_mode.view_available_stations')),
                  );
                }),
              ),

              // ── Panel inferior de estaciones (draggable) ──
              DraggableScrollableSheet(
                controller: _sheetCtrl,
                initialChildSize: _collapsedSheetExtent,
                minChildSize: _collapsedSheetExtent,
                maxChildSize: 0.84,
                snap: true,
                // El mínimo y el máximo ya son puntos de snap implícitos.
                // Solo añadimos la altura de lectura de las estaciones.
                snapSizes: const [_stationsSheetExtent],
                builder: (ctx, scrollCtrl) {
                  return _StationsSheet(
                    ctrl: ctrl,
                    scrollController: scrollCtrl,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 3,
        onTap: _navigateToSection,
      ),
    );
  }

  void _navigateToSection(int index) {
    switch (index) {
      case 0:
        Get.offAllNamed(AppRoutes.home);
        break;
      case 1:
        Get.toNamed(AppRoutes.playlists);
        break;
      case 2:
        Get.toNamed(AppRoutes.artists);
        break;
      case 4:
        Get.toNamed(AppRoutes.downloads);
        break;
      case 5:
        Get.toNamed(AppRoutes.sources);
        break;
    }
  }
}

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.mode, required this.onChanged});

  final WorldViewMode mode;
  final ValueChanged<WorldViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ViewModeButton(
                icon: Icons.public_rounded,
                tooltip: tr('world_mode.view_globe'),
                selected: mode == WorldViewMode.globe,
                onTap: () => onChanged(WorldViewMode.globe),
              ),
              _ViewModeButton(
                icon: Icons.map_rounded,
                tooltip: tr('world_mode.view_map'),
                selected: mode == WorldViewMode.map,
                onTap: () => onChanged(WorldViewMode.map),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.88)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 38,
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: selected ? 1 : 0.74),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANEL INFERIOR DE ESTACIONES
// ─────────────────────────────────────────────────────────────────────────────

class _StationsSheet extends StatelessWidget {
  const _StationsSheet({required this.ctrl, required this.scrollController});

  final WorldModeController ctrl;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: CustomScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Handle ──
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Cabecera: país + shuffle ──
                Obx(() {
                  final country = ctrl.selectedCountry.value;
                  if (country == null) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.explore_rounded,
                            color: scheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr('world_mode.select_region'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final loading = ctrl.isLoadingStations.value;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                country.flag.isEmpty
                                    ? country.localizedName
                                    : '${country.flag}  ${country.localizedName}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                tr(
                                  'world_mode.tracks_count',
                                  args: ['${country.discoveryCount}'],
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Shuffle / regenerar
                        IconButton(
                          onPressed: loading ? null : ctrl.refreshStations,
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: loading
                                ? SizedBox(
                                    key: const ValueKey<String>('loading'),
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.primary,
                                    ),
                                  )
                                : Icon(
                                    key: const ValueKey<String>('shuffle'),
                                    Icons.shuffle_rounded,
                                    color: scheme.primary,
                                  ),
                          ),
                          tooltip: tr('world_mode.shuffle_stations'),
                        ),
                      ],
                    ),
                  );
                }),

                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),

          // ── Lista de estaciones ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: Obx(() {
              final loading = ctrl.isLoadingStations.value;
              final stations = ctrl.stations.toList(growable: false);
              final country = ctrl.selectedCountry.value;

              if (country == null) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }

              if (loading && stations.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (stations.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.radio_outlined,
                            size: 44,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tr('world_mode.no_stations'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((ctx, i) {
                  // índice real (intercalamos separadores)
                  if (i.isOdd) return const SizedBox(height: 12);
                  final station = stations[i ~/ 2];
                  return CountryStationCard(
                    station: station,
                    onPlay: () => ctrl.playStation(station),
                    onContinue: () => ctrl.continueStation(station),
                    onTrackTap: (track) => ctrl.playTrack(station, track),
                  );
                }, childCount: stations.length * 2 - 1),
              );
            }),
          ),
        ],
      ),
    );
  }
}
