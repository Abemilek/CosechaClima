import 'package:flutter/foundation.dart';

import '../../data/models/catalogo.dart';
import '../../data/services/catalogo_service.dart';

/// Carga una sola vez los catálogos locales (cultivos, suelos, etapas y
/// eventos climáticos) y los comparte con el asistente, la bitácora y el
/// detalle de parcela.
class CatalogoViewModel extends ChangeNotifier {
  CatalogoViewModel(this._service);

  final CatalogoService _service;

  List<Cultivo> _cultivos = [];
  List<TipoSuelo> _tiposSuelo = [];
  List<EtapaFenologica> _etapas = [];
  List<EventoClimatico> _eventos = [];

  bool _cargando = false;
  String? _error;
  bool _cargado = false;

  List<Cultivo> get cultivos => _cultivos;
  List<TipoSuelo> get tiposSuelo => _tiposSuelo;
  List<EtapaFenologica> get etapas => _etapas;
  List<EventoClimatico> get eventosClimaticos => _eventos;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get cargado => _cargado;

  Cultivo? cultivoPorId(int id) {
    for (final cultivo in _cultivos) {
      if (cultivo.id == id) return cultivo;
    }
    return null;
  }

  TipoSuelo? sueloPorId(int id) {
    for (final suelo in _tiposSuelo) {
      if (suelo.id == id) return suelo;
    }
    return null;
  }

  EtapaFenologica? etapaPorId(int? id) {
    if (id == null) return null;
    for (final etapa in _etapas) {
      if (etapa.id == id) return etapa;
    }
    return null;
  }

  Future<void> cargarCatalogos({bool forzar = false}) async {
    if (_cargando || (_cargado && !forzar)) return;
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      final resultados = await Future.wait([
        _service.obtenerCultivos(),
        _service.obtenerTiposSuelo(),
        _service.obtenerEtapasFenologicas(),
        _service.obtenerEventosClimaticos(),
      ]);
      _cultivos = resultados[0] as List<Cultivo>;
      _tiposSuelo = resultados[1] as List<TipoSuelo>;
      _etapas = resultados[2] as List<EtapaFenologica>;
      _eventos = resultados[3] as List<EventoClimatico>;
      _cargado = true;
    } catch (e) {
      _error = 'No se pudieron cargar los catálogos locales: $e';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}
