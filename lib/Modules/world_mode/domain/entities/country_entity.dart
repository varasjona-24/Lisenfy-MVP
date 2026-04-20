import '../../../../app/utils/country_catalog.dart';

class CountryEntity {
  const CountryEntity({
    required this.code,
    required this.name,
    required this.regionKey,
    required this.latitude,
    required this.longitude,
    required this.mapX,
    required this.mapY,
    this.discoveryCount = 0,
  });

  final String code;
  final String name;
  final String regionKey;
  final double latitude;
  final double longitude;
  // Coordenadas normalizadas (0..1) sobre el mapa renderizado.
  // Fuente de verdad visual del punto.
  final double mapX;
  final double mapY;
  final int discoveryCount;

  String get flag => CountryCatalog.flagFromIso(code);

  CountryEntity copyWith({
    String? code,
    String? name,
    String? regionKey,
    double? latitude,
    double? longitude,
    double? mapX,
    double? mapY,
    int? discoveryCount,
  }) {
    return CountryEntity(
      code: code ?? this.code,
      name: name ?? this.name,
      regionKey: regionKey ?? this.regionKey,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      mapX: mapX ?? this.mapX,
      mapY: mapY ?? this.mapY,
      discoveryCount: discoveryCount ?? this.discoveryCount,
    );
  }
}
