class WorldExploreOptions {
  const WorldExploreOptions({
    this.preferOnline = true,
    this.forceRefresh = false,
    this.tracksPerStation = 30,
    this.maxStations = 4,
  });

  final bool preferOnline;
  final bool forceRefresh;
  final int tracksPerStation;
  final int maxStations;
}
