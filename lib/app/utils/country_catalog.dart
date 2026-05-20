class CountryOption {
  const CountryOption({
    required this.code,
    required this.name,
    required this.regionKey,
  });

  final String code;
  final String name;
  final String regionKey;
}

class CountryCatalog {
  const CountryCatalog._();

  static const List<CountryOption> all = [
    // Latino
    CountryOption(code: 'AR', name: 'Argentina', regionKey: 'latino'),
    CountryOption(code: 'BO', name: 'Bolivia', regionKey: 'latino'),
    CountryOption(code: 'BR', name: 'Brasil', regionKey: 'latino'),
    CountryOption(code: 'CL', name: 'Chile', regionKey: 'latino'),
    CountryOption(code: 'CO', name: 'Colombia', regionKey: 'latino'),
    CountryOption(code: 'CR', name: 'Costa Rica', regionKey: 'latino'),
    CountryOption(code: 'CU', name: 'Cuba', regionKey: 'latino'),
    CountryOption(code: 'BZ', name: 'Belice', regionKey: 'latino'),
    CountryOption(
      code: 'DO',
      name: 'Republica Dominicana',
      regionKey: 'latino',
    ),
    CountryOption(code: 'EC', name: 'Ecuador', regionKey: 'latino'),
    CountryOption(code: 'SV', name: 'El Salvador', regionKey: 'latino'),
    CountryOption(code: 'GT', name: 'Guatemala', regionKey: 'latino'),
    CountryOption(code: 'HN', name: 'Honduras', regionKey: 'latino'),
    CountryOption(code: 'MX', name: 'Mexico', regionKey: 'latino'),
    CountryOption(code: 'NI', name: 'Nicaragua', regionKey: 'latino'),
    CountryOption(code: 'PA', name: 'Panama', regionKey: 'latino'),
    CountryOption(code: 'PY', name: 'Paraguay', regionKey: 'latino'),
    CountryOption(code: 'PE', name: 'Peru', regionKey: 'latino'),
    CountryOption(code: 'PR', name: 'Puerto Rico', regionKey: 'latino'),
    CountryOption(code: 'HT', name: 'Haiti', regionKey: 'latino'),
    CountryOption(code: 'JM', name: 'Jamaica', regionKey: 'latino'),
    CountryOption(code: 'TT', name: 'Trinidad y Tobago', regionKey: 'latino'),
    CountryOption(code: 'UY', name: 'Uruguay', regionKey: 'latino'),
    CountryOption(code: 'VE', name: 'Venezuela', regionKey: 'latino'),

    // Anglo
    CountryOption(code: 'CA', name: 'Canada', regionKey: 'anglo'),
    CountryOption(code: 'AG', name: 'Antigua y Barbuda', regionKey: 'anglo'),
    CountryOption(code: 'BS', name: 'Bahamas', regionKey: 'anglo'),
    CountryOption(code: 'BB', name: 'Barbados', regionKey: 'anglo'),
    CountryOption(code: 'DM', name: 'Dominica', regionKey: 'anglo'),
    CountryOption(code: 'GD', name: 'Granada', regionKey: 'anglo'),
    CountryOption(code: 'GB', name: 'Reino Unido', regionKey: 'anglo'),
    CountryOption(code: 'IE', name: 'Irlanda', regionKey: 'anglo'),
    CountryOption(
      code: 'KN',
      name: 'San Cristobal y Nieves',
      regionKey: 'anglo',
    ),
    CountryOption(code: 'LC', name: 'Santa Lucia', regionKey: 'anglo'),
    CountryOption(
      code: 'VC',
      name: 'San Vicente y las Granadinas',
      regionKey: 'anglo',
    ),
    CountryOption(code: 'US', name: 'Estados Unidos', regionKey: 'anglo'),

    // Europeo
    CountryOption(code: 'AD', name: 'Andorra', regionKey: 'europeo'),
    CountryOption(code: 'AL', name: 'Albania', regionKey: 'europeo'),
    CountryOption(code: 'AM', name: 'Armenia', regionKey: 'europeo'),
    CountryOption(code: 'AT', name: 'Austria', regionKey: 'europeo'),
    CountryOption(code: 'AZ', name: 'Azerbaiyan', regionKey: 'europeo'),
    CountryOption(
      code: 'BA',
      name: 'Bosnia y Herzegovina',
      regionKey: 'europeo',
    ),
    CountryOption(code: 'BE', name: 'Belgica', regionKey: 'europeo'),
    CountryOption(code: 'BG', name: 'Bulgaria', regionKey: 'europeo'),
    CountryOption(code: 'BY', name: 'Bielorrusia', regionKey: 'europeo'),
    CountryOption(code: 'CH', name: 'Suiza', regionKey: 'europeo'),
    CountryOption(code: 'CY', name: 'Chipre', regionKey: 'europeo'),
    CountryOption(code: 'CZ', name: 'Chequia', regionKey: 'europeo'),
    CountryOption(code: 'DE', name: 'Alemania', regionKey: 'europeo'),
    CountryOption(code: 'DK', name: 'Dinamarca', regionKey: 'europeo'),
    CountryOption(code: 'EE', name: 'Estonia', regionKey: 'europeo'),
    CountryOption(code: 'ES', name: 'Espana', regionKey: 'europeo'),
    CountryOption(code: 'FI', name: 'Finlandia', regionKey: 'europeo'),
    CountryOption(code: 'FR', name: 'Francia', regionKey: 'europeo'),
    CountryOption(code: 'GE', name: 'Georgia', regionKey: 'europeo'),
    CountryOption(code: 'GR', name: 'Grecia', regionKey: 'europeo'),
    CountryOption(code: 'HR', name: 'Croacia', regionKey: 'europeo'),
    CountryOption(code: 'HU', name: 'Hungria', regionKey: 'europeo'),
    CountryOption(code: 'IS', name: 'Islandia', regionKey: 'europeo'),
    CountryOption(code: 'IT', name: 'Italia', regionKey: 'europeo'),
    CountryOption(code: 'LI', name: 'Liechtenstein', regionKey: 'europeo'),
    CountryOption(code: 'LT', name: 'Lituania', regionKey: 'europeo'),
    CountryOption(code: 'LU', name: 'Luxemburgo', regionKey: 'europeo'),
    CountryOption(code: 'LV', name: 'Letonia', regionKey: 'europeo'),
    CountryOption(code: 'MC', name: 'Monaco', regionKey: 'europeo'),
    CountryOption(code: 'MD', name: 'Moldavia', regionKey: 'europeo'),
    CountryOption(code: 'ME', name: 'Montenegro', regionKey: 'europeo'),
    CountryOption(
      code: 'MK',
      name: 'Macedonia del Norte',
      regionKey: 'europeo',
    ),
    CountryOption(code: 'MT', name: 'Malta', regionKey: 'europeo'),
    CountryOption(code: 'NL', name: 'Paises Bajos', regionKey: 'europeo'),
    CountryOption(code: 'NO', name: 'Noruega', regionKey: 'europeo'),
    CountryOption(code: 'PL', name: 'Polonia', regionKey: 'europeo'),
    CountryOption(code: 'PT', name: 'Portugal', regionKey: 'europeo'),
    CountryOption(code: 'RO', name: 'Rumania', regionKey: 'europeo'),
    CountryOption(code: 'RS', name: 'Serbia', regionKey: 'europeo'),
    CountryOption(code: 'RU', name: 'Rusia', regionKey: 'europeo'),
    CountryOption(code: 'SE', name: 'Suecia', regionKey: 'europeo'),
    CountryOption(code: 'SI', name: 'Eslovenia', regionKey: 'europeo'),
    CountryOption(code: 'SK', name: 'Eslovaquia', regionKey: 'europeo'),
    CountryOption(code: 'SM', name: 'San Marino', regionKey: 'europeo'),
    CountryOption(code: 'TR', name: 'Turquia', regionKey: 'europeo'),
    CountryOption(code: 'UA', name: 'Ucrania', regionKey: 'europeo'),
    CountryOption(
      code: 'VA',
      name: 'Ciudad del Vaticano',
      regionKey: 'europeo',
    ),

    // Asiatico
    CountryOption(code: 'AF', name: 'Afganistan', regionKey: 'asiatico'),
    CountryOption(code: 'BD', name: 'Banglades', regionKey: 'asiatico'),
    CountryOption(code: 'BT', name: 'Butan', regionKey: 'asiatico'),
    CountryOption(code: 'BN', name: 'Brunei', regionKey: 'asiatico'),
    CountryOption(code: 'CN', name: 'China', regionKey: 'asiatico'),
    CountryOption(code: 'HK', name: 'Hong Kong', regionKey: 'asiatico'),
    CountryOption(code: 'ID', name: 'Indonesia', regionKey: 'asiatico'),
    CountryOption(code: 'IN', name: 'India', regionKey: 'asiatico'),
    CountryOption(code: 'JP', name: 'Japon', regionKey: 'asiatico'),
    CountryOption(code: 'KH', name: 'Camboya', regionKey: 'asiatico'),
    CountryOption(code: 'LA', name: 'Laos', regionKey: 'asiatico'),
    CountryOption(code: 'LK', name: 'Sri Lanka', regionKey: 'asiatico'),
    CountryOption(code: 'MM', name: 'Myanmar', regionKey: 'asiatico'),
    CountryOption(code: 'MN', name: 'Mongolia', regionKey: 'asiatico'),
    CountryOption(code: 'MO', name: 'Macao', regionKey: 'asiatico'),
    CountryOption(code: 'MV', name: 'Maldivas', regionKey: 'asiatico'),
    CountryOption(code: 'NP', name: 'Nepal', regionKey: 'asiatico'),
    CountryOption(code: 'PK', name: 'Pakistan', regionKey: 'asiatico'),
    CountryOption(code: 'KR', name: 'Corea del Sur', regionKey: 'asiatico'),
    CountryOption(code: 'MY', name: 'Malasia', regionKey: 'asiatico'),
    CountryOption(code: 'PH', name: 'Filipinas', regionKey: 'asiatico'),
    CountryOption(code: 'SG', name: 'Singapur', regionKey: 'asiatico'),
    CountryOption(code: 'TH', name: 'Tailandia', regionKey: 'asiatico'),
    CountryOption(code: 'TL', name: 'Timor Oriental', regionKey: 'asiatico'),
    CountryOption(code: 'TW', name: 'Taiwan', regionKey: 'asiatico'),
    CountryOption(code: 'VN', name: 'Vietnam', regionKey: 'asiatico'),

    // Africano
    CountryOption(code: 'AO', name: 'Angola', regionKey: 'africano'),
    CountryOption(code: 'BF', name: 'Burkina Faso', regionKey: 'africano'),
    CountryOption(code: 'BI', name: 'Burundi', regionKey: 'africano'),
    CountryOption(code: 'BJ', name: 'Benin', regionKey: 'africano'),
    CountryOption(code: 'BW', name: 'Botsuana', regionKey: 'africano'),
    CountryOption(
      code: 'CD',
      name: 'Republica Democratica del Congo',
      regionKey: 'africano',
    ),
    CountryOption(
      code: 'CF',
      name: 'Republica Centroafricana',
      regionKey: 'africano',
    ),
    CountryOption(
      code: 'CG',
      name: 'Republica del Congo',
      regionKey: 'africano',
    ),
    CountryOption(code: 'CI', name: 'Costa de Marfil', regionKey: 'africano'),
    CountryOption(code: 'CM', name: 'Camerun', regionKey: 'africano'),
    CountryOption(code: 'CV', name: 'Cabo Verde', regionKey: 'africano'),
    CountryOption(code: 'DJ', name: 'Yibuti', regionKey: 'africano'),
    CountryOption(code: 'DZ', name: 'Argelia', regionKey: 'africano'),
    CountryOption(code: 'EG', name: 'Egipto', regionKey: 'africano'),
    CountryOption(code: 'ER', name: 'Eritrea', regionKey: 'africano'),
    CountryOption(code: 'ET', name: 'Etiopia', regionKey: 'africano'),
    CountryOption(code: 'GA', name: 'Gabon', regionKey: 'africano'),
    CountryOption(code: 'GH', name: 'Ghana', regionKey: 'africano'),
    CountryOption(code: 'GM', name: 'Gambia', regionKey: 'africano'),
    CountryOption(code: 'GN', name: 'Guinea', regionKey: 'africano'),
    CountryOption(code: 'GQ', name: 'Guinea Ecuatorial', regionKey: 'africano'),
    CountryOption(code: 'GW', name: 'Guinea-Bisau', regionKey: 'africano'),
    CountryOption(code: 'KE', name: 'Kenia', regionKey: 'africano'),
    CountryOption(code: 'KM', name: 'Comoras', regionKey: 'africano'),
    CountryOption(code: 'LR', name: 'Liberia', regionKey: 'africano'),
    CountryOption(code: 'LS', name: 'Lesoto', regionKey: 'africano'),
    CountryOption(code: 'LY', name: 'Libia', regionKey: 'africano'),
    CountryOption(code: 'MA', name: 'Marruecos', regionKey: 'africano'),
    CountryOption(code: 'MG', name: 'Madagascar', regionKey: 'africano'),
    CountryOption(code: 'ML', name: 'Mali', regionKey: 'africano'),
    CountryOption(code: 'MR', name: 'Mauritania', regionKey: 'africano'),
    CountryOption(code: 'MU', name: 'Mauricio', regionKey: 'africano'),
    CountryOption(code: 'MW', name: 'Malaui', regionKey: 'africano'),
    CountryOption(code: 'MZ', name: 'Mozambique', regionKey: 'africano'),
    CountryOption(code: 'NA', name: 'Namibia', regionKey: 'africano'),
    CountryOption(code: 'NE', name: 'Niger', regionKey: 'africano'),
    CountryOption(code: 'NG', name: 'Nigeria', regionKey: 'africano'),
    CountryOption(code: 'RW', name: 'Ruanda', regionKey: 'africano'),
    CountryOption(code: 'SC', name: 'Seychelles', regionKey: 'africano'),
    CountryOption(code: 'SD', name: 'Sudan', regionKey: 'africano'),
    CountryOption(code: 'SN', name: 'Senegal', regionKey: 'africano'),
    CountryOption(code: 'SO', name: 'Somalia', regionKey: 'africano'),
    CountryOption(code: 'SS', name: 'Sudan del Sur', regionKey: 'africano'),
    CountryOption(
      code: 'ST',
      name: 'Santo Tome y Principe',
      regionKey: 'africano',
    ),
    CountryOption(code: 'SZ', name: 'Esuatini', regionKey: 'africano'),
    CountryOption(code: 'TD', name: 'Chad', regionKey: 'africano'),
    CountryOption(code: 'TG', name: 'Togo', regionKey: 'africano'),
    CountryOption(code: 'TN', name: 'Tunez', regionKey: 'africano'),
    CountryOption(code: 'TZ', name: 'Tanzania', regionKey: 'africano'),
    CountryOption(code: 'UG', name: 'Uganda', regionKey: 'africano'),
    CountryOption(code: 'ZA', name: 'Sudafrica', regionKey: 'africano'),
    CountryOption(code: 'ZM', name: 'Zambia', regionKey: 'africano'),
    CountryOption(code: 'ZW', name: 'Zimbabue', regionKey: 'africano'),

    // Medio Oriente
    CountryOption(
      code: 'AE',
      name: 'Emiratos Arabes Unidos',
      regionKey: 'medio_oriente',
    ),
    CountryOption(code: 'BH', name: 'Barein', regionKey: 'medio_oriente'),
    CountryOption(code: 'KZ', name: 'Kazajistan', regionKey: 'medio_oriente'),
    CountryOption(code: 'KG', name: 'Kirguistan', regionKey: 'medio_oriente'),
    CountryOption(code: 'IL', name: 'Israel', regionKey: 'medio_oriente'),
    CountryOption(code: 'IQ', name: 'Irak', regionKey: 'medio_oriente'),
    CountryOption(code: 'IR', name: 'Iran', regionKey: 'medio_oriente'),
    CountryOption(code: 'JO', name: 'Jordania', regionKey: 'medio_oriente'),
    CountryOption(code: 'KW', name: 'Kuwait', regionKey: 'medio_oriente'),
    CountryOption(code: 'LB', name: 'Libano', regionKey: 'medio_oriente'),
    CountryOption(code: 'OM', name: 'Oman', regionKey: 'medio_oriente'),
    CountryOption(code: 'PS', name: 'Palestina', regionKey: 'medio_oriente'),
    CountryOption(code: 'QA', name: 'Qatar', regionKey: 'medio_oriente'),
    CountryOption(
      code: 'SA',
      name: 'Arabia Saudita',
      regionKey: 'medio_oriente',
    ),
    CountryOption(code: 'SY', name: 'Siria', regionKey: 'medio_oriente'),
    CountryOption(code: 'TJ', name: 'Tayikistan', regionKey: 'medio_oriente'),
    CountryOption(code: 'TM', name: 'Turkmenistan', regionKey: 'medio_oriente'),
    CountryOption(code: 'UZ', name: 'Uzbekistan', regionKey: 'medio_oriente'),
    CountryOption(code: 'YE', name: 'Yemen', regionKey: 'medio_oriente'),

    // Oceania
    CountryOption(code: 'AU', name: 'Australia', regionKey: 'oceania'),
    CountryOption(code: 'FM', name: 'Micronesia', regionKey: 'oceania'),
    CountryOption(code: 'FJ', name: 'Fiyi', regionKey: 'oceania'),
    CountryOption(code: 'KI', name: 'Kiribati', regionKey: 'oceania'),
    CountryOption(code: 'MH', name: 'Islas Marshall', regionKey: 'oceania'),
    CountryOption(code: 'NR', name: 'Nauru', regionKey: 'oceania'),
    CountryOption(code: 'NZ', name: 'Nueva Zelanda', regionKey: 'oceania'),
    CountryOption(code: 'PG', name: 'Papua Nueva Guinea', regionKey: 'oceania'),
    CountryOption(code: 'PW', name: 'Palaos', regionKey: 'oceania'),
    CountryOption(code: 'SB', name: 'Islas Salomon', regionKey: 'oceania'),
    CountryOption(code: 'TO', name: 'Tonga', regionKey: 'oceania'),
    CountryOption(code: 'TV', name: 'Tuvalu', regionKey: 'oceania'),
    CountryOption(code: 'VU', name: 'Vanuatu', regionKey: 'oceania'),
    CountryOption(code: 'WS', name: 'Samoa', regionKey: 'oceania'),
  ];

