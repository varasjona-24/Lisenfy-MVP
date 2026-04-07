class WorldRegionDefinition {
  const WorldRegionDefinition({
    required this.code,
    required this.name,
    required this.continentKey,
    required this.latitude,
    required this.longitude,
    required this.countryCodes,
  });

  final String code;
  final String name;
  final String continentKey;
  final double latitude;
  final double longitude;
  final Set<String> countryCodes;
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
    ),
    WorldRegionDefinition(
      code: 'gran_colombia',
      name: 'Gran Colombia',
      continentKey: 'americas',
      latitude: 6.5,
      longitude: -75.0,
      countryCodes: {'EC', 'CO', 'VE', 'PA'},
    ),
    WorldRegionDefinition(
      code: 'andes_centrales',
      name: 'Andes Centrales',
      continentKey: 'americas',
      latitude: -18.0,
      longitude: -71.0,
      countryCodes: {'PE', 'BO', 'CL'},
    ),
    WorldRegionDefinition(
      code: 'brasil',
      name: 'Brasil',
      continentKey: 'americas',
      latitude: -15.5,
      longitude: -52.0,
      countryCodes: {'BR'},
    ),
    WorldRegionDefinition(
      code: 'mexico',
      name: 'México',
      continentKey: 'americas',
      latitude: 22.0,
      longitude: -102.0,
      countryCodes: {'MX'},
    ),
    WorldRegionDefinition(
      code: 'centroamerica',
      name: 'Centroamérica',
      continentKey: 'americas',
      latitude: 13.0,
      longitude: -88.5,
      countryCodes: {'GT', 'SV', 'HN', 'NI', 'CR'},
    ),
    WorldRegionDefinition(
      code: 'caribe_hispano',
      name: 'Caribe Hispano',
      continentKey: 'americas',
      latitude: 20.5,
      longitude: -71.0,
      countryCodes: {'CU', 'DO', 'PR'},
    ),
    WorldRegionDefinition(
      code: 'caribe_anglo_franco',
      name: 'Caribe Anglo/Francófono',
      continentKey: 'americas',
      latitude: 17.8,
      longitude: -61.5,
      countryCodes: {'JM', 'HT', 'TT', 'BB', 'BS'},
    ),
    WorldRegionDefinition(
      code: 'norteamerica_anglosajona',
      name: 'Norteamérica Anglosajona',
      continentKey: 'americas',
      latitude: 43.0,
      longitude: -95.0,
      countryCodes: {'US', 'CA'},
    ),

    // 🌍 Europa
    WorldRegionDefinition(
      code: 'peninsula_iberica',
      name: 'Península Ibérica',
      continentKey: 'europa',
      latitude: 40.0,
      longitude: -5.0,
      countryCodes: {'ES', 'PT'},
    ),
    WorldRegionDefinition(
      code: 'francia_benelux',
      name: 'Arco Franco-Benelux',
      continentKey: 'europa',
      latitude: 48.8,
      longitude: 3.5,
      countryCodes: {'FR', 'BE', 'NL', 'LU'},
    ),
    WorldRegionDefinition(
      code: 'mundo_germanico',
      name: 'Mundo Germánico',
      continentKey: 'europa',
      latitude: 48.2,
      longitude: 11.0,
      countryCodes: {'DE', 'AT', 'CH'},
    ),
    WorldRegionDefinition(
      code: 'islas_britanicas',
      name: 'Islas Británicas',
      continentKey: 'europa',
      latitude: 53.5,
      longitude: -4.5,
      countryCodes: {'GB', 'IE'},
    ),
    WorldRegionDefinition(
      code: 'europa_nordica',
      name: 'Europa Nórdica',
      continentKey: 'europa',
      latitude: 61.5,
      longitude: 14.0,
      countryCodes: {'NO', 'SE', 'FI', 'DK', 'IS'},
    ),
    WorldRegionDefinition(
      code: 'mediterraneo_occidental',
      name: 'Mediterráneo Occidental',
      continentKey: 'europa',
      latitude: 39.0,
      longitude: 20.0,
      countryCodes: {'IT', 'MT', 'GR', 'CY', 'TR'},
    ),
    WorldRegionDefinition(
      code: 'balcanes',
      name: 'Balcanes',
      continentKey: 'europa',
      latitude: 43.0,
      longitude: 20.0,
      countryCodes: {'RS', 'HR', 'BA', 'ME', 'AL', 'MK', 'XK'},
    ),
    WorldRegionDefinition(
      code: 'europa_central',
      name: 'Europa Central',
      continentKey: 'europa',
      latitude: 49.5,
      longitude: 18.0,
      countryCodes: {'PL', 'CZ', 'SK', 'HU'},
    ),
    WorldRegionDefinition(
      code: 'europa_oriental',
      name: 'Europa Oriental',
      continentKey: 'europa',
      latitude: 50.0,
      longitude: 32.0,
      countryCodes: {'UA', 'BY', 'MD', 'RU', 'RO'},
    ),

    // 🌍 África
    WorldRegionDefinition(
      code: 'magreb',
      name: 'Magreb',
      continentKey: 'africa',
      latitude: 31.5,
      longitude: 4.0,
      countryCodes: {'MA', 'DZ', 'TN', 'LY', 'EG'},
    ),
    WorldRegionDefinition(
      code: 'africa_occidental',
      name: 'África Occidental',
      continentKey: 'africa',
      latitude: 11.5,
      longitude: -2.0,
      countryCodes: {'SN', 'ML', 'CI', 'GH', 'NG'},
    ),
    WorldRegionDefinition(
      code: 'africa_central',
      name: 'África Central',
      continentKey: 'africa',
      latitude: 0.8,
      longitude: 16.0,
      countryCodes: {'CM', 'GA', 'CG', 'CD'},
    ),
    WorldRegionDefinition(
      code: 'africa_oriental',
      name: 'África Oriental',
      continentKey: 'africa',
      latitude: 3.0,
      longitude: 36.0,
      countryCodes: {'ET', 'KE', 'TZ', 'UG'},
    ),
    WorldRegionDefinition(
      code: 'africa_austral',
      name: 'África Austral',
      continentKey: 'africa',
      latitude: -23.0,
      longitude: 24.0,
      countryCodes: {'ZA', 'NA', 'BW', 'ZW', 'ZM'},
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
    ),
    WorldRegionDefinition(
      code: 'asia_central',
      name: 'Asia Central',
      continentKey: 'asia',
      latitude: 42.0,
      longitude: 67.0,
      countryCodes: {'KZ', 'UZ', 'TM', 'KG', 'TJ'},
    ),
    WorldRegionDefinition(
      code: 'subcontinente_indio',
      name: 'Subcontinente Indio',
      continentKey: 'asia',
      latitude: 22.0,
      longitude: 79.0,
      countryCodes: {'IN', 'PK', 'BD', 'NP', 'LK'},
    ),
    WorldRegionDefinition(
      code: 'sudeste_asiatico',
      name: 'Sudeste Asiático',
      continentKey: 'asia',
      latitude: 12.0,
      longitude: 106.0,
      countryCodes: {'TH', 'VN', 'ID', 'MY', 'PH', 'SG', 'KH', 'LA', 'MM'},
    ),
    WorldRegionDefinition(
      code: 'asia_oriental',
      name: 'Asia Oriental',
      continentKey: 'asia',
      latitude: 36.0,
      longitude: 120.0,
      countryCodes: {'CN', 'JP', 'KR', 'KP', 'MN', 'HK', 'TW'},
    ),

    // 🌊 Extra geográfico necesario
    WorldRegionDefinition(
      code: 'oceania_insular',
      name: 'Oceanía',
      continentKey: 'oceania',
      latitude: -22.0,
      longitude: 146.0,
      countryCodes: {'AU', 'NZ', 'FJ', 'PG', 'WS'},
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
