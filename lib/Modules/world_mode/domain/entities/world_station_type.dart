import 'package:easy_localization/easy_localization.dart'
    hide StringTranslateExtension;

enum WorldStationType { gateway, essentials, discovery, energy, chill }

extension WorldStationTypeX on WorldStationType {
  String get key {
    switch (this) {
      case WorldStationType.gateway:
        return 'gateway';
      case WorldStationType.essentials:
        return 'essentials';
      case WorldStationType.discovery:
        return 'discovery';
      case WorldStationType.energy:
        return 'energy';
      case WorldStationType.chill:
        return 'chill';
    }
  }

  String get title {
    switch (this) {
      case WorldStationType.gateway:
        return tr('world_mode.station_types.gateway');
      case WorldStationType.essentials:
        return tr('world_mode.station_types.essentials');
      case WorldStationType.discovery:
        return tr('world_mode.station_types.discovery');
      case WorldStationType.energy:
        return tr('world_mode.station_types.energy');
      case WorldStationType.chill:
        return tr('world_mode.station_types.chill');
    }
  }

  static WorldStationType fromKey(String? raw) {
    final key = (raw ?? '').trim().toLowerCase();
    switch (key) {
      case 'gateway':
        return WorldStationType.gateway;
      case 'essentials':
        return WorldStationType.essentials;
      case 'discovery':
        return WorldStationType.discovery;
      case 'energy':
        return WorldStationType.energy;
      case 'chill':
      default:
        return WorldStationType.chill;
    }
  }
}
