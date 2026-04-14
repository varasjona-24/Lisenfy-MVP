class WorldRegionDefinition {
  const WorldRegionDefinition({
    required this.code,
    required this.name,
    required this.continentKey,
    required this.latitude,
    required this.longitude,
    required this.countryCodes,
    required this.mapX,
    required this.mapY,
  });

  final String code;
  final String name;
  final String continentKey;
  final double latitude;
  final double longitude;
  final Set<String> countryCodes;
  final double mapX;
  final double mapY;
}

class WorldRegionCatalog {
  const WorldRegionCatalog._();

  static const List<WorldRegionDefinition> all = [
    // 🌎 América
    WorldRegionDefinition(
      code: 'rio_plata',
      name: 'Río de la Plata',
      continentKey: 'americas',
      latitude: -31.0,
      longitude: -58.5,
      countryCodes: {'AR', 'UY', 'PY'},
      mapX: 0.297,
      mapY: 0.777,
    ),
    WorldRegionDefinition(
      code: 'gran_colombia',
      name: 'Gran Colombia',
      continentKey: 'americas',
      latitude: 6.5,
      longitude: -75.0,
      countryCodes: {'EC', 'CO', 'VE', 'PA'},
      mapX: 0.268,
      mapY: 0.544,
    ),
    WorldRegionDefinition(
      code: 'andes_centrales',
      name: 'Andes Centrales',
      continentKey: 'americas',
      latitude: -18.0,
      longitude: -71.0,
      countryCodes: {'PE', 'BO', 'CL'},
      mapX: 0.250,
      mapY: 0.647,
    ),
    WorldRegionDefinition(
      code: 'brasil',
      name: 'Brasil',
      continentKey: 'americas',
      latitude: -15.5,
      longitude: -52.0,
      countryCodes: {'BR'},
      mapX: 0.356,
      mapY: 0.586,
    ),
    WorldRegionDefinition(
      code: 'mexico',
      name: 'México',
      continentKey: 'americas',
      latitude: 22.0,
      longitude: -102.0,
      countryCodes: {'MX'},
      mapX: 0.184,
      mapY: 0.425,
    ),
    WorldRegionDefinition(
      code: 'centroamerica',
      name: 'Centroamérica',
      continentKey: 'americas',
      latitude: 13.0,
      longitude: -88.5,
      countryCodes: {'GT', 'SV', 'HN', 'NI', 'CR'},
      mapX: 0.254,
      mapY: 0.428,
    ),
    WorldRegionDefinition(
      code: 'caribe_hispano',
      name: 'Caribe Hispano',
      continentKey: 'americas',
      latitude: 20.5,
      longitude: -71.0,
      countryCodes: {'CU', 'DO', 'PR'},
      mapX: 0.276,
      mapY: 0.429,
    ),
    WorldRegionDefinition(
      code: 'caribe_anglo_franco',
      name: 'Caribe Anglo/Francófono',
      continentKey: 'americas',
      latitude: 17.8,
      longitude: -61.5,
      countryCodes: {'JM', 'HT', 'TT', 'BB', 'BS'},
      mapX: 0.329,
      mapY: 0.401,
    ),
    WorldRegionDefinition(
      code: 'norteamerica_anglosajona',
      name: 'Norteamérica Anglosajona',
      continentKey: 'americas',
      latitude: 43.0,
      longitude: -95.0,
      countryCodes: {'US', 'CA'},
      mapX: 0.236,
      mapY: 0.261,
    ),

    // 🌍 Europa
    WorldRegionDefinition(
      code: 'peninsula_iberica',
      name: 'Península Ibérica',
      continentKey: 'europa',
      latitude: 40.0,
      longitude: -5.0,
      countryCodes: {'ES', 'PT'},
      mapX: 0.459,
      mapY: 0.322,
    ),
    WorldRegionDefinition(
      code: 'francia_benelux',
      name: 'Arco Franco-Benelux',
      continentKey: 'europa',
      latitude: 48.8,
      longitude: 3.5,
      countryCodes: {'FR', 'BE', 'NL', 'LU'},
      mapX: 0.494,
      mapY: 0.272,
    ),
    WorldRegionDefinition(
      code: 'mundo_germanico',
      name: 'Mundo Germánico',
      continentKey: 'europa',
      latitude: 48.2,
      longitude: 11.0,
      countryCodes: {'DE', 'AT', 'CH'},
      mapX: 0.531,
      mapY: 0.232,
    ),
    WorldRegionDefinition(
      code: 'islas_britanicas',
      name: 'Islas Británicas',
      continentKey: 'europa',
      latitude: 53.5,
      longitude: -4.5,
      countryCodes: {'GB', 'IE'},
      mapX: 0.454,
      mapY: 0.209,
    ),
    WorldRegionDefinition(
      code: 'europa_nordica',
      name: 'Europa Nórdica',
      continentKey: 'europa',
      latitude: 61.5,
      longitude: 14.0,
      countryCodes: {'NO', 'SE', 'FI', 'DK', 'IS'},
      mapX: 0.539,
      mapY: 0.158,
    ),
    WorldRegionDefinition(
      code: 'mediterraneo_occidental',
      name: 'Mediterráneo Occidental',
      continentKey: 'europa',
      latitude: 39.0,
      longitude: 20.0,
      countryCodes: {'IT', 'MT', 'GR', 'CY', 'TR'},
      mapX: 0.523,
      mapY: 0.334,
    ),
    WorldRegionDefinition(
      code: 'balcanes',
      name: 'Balcanes',
      continentKey: 'europa',
      latitude: 43.0,
      longitude: 20.0,
      countryCodes: {'RS', 'HR', 'BA', 'ME', 'AL', 'MK', 'XK'},
      mapX: 0.556,
      mapY: 0.261,
    ),
    WorldRegionDefinition(
      code: 'europa_central',
      name: 'Europa Central',
      continentKey: 'europa',
      latitude: 49.5,
      longitude: 18.0,
      countryCodes: {'PL', 'CZ', 'SK', 'HU'},
      mapX: 0.550,
      mapY: 0.225,
    ),
    WorldRegionDefinition(
      code: 'europa_oriental',
      name: 'Europa Oriental',
      continentKey: 'europa',
      latitude: 50.0,
      longitude: 32.0,
      countryCodes: {'UA', 'BY', 'MD', 'RU', 'RO'},
      mapX: 0.589,
      mapY: 0.222,
    ),

    // 🌍 África
    WorldRegionDefinition(
      code: 'magreb',
      name: 'Magreb',
      continentKey: 'africa',
      latitude: 31.5,
      longitude: 4.0,
      countryCodes: {'MA', 'DZ', 'TN', 'LY', 'EG'},
      mapX: 0.511,
      mapY: 0.325,
    ),
    WorldRegionDefinition(
      code: 'africa_occidental',
      name: 'África Occidental',
      continentKey: 'africa',
      latitude: 11.5,
      longitude: -2.0,
      countryCodes: {'SN', 'ML', 'CI', 'GH', 'NG'},
      mapX: 0.494,
      mapY: 0.436,
    ),
    WorldRegionDefinition(
      code: 'africa_central',
      name: 'África Central',
      continentKey: 'africa',
      latitude: 0.8,
      longitude: 16.0,
      countryCodes: {'CM', 'GA', 'CG', 'CD'},
      mapX: 0.544,
      mapY: 0.496,
    ),
    WorldRegionDefinition(
      code: 'africa_oriental',
      name: 'África Oriental',
      continentKey: 'africa',
      latitude: 3.0,
      longitude: 36.0,
      countryCodes: {'ET', 'KE', 'TZ', 'UG'},
      mapX: 0.600,
      mapY: 0.483,
    ),
    WorldRegionDefinition(
      code: 'africa_austral',
      name: 'África Austral',
      continentKey: 'africa',
      latitude: -23.0,
      longitude: 24.0,
      countryCodes: {'ZA', 'NA', 'BW', 'ZW', 'ZM'},
      mapX: 0.567,
      mapY: 0.628,
    ),

    // 🌏 Asia
    WorldRegionDefinition(
      code: 'medio_oriente',
      name: 'Medio Oriente',
      continentKey: 'asia',
      latitude: 28.5,
      longitude: 44.0,
      countryCodes: {
        'SA',
        'AE',
        'QA',
        'KW',
        'OM',
        'JO',
        'IL',
        'IQ',
        'SY',
        'LB',
        'YE',
        'IR',
        'BH',
        'PS',
      },
      mapX: 0.622,
      mapY: 0.342,
    ),
    WorldRegionDefinition(
      code: 'asia_central',
      name: 'Asia Central',
      continentKey: 'asia',
      latitude: 42.0,
      longitude: 67.0,
      countryCodes: {'KZ', 'UZ', 'TM', 'KG', 'TJ'},
      mapX: 0.686,
      mapY: 0.267,
    ),
    WorldRegionDefinition(
      code: 'subcontinente_indio',
      name: 'Subcontinente Indio',
      continentKey: 'asia',
      latitude: 22.0,
      longitude: 79.0,
      countryCodes: {'IN', 'PK', 'BD', 'NP', 'LK'},
      mapX: 0.719,
      mapY: 0.378,
    ),
    WorldRegionDefinition(
      code: 'sudeste_asiatico',
      name: 'Sudeste Asiático',
      continentKey: 'asia',
      latitude: 12.0,
      longitude: 106.0,
      countryCodes: {'TH', 'VN', 'ID', 'MY', 'PH', 'SG', 'KH', 'LA', 'MM'},
      mapX: 0.794,
      mapY: 0.433,
    ),
    WorldRegionDefinition(
      code: 'asia_oriental',
      name: 'Asia Oriental',
      continentKey: 'asia',
      latitude: 36.0,
      longitude: 120.0,
      countryCodes: {'CN', 'JP', 'KR', 'KP', 'MN', 'HK', 'TW'},
      mapX: 0.797,
      mapY: 0.340,
    ),

    // 🌊 Extra geográfico necesario
    WorldRegionDefinition(
      code: 'oceania_insular',
      name: 'Oceanía',
      continentKey: 'oceania',
      latitude: -22.0,
      longitude: 146.0,
      countryCodes: {'AU', 'NZ', 'FJ', 'PG', 'WS'},
      mapX: 0.906,
      mapY: 0.622,
    ),
  ];

  static final Map<String, WorldRegionDefinition> _byCode = {
    for (final region in all) region.code: region,
  };

  static final Map<String, Set<String>> _regionsByCountryCode = () {
    final map = <String, Set<String>>{};
    for (final region in all) {
      for (final country in region.countryCodes) {
        final code = country.trim().toUpperCase();
        if (code.isEmpty) continue;
        map.putIfAbsent(code, () => <String>{}).add(region.code);
      }
    }
    return map;
  }();

  static WorldRegionDefinition? byCode(String? regionCode) {
    final code = (regionCode ?? '').trim();
    if (code.isEmpty) return null;
    return _byCode[code];
  }

  static Set<String> regionCodesForCountry(String? countryCode) {
    final code = (countryCode ?? '').trim().toUpperCase();
    if (code.isEmpty) return const <String>{};
    return _regionsByCountryCode[code] ?? const <String>{};
  }
}
