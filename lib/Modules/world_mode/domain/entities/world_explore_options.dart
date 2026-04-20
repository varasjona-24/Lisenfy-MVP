class WorldExploreOptions {
  const WorldExploreOptions({
    this.preferOnline = true,
    this.forceRefresh = false,
    this.tracksPerStation = 30,
    this.maxStations = 4,
    this.shuffleSeed,
  });

  final bool preferOnline;
  final bool forceRefresh;
  final int tracksPerStation;
  final int maxStations;

  /// Seed para aleatorizar el orden de pistas dentro de cada estación.
  /// Si es null, se usa el timestamp actual como seed.
  final int? shuffleSeed;
}
