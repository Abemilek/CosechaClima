import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/cache/guest_parcela_store.dart';
import '../../../../core/cache/parcela_cache.dart';
import '../../../../core/config/municipio_centroide.dart';
import '../../../../core/network/api_exception.dart';
import '../../../catalogo/data/models/catalogo.dart';
import '../../../catalogo/data/services/catalogo_service.dart';
import '../../data/models/parcela.dart';
import '../../data/services/parcela_service.dart';

class ParcelaViewModel extends ChangeNotifier {
  final ParcelaService _parcelaService;
  final CatalogoService _catalogoService;
  final ParcelaCache _cache = ParcelaCache();

  ParcelaViewModel(this._parcelaService, this._catalogoService);

  List<Parcela> _parcelas = [];
  List<Cultivo> _cultivos = [];
  List<TipoSuelo> _tiposSuelo = [];
  List<EtapaFenologica> _etapas = [];
  List<EventoClimatico> _eventosClimaticos = [];

  bool _cargando = false;
  String? _error;
  bool _mostrandoDatosGuardados = false;
  DateTime? _datosGuardadosEn;
  bool _guardadaLocalmente = false;

  List<Parcela> get parcelas => _parcelas;
  List<Cultivo> get cultivos => _cultivos;
  List<TipoSuelo> get tiposSuelo => _tiposSuelo;
  List<EtapaFenologica> get etapas => _etapas;

  List<EventoClimatico> get eventosClimaticos => _eventosClimaticos;

  bool get cargando => _cargando;
  String? get error => _error;
  bool get mostrandoDatosGuardados => _mostrandoDatosGuardados;
  DateTime? get datosGuardadosEn => _datosGuardadosEn;

  bool get guardadaLocalmente => _guardadaLocalmente;

  Future<void> cargarParcelas() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _parcelas = await _parcelaService.obtenerMisParcelas();
      _mostrandoDatosGuardados = false;
      _datosGuardadosEn = null;
      unawaited(_cache.guardarLista(_parcelas));
    } on ApiException catch (e) {
      _error = e.message;
    } on NetworkException catch (e) {
      await _usarCacheOMostrarError(e.message);
    } on TimeoutApiException catch (e) {
      await _usarCacheOMostrarError(e.message);
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> _usarCacheOMostrarError(String mensajeError) async {
    final cache = await _cache.obtenerLista();
    if (cache != null && cache.parcelas.isNotEmpty) {
      _parcelas = cache.parcelas;
      _mostrandoDatosGuardados = true;
      _datosGuardadosEn = cache.guardadoEn;
      _error = null;
    } else {
      _error = mensajeError;
      _mostrandoDatosGuardados = false;
    }
  }

  Future<void> cargarCatalogos() async {
    _error = null;
    notifyListeners();
    try {
      final resultados = await Future.wait([
        _catalogoService.obtenerCultivos(),
        _catalogoService.obtenerTiposSuelo(),
        _catalogoService.obtenerEtapasFenologicas(),
        _catalogoService.obtenerEventosClimaticos(),
      ]);
      _cultivos = resultados[0] as List<Cultivo>;
      _tiposSuelo = resultados[1] as List<TipoSuelo>;
      _etapas = resultados[2] as List<EtapaFenologica>;
      _eventosClimaticos = resultados[3] as List<EventoClimatico>;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    } on NetworkException catch (e) {
      _error = e.message;
      notifyListeners();
    } on TimeoutApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<bool> crearParcela(ParcelaRequest request) async {
    _cargando = true;
    _error = null;
    _guardadaLocalmente = false;
    notifyListeners();
    try {
      await _parcelaService.crear(request);
      await cargarParcelas();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } on NetworkException {
      return _guardarLocalPendiente(request);
    } on TimeoutApiException {
      return _guardarLocalPendiente(request);
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> _guardarLocalPendiente(ParcelaRequest request) async {
    Cultivo? cultivo;
    for (final c in _cultivos) {
      if (c.id == request.cultivoId) {
        cultivo = c;
        break;
      }
    }
    TipoSuelo? suelo;
    for (final s in _tiposSuelo) {
      if (s.id == request.tipoSueloId) {
        suelo = s;
        break;
      }
    }
    if (cultivo == null || suelo == null) {
      _error =
          'Sin conexión, y todavía no se descargaron los catálogos. '
          'Probá de nuevo en un momento.';
      return false;
    }

    final latitud =
        request.latitud ?? MunicipioCentroide.latitud(request.municipio);
    final longitud =
        request.longitud ?? MunicipioCentroide.longitud(request.municipio);
    if (latitud == null || longitud == null) {
      _error =
          'Sin conexión hace falta una ubicación GPS o un municipio '
          'conocido para guardar la parcela.';
      return false;
    }

    await GuestParcelaStore().agregar(
      cultivoId: cultivo.id,
      cultivoNombre: cultivo.nombre,
      tipoSueloId: suelo.id,
      tipoSueloNombre: suelo.nombre,
      etapaFenologicaId: request.etapaFenologicaId,
      latitud: latitud,
      longitud: longitud,
      municipio: request.municipio,
      comunidad: request.comunidad,
      fechaSiembra: request.fechaSiembra,
      areaMzs: request.areaMzs,
    );
    _guardadaLocalmente = true;
    _error = null;
    return true;
  }

  Future<bool> actualizarParcela(
    int parcelaId,
    ParcelaUpdateRequest request, {
    int? nuevaEtapaId,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      await _parcelaService.actualizar(parcelaId, request);
      if (nuevaEtapaId != null) {
        await _parcelaService.actualizarEtapa(parcelaId, nuevaEtapaId);
      }
      await cargarParcelas();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } on NetworkException catch (e) {
      _error = e.message;
      return false;
    } on TimeoutApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> eliminarParcela(int parcelaId) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      await _parcelaService.eliminar(parcelaId);
      await cargarParcelas();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } on NetworkException catch (e) {
      _error = e.message;
      return false;
    } on TimeoutApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}
