class ZonaCobertura {
  ZonaCobertura._();

  static const double latitudMinima = 10.70;
  static const double latitudMaxima = 15.03;
  static const double longitudMinima = -87.70;
  static const double longitudMaxima = -82.70;

  static bool estaDentroDeNicaragua(double? latitud, double? longitud) {
    if (latitud == null || longitud == null) return false;

    return latitud >= latitudMinima &&
        latitud <= latitudMaxima &&
        longitud >= longitudMinima &&
        longitud <= longitudMaxima;
  }

  static bool estaDentroDeCarazo(double? latitud, double? longitud) =>
      estaDentroDeNicaragua(latitud, longitud);
}
