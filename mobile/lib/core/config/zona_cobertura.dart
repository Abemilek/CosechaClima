class ZonaCobertura {
  ZonaCobertura._();

  static const double latitudMinima = 11.55;
  static const double latitudMaxima = 11.95;
  static const double longitudMinima = -86.45;
  static const double longitudMaxima = -86.05;

  static bool estaDentroDeCarazo(double? latitud, double? longitud) {
    if (latitud == null || longitud == null) return false;

    return latitud >= latitudMinima &&
        latitud <= latitudMaxima &&
        longitud >= longitudMinima &&
        longitud <= longitudMaxima;
  }
}
