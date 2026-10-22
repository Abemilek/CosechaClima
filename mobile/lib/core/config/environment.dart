/// Configuración de compilación de CosechaClima.
///
/// La app es **local-first**: no necesita servidor, cuentas ni variables de
/// entorno para arrancar. Todo lo que el productor registra vive en el teléfono.
class Environment {
  Environment._();

  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  /// Versión visible en la app y en la copia de seguridad.
  static const String version = '2.0.0';

  /// Licencia de la fuente climática. Open-Meteo la exige visible.
  static const String atribucionClima =
      'Datos meteorológicos: Open-Meteo.com (CC BY 4.0)';
}
