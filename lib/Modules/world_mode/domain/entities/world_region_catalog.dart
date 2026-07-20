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
      mapX: 0.336,
      mapY: 0.699,
    ),
    WorldRegionDefinition(
      code: 'gran_colombia',
      name: 'Gran Colombia',
      continentKey: 'americas',
      latitude: 6.5,
      longitude: -75.0,
      countryCodes: {'EC', 'CO', 'VE', 'PA'},
      mapX: 0.299,
      mapY: 0.477,
    ),
    WorldRegionDefinition(
      code: 'andes_centrales',
      name: 'Andes Centrales',
      continentKey: 'americas',
      latitude: -18.0,
      longitude: -71.0,
      countryCodes: {'PE', 'BO', 'CL'},
      mapX: 0.315,
      mapY: 0.632,
    ),
    WorldRegionDefinition(
      code: 'brasil',
      name: 'Brasil',
      continentKey: 'americas',
      latitude: -15.5,
      longitude: -52.0,
      countryCodes: {'BR'},
      mapX: 0.365,
      mapY: 0.548,
    ),
    WorldRegionDefinition(
      code: 'mexico',
      name: 'México',
      continentKey: 'americas',
      latitude: 22.0,
      longitude: -102.0,
      countryCodes: {'MX'},
      mapX: 0.216,
      mapY: 0.374,
    ),
    WorldRegionDefinition(
      code: 'centroamerica',
      name: 'Centroamérica',
      continentKey: 'americas',
      latitude: 13.0,
      longitude: -88.5,
      countryCodes: {'GT', 'SV', 'HN', 'NI', 'CR', 'BZ'},
      mapX: 0.254,
      mapY: 0.415,
    ),
    WorldRegionDefinition(
      code: 'caribe_hispano',
      name: 'Caribe Hispano',
      continentKey: 'americas',
      latitude: 20.5,
      longitude: -71.0,
      countryCodes: {'CU', 'DO', 'PR'},
      mapX: 0.306,
      mapY: 0.384,
    ),
    WorldRegionDefinition(
      code: 'caribe_anglo_franco',
      name: 'Caribe Anglo/Francófono',
      continentKey: 'americas',
      latitude: 17.8,
      longitude: -61.5,
      countryCodes: {
        'JM',
        'HT',
        'TT',
        'BB',
        'BS',
        'AG',
        'DM',
        'GD',
        'KN',
        'LC',
        'VC',
      },
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
      code: 'europa_occidental',
      name: 'Europa Occidental',
      continentKey: 'europa',
      latitude: 47.0,
      longitude: 4.0,
      countryCodes: {
        'ES',
        'PT',
        'AD',
        'FR',
        'BE',
        'NL',
        'LU',
        'MC',
        'DE',
        'AT',
        'CH',
        'LI',
      },
      mapX: 0.515,
      mapY: 0.245,
    ),
    WorldRegionDefinition(
      code: 'islas_britanicas',
      name: 'Islas Británicas',
      continentKey: 'europa',
      latitude: 53.5,
      longitude: -4.5,
      countryCodes: {'GB', 'IE'},
      mapX: 0.491,
      mapY: 0.186,
    ),
    WorldRegionDefinition(
      code: 'europa_nordica_baltica',
      name: 'Europa Nórdica y Báltica',
      continentKey: 'europa',
      latitude: 59.5,
      longitude: 18.0,
      countryCodes: {'NO', 'SE', 'FI', 'DK', 'IS', 'EE', 'LT', 'LV'},
      mapX: 0.539,
      mapY: 0.158,
    ),
    WorldRegionDefinition(
      code: 'europa_mediterranea_balcanica',
      name: 'Europa Mediterránea y Balcánica',
      continentKey: 'europa',
      latitude: 41.0,
      longitude: 20.0,
      countryCodes: {
        'IT',
        'MT',
        'GR',
        'CY',
        'TR',
        'SM',
        'RS',
        'HR',
        'BA',
        'ME',
        'AL',
        'MK',
        'XK',
        'BG',
        'SI',
        'VA',
      },
      mapX: 0.556,
      mapY: 0.285,
    ),
    WorldRegionDefinition(
      code: 'europa_oriental_caucaso',
      name: 'Europa Oriental y Cáucaso',
      continentKey: 'europa',
      latitude: 48.0,
      longitude: 32.0,
      countryCodes: {
        'PL',
        'CZ',
        'SK',
        'HU',
        'UA',
        'BY',
        'MD',
        'RU',
        'RO',
        'AM',
        'AZ',
        'GE',
      },
      mapX: 0.568,
      mapY: 0.215,
    ),

    // 🌍 África
    WorldRegionDefinition(
      code: 'magreb',
      name: 'Magreb',
      continentKey: 'africa',
      latitude: 31.5,
      longitude: 4.0,
      countryCodes: {'MA', 'DZ', 'TN', 'LY', 'EG', 'MR', 'SD'},
      mapX: 0.532,
      mapY: 0.341,
    ),
    WorldRegionDefinition(
      code: 'africa_occidental',
      name: 'África Occidental',
      continentKey: 'africa',
      latitude: 11.5,
      longitude: -2.0,
      countryCodes: {
        'SN',
        'ML',
        'CI',
        'GH',
        'NG',
        'BF',
        'BJ',
        'CV',
        'GM',
        'GN',
        'GW',
        'LR',
        'NE',
        'TG',
      },
      mapX: 0.504,
      mapY: 0.413,
    ),
    WorldRegionDefinition(
      code: 'africa_central',
      name: 'África Central',
      continentKey: 'africa',
      latitude: 0.8,
      longitude: 16.0,
      countryCodes: {'CM', 'GA', 'CG', 'CD', 'AO', 'CF', 'GQ', 'ST', 'TD'},
      mapX: 0.551,
      mapY: 0.498,
    ),
    WorldRegionDefinition(
      code: 'africa_oriental',
      name: 'África Oriental',
      continentKey: 'africa',
      latitude: 3.0,
      longitude: 36.0,
      countryCodes: {
        'ET',
        'KE',
        'TZ',
        'UG',
        'BI',
        'DJ',
        'ER',
        'KM',
        'MG',
        'MU',
        'RW',
        'SC',
        'SO',
        'SS',
      },
      mapX: 0.613,
      mapY: 0.471,
    ),
    WorldRegionDefinition(
      code: 'africa_austral',
      name: 'África Austral',
      continentKey: 'africa',
      latitude: -23.0,
      longitude: 24.0,
      countryCodes: {'ZA', 'NA', 'BW', 'ZW', 'ZM', 'LS', 'MW', 'MZ', 'SZ'},
      mapX: 0.595,
      mapY: 0.623,
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
        'AF',
      },
      mapX: 0.630,
      mapY: 0.280,
    ),
    WorldRegionDefinition(
      code: 'asia_central',
      name: 'Asia Central',
      continentKey: 'asia',
      latitude: 42.0,
      longitude: 67.0,
      countryCodes: {'KZ', 'UZ', 'TM', 'KG', 'TJ'},
      mapX: 0.681,
      mapY: 0.226,
    ),
    WorldRegionDefinition(
      code: 'subcontinente_indio',
      name: 'Subcontinente Indio',
      continentKey: 'asia',
      latitude: 22.0,
      longitude: 79.0,
      countryCodes: {'IN', 'PK', 'BD', 'NP', 'LK', 'BT', 'MV'},
      mapX: 0.731,
      mapY: 0.361,
    ),
    WorldRegionDefinition(
      code: 'sudeste_asiatico',
      name: 'Sudeste Asiático',
      continentKey: 'asia',
      latitude: 12.0,
      longitude: 106.0,
      countryCodes: {
        'TH',
        'VN',
        'ID',
        'MY',
        'PH',
        'SG',
        'KH',
        'LA',
        'MM',
        'BN',
        'TL',
      },
      mapX: 0.792,
      mapY: 0.430,
    ),
    WorldRegionDefinition(
      code: 'asia_oriental',
      name: 'Asia Oriental',
      continentKey: 'asia',
      latitude: 36.0,
      longitude: 120.0,
      countryCodes: {'CN', 'JP', 'KR', 'KP', 'MN', 'HK', 'TW', 'MO'},
      mapX: 0.842,
      mapY: 0.288,
    ),

    // 🌊 Extra geográfico necesario
    WorldRegionDefinition(
      code: 'oceania_insular',
      name: 'Oceanía',
      continentKey: 'oceania',
      latitude: -22.0,
      longitude: 146.0,
      countryCodes: {
        'AU',
        'NZ',
        'FJ',
        'PG',
        'WS',
        'FM',
        'KI',
        'MH',
        'NR',
        'PW',
        'SB',
        'TO',
        'TV',
        'VU',
      },
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