  static final Map<String, CountryOption> _byCode = {
    for (final country in all) country.code: country,
  };

  static final Map<String, CountryOption> _byName = {
    for (final country in all) _normalizeText(country.name): country,
  };

  static CountryOption? findByCode(String? code) {
    final key = (code ?? '').trim().toUpperCase();
    if (key.isEmpty) return null;
    return _byCode[key];
  }

  static CountryOption? findByName(String? name) {
    final key = _normalizeText(name ?? '');
    if (key.isEmpty) return null;
    return _byName[key];
  }

  static String? countryNameFromCode(String? code) {
    return findByCode(code)?.name;
  }

  static String? regionKeyFromCode(String? code) {
    return findByCode(code)?.regionKey;
  }

  static List<CountryOption> byRegion(String regionKey) {
    final key = regionKey.trim().toLowerCase();
    final filtered = all.where((entry) => entry.regionKey == key).toList();
    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return filtered;
  }

  static String flagFromIso(String? countryCode) {
    final code = (countryCode ?? '').trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) return '';
    return String.fromCharCodes(
      code.codeUnits.map((char) => 0x1F1E6 + (char - 0x41)),
    );
  }

  static String _normalizeText(String value) {
    var text = value.trim().toLowerCase();
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    accents.forEach((raw, clean) {
      text = text.replaceAll(raw, clean);
    });
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }
}
