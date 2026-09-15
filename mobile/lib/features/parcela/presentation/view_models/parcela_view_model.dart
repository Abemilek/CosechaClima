import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../catalogo/data/models/catalogo.dart';
import '../../../catalogo/data/services/catalogo_service.dart';
import '../../data/models/parcela.dart';
import '../../data/services/parcela_service.dart';

class ParcelaViewModel extends ChangeNotifier {
  final ParcelaService _parcelaService;
  final CatalogoService _catalogoService;

  ParcelaViewModel(this._parcelaService, this._catalogoService);

  List<Parcela> _parcelas = [];
  List<Cultivo> _cultivos = [];
  List<TipoSuelo> _tiposSuelo = [];
  List<EtapaFenologica> _etapas = [];
  List<EventoClimatico> _eventosClimaticos = [];

  bool _cargando = false;
  String? _error;

  List<Parcela> get parcelas => _parcelas;
  List<Cultivo> get cultivos => _cultivos;
  List<TipoSuelo> get tiposSuelo => _tiposSuelo;
  List<EtapaFenologica> get etapas => _etapas;

  List<EventoClimatico> get eventosClimaticos => _eventosClimaticos;

  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargarParcelas() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _parcelas = await _parcelaService.obtenerMisParcelas();
    } on ApiException catch (e) {
      _error = e.message;
    } on NetworkException catch (e) {
      _error = e.message;
    } on TimeoutApiException catch (e) {
      _error = e.message;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> cargarCatalogos() async {
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
    notifyListeners();
    try {
      await _parcelaService.crear(request);
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
