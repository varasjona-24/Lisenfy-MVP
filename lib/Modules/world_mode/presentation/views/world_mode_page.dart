import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/models/media_item.dart';
import '../../../../app/ui/widgets/layout/app_gradient_background.dart';
import '../../controller/world_mode_controller.dart';
import '../../domain/entities/country_entity.dart';
import '../../domain/entities/country_station_entity.dart';
import '../widgets/country_station_card.dart';
import '../widgets/world_map_canvas.dart';

class WorldModePage extends GetView<WorldModeController> {
  const WorldModePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Listenfy Atlas')),
      body: AppGradientBackground(
        child: Obx(() {
          final countries = controller.filteredCountries.toList(
            growable: false,
          );
          final selected = controller.selectedCountry.value;
          final stations = controller.stations.toList(growable: false);
          final loadingCountries = controller.isLoadingCountries.value;
          final loadingStations = controller.isLoadingStations.value;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 980;
              final mapBlock = _MapBlock(
                countries: countries,
                selectedCountry: selected,
                onCountryTap: controller.selectCountry,
                onSearchChanged: controller.setSearchQuery,
                searchQuery: controller.searchQuery.value,
                loadingCountries: loadingCountries,
              );
              final stationBlock = _CountryStationsBlock(
                selectedCountry: selected,
                stations: stations,
                loadingStations: loadingStations,
                expandBody: isWide,
                preferOnline: controller.preferOnline.value,
                onToggleOnline: controller.toggleOnlinePreference,
                onRefresh: controller.refreshStations,
                onPlayStation: controller.playStation,
                onContinueStation: controller.continueStation,
                onPlayTrack: controller.playTrack,
              );

              if (isWide) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                  child: Row(
                    children: [
                      Expanded(flex: 6, child: mapBlock),
                      const SizedBox(width: 12),
                      Expanded(flex: 5, child: stationBlock),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                children: [
                  SizedBox(height: 280, child: mapBlock),
                  const SizedBox(height: 12),
                  stationBlock,
                ],
              );
            },
          );
        }),
      ),
      floatingActionButton: Obx(() {
        final error = controller.errorMessage.value.trim();
        if (error.isEmpty) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: controller.loadCountries,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(error, style: TextStyle(color: scheme.onPrimary)),
        );
      }),
    );
  }
}

class _MapBlock extends StatelessWidget {
  const _MapBlock({
    required this.countries,
    required this.selectedCountry,
    required this.onCountryTap,
    required this.onSearchChanged,
    required this.searchQuery,
    required this.loadingCountries,
  });

  final List<CountryEntity> countries;
  final CountryEntity? selectedCountry;
  final ValueChanged<CountryEntity> onCountryTap;
  final ValueChanged<String> onSearchChanged;
  final String searchQuery;
  final bool loadingCountries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mapa de Regiones',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: ValueKey<String>('world-country-search-$searchQuery'),
              onChanged: onSearchChanged,
              initialValue: searchQuery,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Buscar región...',
                isDense: true,
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: loadingCountries
                  ? const Center(child: CircularProgressIndicator())
                  : WorldMapCanvas(
                      countries: countries,
                      selectedCountryCode: selectedCountry?.code,
                      onCountryTap: onCountryTap,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryStationsBlock extends StatelessWidget {
  const _CountryStationsBlock({
    required this.selectedCountry,
    required this.stations,
    required this.loadingStations,
    required this.expandBody,
    required this.preferOnline,
    required this.onToggleOnline,
    required this.onRefresh,
    required this.onPlayStation,
    required this.onContinueStation,
    required this.onPlayTrack,
  });

  final CountryEntity? selectedCountry;
  final List<CountryStationEntity> stations;
  final bool loadingStations;
  final bool expandBody;
  final bool preferOnline;
  final ValueChanged<bool> onToggleOnline;
  final Future<void> Function() onRefresh;
  final Future<void> Function(CountryStationEntity station) onPlayStation;
  final Future<void> Function(CountryStationEntity station) onContinueStation;
  final Future<void> Function(CountryStationEntity station, MediaItem track)
  onPlayTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final country = selectedCountry;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (country == null)
              Text(
                'Selecciona una región para generar estaciones.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      country.flag.isEmpty
                          ? country.name
                          : '${country.flag} ${country.name}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Regenerar estaciones',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              Text(
                'Macroregión: ${country.regionKey} · Pistas detectadas: ${country.discoveryCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: preferOnline,
                onChanged: onToggleOnline,
                title: const Text('Enriquecimiento online'),
                subtitle: const Text(
                  'Si no hay red, se usa generación local automáticamente.',
                ),
              ),
              const SizedBox(height: 8),
              if (loadingStations)
                (expandBody
                    ? const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      ))
              else if (stations.isEmpty)
                (expandBody
                    ? Expanded(
                        child: Center(
                          child: Text(
                            'No hay estaciones disponibles para esta región todavía.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No hay estaciones disponibles para esta región todavía.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ))
              else
                (expandBody
                    ? Expanded(
                        child: ListView.separated(
                          itemCount: stations.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final station = stations[index];
                            return CountryStationCard(
                              station: station,
                              onPlay: () => onPlayStation(station),
                              onContinue: () => onContinueStation(station),
                              onTrackTap: (track) =>
                                  onPlayTrack(station, track),
                            );
                          },
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: stations.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final station = stations[index];
                          return CountryStationCard(
                            station: station,
                            onPlay: () => onPlayStation(station),
                            onContinue: () => onContinueStation(station),
                            onTrackTap: (track) => onPlayTrack(station, track),
                          );
                        },
                      )),
            ],
          ],
        ),
      ),
    );
  }
}
