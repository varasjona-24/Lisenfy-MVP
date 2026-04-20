import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../controller/world_mode_controller.dart';
import '../../domain/entities/country_station_entity.dart';
import '../widgets/country_station_card.dart';
import '../widgets/world_map_canvas.dart';

class WorldModePage extends GetView<WorldModeController> {
  const WorldModePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isExpanded = controller.isMapExpanded.value;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 480),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        ),
        child: isExpanded
            ? _ImmersiveAtlasView(
                key: const ValueKey<String>('atlas-immersive'),
                ctrl: controller,
              )
            : _AtlasEntryView(
                key: const ValueKey<String>('atlas-entry'),
                ctrl: controller,
              ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTA DE ENTRADA  (portal animado)
// ─────────────────────────────────────────────────────────────────────────────

class _AtlasEntryView extends StatefulWidget {
  const _AtlasEntryView({super.key, required this.ctrl});

  final WorldModeController ctrl;

  @override
  State<_AtlasEntryView> createState() => _AtlasEntryViewState();
}

class _AtlasEntryViewState extends State<_AtlasEntryView>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _glowCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1900),
      vsync: this,
    )..repeat(reverse: true);

    _glowCtrl = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.3, end: 0.65).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listenfly Atlas'),
        centerTitle: true,
        forceMaterialTransparency: true,
      ),
      body: AppGradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Globo animado ──
                  AnimatedBuilder(
                    animation: Listenable.merge([_pulseAnim, _glowAnim]),
                    builder: (ctx, _) {
                      return Transform.scale(
                        scale: _pulseAnim.value,
                        child: Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                scheme.primary,
                                scheme.primary.withValues(alpha: 0.55),
                                scheme.primary.withValues(alpha: 0.08),
                              ],
                              stops: const [0.0, 0.55, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(
                                  alpha: _glowAnim.value,
                                ),
                                blurRadius: 48,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.public_rounded,
                            size: 86,
                            color: scheme.onPrimary.withValues(alpha: 0.95),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // ── Título ──
                  Text(
                    'Listenfly Atlas',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'Explora tu música a través del mundo.\nSelecciona una región en el mapa y genera estaciones de radio personalizadas con tus canciones.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Botón explorar ──
                  Obx(() {
                    final loading = widget.ctrl.isLoadingCountries.value;
                    return FilledButton.icon(
                      onPressed:
                          loading ? null : () => widget.ctrl.setMapExpanded(true),
                      icon: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.explore_rounded, size: 22),
                      label: Text(
                        loading ? 'Cargando regiones…' : 'Explorar Atlas',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(230, 58),
                        shape: const StadiumBorder(),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 22),

                  // ── Chip de regiones disponibles ──
                  Obx(() {
                    final count = widget.ctrl.countries.length;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.55,
                        ),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '$count regiones con música disponible',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTA INMERSIVA estilo Radio Garden
// ─────────────────────────────────────────────────────────────────────────────

class _ImmersiveAtlasView extends StatefulWidget {
  const _ImmersiveAtlasView({super.key, required this.ctrl});

  final WorldModeController ctrl;

  @override
  State<_ImmersiveAtlasView> createState() => _ImmersiveAtlasViewState();
}

class _ImmersiveAtlasViewState extends State<_ImmersiveAtlasView> {
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();
  StreamSubscription<List<CountryStationEntity>>? _stationsSub;

  @override
  void initState() {
    super.initState();
    // Cuando cargan estaciones → expandir el panel inferior automáticamente
    _stationsSub = widget.ctrl.stations.listen((stations) {
      if (!mounted || stations.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sheetCtrl.isAttached) {
          _sheetCtrl.animateTo(
            0.40,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _stationsSub?.cancel();
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Mapa interactivo a pantalla completa ──
          Positioned.fill(
            child: Obx(
              () => WorldMapCanvas(
                countries: ctrl.filteredCountries.toList(growable: false),
                selectedCountryCode: ctrl.selectedCountry.value?.code,
                onCountryTap: ctrl.selectCountry,
                interactive: true,
                showHint: false,
              ),
            ),
          ),

          // ── Barra superior con blur ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(ctrl: ctrl, topPadding: topPadding),
          ),

          // ── Panel inferior de estaciones (draggable) ──
          DraggableScrollableSheet(
            controller: _sheetCtrl,
            initialChildSize: 0.08,
            minChildSize: 0.05,
            maxChildSize: 0.84,
            snap: true,
            snapSizes: const [0.08, 0.40, 0.84],
            builder: (ctx, scrollCtrl) {
              return _StationsSheet(
                ctrl: ctrl,
                scrollController: scrollCtrl,
                onSearchTap: () => _showSearchSheet(context),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchRegionSheet(ctrl: widget.ctrl),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BARRA SUPERIOR CON BLUR
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.ctrl, required this.topPadding});

  final WorldModeController ctrl;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.fromLTRB(12, topPadding + 6, 12, 12),
          color: Colors.black.withValues(alpha: 0.38),
          child: Row(
            children: [
              // ── Botón volver ──
              _BarButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => ctrl.setMapExpanded(false),
              ),
              const SizedBox(width: 10),

              // ── Título + región seleccionada ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Listenfly Atlas',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Obx(() {
                      final country = ctrl.selectedCountry.value;
                      return Text(
                        country == null
                            ? 'Toca un punto para explorar'
                            : '${country.flag.isEmpty ? '' : '${country.flag} '}${country.name}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                  ],
                ),
              ),

              // ── Botón buscar región ──
              _BarButton(
                icon: Icons.search_rounded,
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _SearchRegionSheet(ctrl: ctrl),
                  );
                },
              ),
              const SizedBox(width: 8),

              // ── Toggle online / offline ──
              Obx(() {
                final online = ctrl.preferOnline.value;
                return _BarButton(
                  icon: online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  onTap: () => ctrl.toggleOnlinePreference(!online),
                  active: online,
                  activeColor: scheme.primary,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? (activeColor ?? Colors.white).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.14);
    final iconColor = active ? Colors.white : Colors.white;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: iconColor, size: 21),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANEL INFERIOR DE ESTACIONES
// ─────────────────────────────────────────────────────────────────────────────

class _StationsSheet extends StatelessWidget {
  const _StationsSheet({
    required this.ctrl,
    required this.scrollController,
    required this.onSearchTap,
  });

  final WorldModeController ctrl;
  final ScrollController scrollController;
  final VoidCallback onSearchTap;

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
                              'Selecciona una región en el mapa',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Botón buscar dentro del panel
                          IconButton(
                            icon: const Icon(Icons.search_rounded),
                            onPressed: onSearchTap,
                            tooltip: 'Buscar región',
                            style: IconButton.styleFrom(
                              foregroundColor: scheme.primary,
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
                                    ? country.name
                                    : '${country.flag}  ${country.name}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${country.regionKey.toUpperCase()} · ${country.discoveryCount} pistas',
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
                          tooltip: 'Aleatorizar estaciones',
                        ),
                        IconButton(
                          onPressed: onSearchTap,
                          icon: Icon(
                            Icons.search_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                          tooltip: 'Buscar región',
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
                            'Sin estaciones para esta región todavía.',
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
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    // índice real (intercalamos separadores)
                    if (i.isOdd) return const SizedBox(height: 12);
                    final station = stations[i ~/ 2];
                    return CountryStationCard(
                      station: station,
                      onPlay: () => ctrl.playStation(station),
                      onContinue: () => ctrl.continueStation(station),
                      onTrackTap: (track) => ctrl.playTrack(station, track),
                    );
                  },
                  childCount: stations.length * 2 - 1,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUSCADOR DE REGIÓN (bottom sheet modal)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchRegionSheet extends StatefulWidget {
  const _SearchRegionSheet({required this.ctrl});

  final WorldModeController ctrl;

  @override
  State<_SearchRegionSheet> createState() => _SearchRegionSheetState();
}

class _SearchRegionSheetState extends State<_SearchRegionSheet> {
  final TextEditingController _textCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textCtrl.text = widget.ctrl.searchQuery.value;
  }

  @override
  void dispose() {
    widget.ctrl.setSearchQuery('');
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: Container(
        color: scheme.surface,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Handle
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Campo de búsqueda
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _textCtrl,
                autofocus: true,
                onChanged: widget.ctrl.setSearchQuery,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Buscar región…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Lista de resultados
            SizedBox(
              height: 300,
              child: Obx(() {
                final countries = widget.ctrl.filteredCountries.toList(
                  growable: false,
                );
                if (countries.isEmpty) {
                  return Center(
                    child: Text(
                      'Sin resultados',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: countries.length,
                  itemBuilder: (ctx, i) {
                    final c = countries[i];
                    final isSelected =
                        widget.ctrl.selectedCountry.value?.code == c.code;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: scheme.primaryContainer.withValues(
                        alpha: 0.35,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Text(
                        c.flag.isEmpty ? '🌍' : c.flag,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        c.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text('${c.discoveryCount} pistas disponibles'),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: scheme.primary,
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.ctrl.selectCountry(c);
                      },
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
