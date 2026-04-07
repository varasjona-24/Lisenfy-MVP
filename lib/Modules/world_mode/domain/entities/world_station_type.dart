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
        return 'Puerta de entrada';
      case WorldStationType.essentials:
        return 'Esenciales';
      case WorldStationType.discovery:
        return 'Descubrimiento';
      case WorldStationType.energy:
        return 'Energía alta';
      case WorldStationType.chill:
        return 'Chill / Noche';
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
