import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/cache/evaluacion_local_cache.dart';
import '../../../../core/cache/forecast_cache.dart';
import '../../../../core/config/environment.dart';
import '../../../../core/motor/motor_local.dart';
import '../../../../core/network/network_exception.dart';
import '../../../../core/services/notificacion_riesgo_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routing/no_animation_route.dart';
import '../../../../shared/utils/riesgo_ui.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_loading_message.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../bitacora/data/models/bitacora.dart';
import '../../../bitacora/data/services/bitacora_service.dart';
import '../../../bitacora/presentation/screens/bitacora_screen.dart';
import '../../../catalogo/data/models/catalogo.dart';
import '../../../catalogo/presentation/view_models/catalogo_view_model.dart';
import '../../../clima/data/models/clima.dart';
import '../../../clima/data/services/motor_local_service.dart';
import '../../../clima/presentation/screens/resumen_semanal_tab.dart';
import '../../../onboarding/presentation/screens/acerca_de_screen.dart';
import '../../../umbral/data/services/umbral_service.dart';
import '../../../umbral/presentation/screens/umbrales_screen.dart';
import '../../data/models/parcela_local.dart';
import '../../data/services/parcela_local_store.dart';
import 'editar_parcela_local_screen.dart';

class ParcelaLocalDetailScreen extends StatefulWidget {
  final ParcelaLocal parcela;

  const ParcelaLocalDetailScreen({super.key, required this.parcela});

  @override
  State<ParcelaLocalDetailScreen> createState() =>
      _ParcelaLocalDetailScreenState();
}

class _ParcelaLocalDetailScreenState extends State<ParcelaLocalDetailScreen> {
  final _motor = MotorLocalService();
  final _cache = EvaluacionLocalCache();
  final _umbralService = UmbralService();
  final _bitacoraService = BitacoraService();
  final _store = ParcelaLocalStore();

  late ParcelaLocal _parcela;

  int _tab = 0;
  bool _cargando = true;
  String? _error;
  bool _desdeCacheGuardada = false;
  DateTime? _datosGuardadosEn;

  DatosClimaticos? _clima;
  Semaforo? _semaforo;
  ResumenSemanal? _resumen;

  bool _guardandoBitacora = false;
  bool _registradaHoy = false;
  int _bitacoraVersion = 0;

  @override
  void initState() {
    super.initState();
    _parcela = widget.parcela;
    unawaited(_cargarTodo());
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _cargando = true;
      _error = null;
      _desdeCacheGuardada = false;
      _datosGuardadosEn = null;
      _clima = null;
      _semaforo = null;
      _resumen = null;
      _registradaHoy = false;
    });

    try {
      final umbrales = await _umbralService.obtenerParaMotor();
      final evaluacion = await _motor.evaluar(
        EntradaMotor.deParcelaLocal(_parcela),
        umbrales: umbrales,
      );
      final entradas = await _bitacoraService.obtenerDeParcela(_parcela.id);
      if (!mounted) return;
      final registradaHoy = entradas.any(
        (entrada) => DateUtils.isSameDay(entrada.fecha, DateTime.now()),
      );
      final cacheVencida =
          evaluacion.desdeCache &&
          DateTime.now().difference(evaluacion.descargadaEn) >
              ForecastCache.frescura;

      setState(() {
        _clima = evaluacion.datosHoy;
        _semaforo = evaluacion.semaforo;
        _resumen = evaluacion.resumen;
        _registradaHoy = registradaHoy;
        _desdeCacheGuardada = cacheVencida;
        _datosGuardadosEn = cacheVencida ? evaluacion.descargadaEn : null;
      });
      unawaited(
        _cache.guardar(
          parcelaId: _parcela.id,
          clima: evaluacion.datosHoy,
          semaforo: evaluacion.semaforo,
          resumen: evaluacion.resumen,
        ),
      );
      unawaited(_evaluarNotificacion(evaluacion));
    } on NetworkException catch (e) {
      await _usarCacheOMostrarError(e.message);
    } on NetworkTimeoutException catch (e) {
      await _usarCacheOMostrarError(e.message);
    } on MotorLocalException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Ocurrió un problema al calcular el semáforo. Intentá de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _evaluarNotificacion(EvaluacionLocal evaluacion) async {
    try {
      await NotificacionRiesgoService.instancia.evaluarCambioDeRiesgo(
        parcelaId: _parcela.id,
        parcelaNombre: _parcela.comunidad ?? _parcela.municipio ?? 'tu parcela',
        nivelRiesgoActual: evaluacion.semaforo.nivelRiesgo,
        descripcionAlerta: evaluacion.semaforo.descripcionAlerta,
      );
    } catch (_) {
      // Las notificaciones son un extra: un fallo no debe romper el semáforo.
    }
  }

  Future<void> _usarCacheOMostrarError(String mensaje) async {
    final guardada = await _cache.obtener(_parcela.id);
    if (!mounted) return;
    if (guardada != null) {
      setState(() {
        _clima = guardada.clima;
        _semaforo = guardada.semaforo;
        _resumen = guardada.resumen;
        _desdeCacheGuardada = true;
        _datosGuardadosEn = guardada.guardadoEn;
        _error = null;
      });
    } else {
      setState(() => _error = mensaje);
    }
  }

  Future<void> _registrarEnBitacora() async {
    final semaforo = _semaforo;
    if (semaforo == null || _guardandoBitacora || _registradaHoy) return;

    final catalogo = context.read<CatalogoViewModel>();
    final eventos = catalogo.eventosClimaticos;
    if (eventos.isEmpty) {
      _mostrarError(
        'No se pudo cargar el catálogo local de eventos climáticos.',
      );
      unawaited(catalogo.cargarCatalogos(forzar: true));
      return;
    }

    int? eventoId;
    if (semaforo.nivelRiesgo.toLowerCase() == 'bajo') {
      eventoId = semaforo.eventoClimaticoId;
    } else {
      eventoId = await _elegirEventoClimatico(
        eventos,
        preseleccionado: semaforo.eventoClimaticoId,
      );
    }
    if (eventoId == null || !mounted) return;

    setState(() => _guardandoBitacora = true);
    try {
      await _bitacoraService.crear(
        BitacoraRequest(
          parcelaId: _parcela.id,
          fecha: DateTime.now(),
          eventoClimaticoId: eventoId,
          nivelRiesgo: semaforo.nivelRiesgo,
          accion1Texto: semaforo.acciones.isNotEmpty
              ? semaforo.acciones[0]
              : '-',
          accion2Texto: semaforo.acciones.length > 1
              ? semaforo.acciones[1]
              : '-',
          accion3Texto: semaforo.acciones.length > 2
              ? semaforo.acciones[2]
              : '-',
        ),
      );
      if (!mounted) return;
      setState(() {
        _registradaHoy = true;
        _guardandoBitacora = false;
        _bitacoraVersion++;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Guardado en tu cuaderno')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardandoBitacora = false);
      _mostrarError('No se pudo guardar en la bitácora. Intentá de nuevo.');
    }
  }

  Future<int?> _elegirEventoClimatico(
    List<EventoClimatico> eventos, {
    int? preseleccionado,
  }) {
    var seleccionado = eventos.any((e) => e.id == preseleccionado)
        ? preseleccionado!
        : eventos.first.id;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('¿Qué evento climático fue?'),
          content: DropdownButtonFormField<int>(
            initialValue: seleccionado,
            items: eventos
                .map(
                  (e) => DropdownMenuItem(value: e.id, child: Text(e.nombre)),
                )
                .toList(),
            onChanged: (v) =>
                setDialogState(() => seleccionado = v ?? seleccionado),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(seleccionado),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editarParcela() async {
    final actualizada = await Navigator.of(context).push<bool>(
      noAnimationRoute<bool>(
        (_) => EditarParcelaLocalScreen(parcela: _parcela),
      ),
    );
    if (actualizada != true || !mounted) return;
    final guardada = await _store.obtener(_parcela.id);
    if (guardada == null || !mounted) return;
    await _cache.limpiar(_parcela.id);
    if (!mounted) return;
    setState(() => _parcela = guardada);
    unawaited(_cargarTodo());
  }

  Future<void> _eliminarParcela() async {
    final confirmar = await mostrarConfirmacion(
      context,
      titulo: '¿Eliminar esta parcela?',
      mensaje:
          'Se van a borrar la parcela y las entradas de su cuaderno de este '
          'teléfono. Esta acción no se puede deshacer.',
      textoConfirmar: 'Eliminar',
      esDestructivo: true,
    );
    if (!confirmar || !mounted) return;

    try {
      await _bitacoraService.eliminarDeParcela(_parcela.id);
      await _cache.limpiar(_parcela.id);
      await _store.eliminar(_parcela.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      _mostrarError('No se pudo eliminar la parcela.');
    }
  }

  Future<void> _ajustarAlertas() async {
    final guardado = await Navigator.of(
      context,
    ).push<bool>(noAnimationRoute<bool>((_) => const UmbralesScreen()));
    if (guardado != true) return;
    await _cache.limpiarTodas();
    if (!mounted) return;
    unawaited(_cargarTodo());
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoViewModel>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 6),
              child: Row(
                children: [
                  const BackButton(color: AppColors.greenDark),
                  const AppAvatar(icon: Icons.eco_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _parcela.ubicacionTexto.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.soil,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _parcela.cultivoNombre,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontFamilyFallback: ['Times New Roman', 'serif'],
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ajustar mis alertas',
                    onPressed: _ajustarAlertas,
                    icon: const Icon(Icons.tune),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.green.withValues(alpha: 0.08),
                      foregroundColor: AppColors.greenDark,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.greenDark,
                    ),
                    onSelected: (opcion) {
                      if (opcion == 'editar') unawaited(_editarParcela());
                      if (opcion == 'eliminar') unawaited(_eliminarParcela());
                      if (opcion == 'acerca') {
                        Navigator.of(context).push(
                          noAnimationRoute<void>((_) => const AcercaDeScreen()),
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'editar',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar parcela'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'acerca',
                        child: ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('¿Cómo calculamos esto?'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'eliminar',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: AppColors.red,
                          ),
                          title: Text(
                            'Eliminar parcela',
                            style: TextStyle(color: AppColors.red),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _InicioTab(
                    parcela: _parcela,
                    catalogo: catalogo,
                    cargando: _cargando,
                    error: _error,
                    clima: _clima,
                    semaforo: _semaforo,
                    resumen: _resumen,
                    desdeCacheGuardada: _desdeCacheGuardada,
                    datosGuardadosEn: _datosGuardadosEn,
                    guardandoBitacora: _guardandoBitacora,
                    registradaHoy: _registradaHoy,
                    onReintentar: _cargarTodo,
                    onRegistrar: _registrarEnBitacora,
                    onEditar: _editarParcela,
                    onAjustarAlertas: _ajustarAlertas,
                  ),
                  BitacoraScreen(
                    key: ValueKey(_bitacoraVersion),
                    parcelaId: _parcela.id,
                    mostrarAppBar: false,
                  ),
                  ResumenSemanalTab(
                    resumenSemanal: _resumen,
                    cargando: _cargando,
                    error: _error,
                    sinCoordenadas: false,
                    onRefrescar: _cargarTodo,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _InicioTab extends StatelessWidget {
  final ParcelaLocal parcela;
  final CatalogoViewModel catalogo;
  final bool cargando;
  final String? error;
  final DatosClimaticos? clima;
  final Semaforo? semaforo;
  final ResumenSemanal? resumen;
  final bool desdeCacheGuardada;
  final DateTime? datosGuardadosEn;
  final bool guardandoBitacora;
  final bool registradaHoy;
  final Future<void> Function() onReintentar;
  final VoidCallback onRegistrar;
  final Future<void> Function() onEditar;
  final Future<void> Function() onAjustarAlertas;

  const _InicioTab({
    required this.parcela,
    required this.catalogo,
    required this.cargando,
    required this.error,
    required this.clima,
    required this.semaforo,
    required this.resumen,
    required this.desdeCacheGuardada,
    required this.datosGuardadosEn,
    required this.guardandoBitacora,
    required this.registradaHoy,
    required this.onReintentar,
    required this.onRegistrar,
    required this.onEditar,
    required this.onAjustarAlertas,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const AppLoadingMessage(message: 'Calculando tu semáforo...');
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: AppColors.muted,
              ),
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => onReintentar(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final semaforoActual = semaforo;
    final climaActual = clima;
    if (semaforoActual == null || climaActual == null) {
      return const SizedBox.shrink();
    }

    final etapa = catalogo.etapaPorId(parcela.etapaFenologicaId);
    final color = RiesgoUi.colorPara(semaforoActual.nivelRiesgo);

    return RefreshIndicator(
      onRefresh: onReintentar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (desdeCacheGuardada) ...[
            _BannerDatosGuardados(
              guardadoEn: datosGuardadosEn,
              texto:
                  'Sin conexión: mostrando datos guardados en este teléfono.',
            ),
            const SizedBox(height: 12),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: RiesgoUi.colorFondoSuavePara(semaforoActual.nivelRiesgo),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppPill(
                      text: 'Riesgo ${semaforoActual.nivelRiesgo}',
                      variant: RiesgoUi.variantePara(
                        semaforoActual.nivelRiesgo,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('EEEE d', 'es').format(semaforoActual.fecha),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  semaforoActual.descripcionAlerta,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontFamilyFallback: ['Times New Roman', 'serif'],
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ClimaResumen(clima: climaActual),
          const SizedBox(height: 22),
          const Text(
            'TU PLAN DE HOY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          ...semaforoActual.acciones.map(
            (accion) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 19,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      accion,
                      style: const TextStyle(fontSize: 14.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: guardandoBitacora || registradaHoy ? null : onRegistrar,
            icon: Icon(
              registradaHoy
                  ? Icons.check_circle_outline
                  : Icons.menu_book_outlined,
            ),
            label: Text(
              registradaHoy
                  ? 'Ya está en tu cuaderno'
                  : guardandoBitacora
                  ? 'Guardando...'
                  : 'Guardar en mi cuaderno',
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'TU PARCELA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          _FichaParcela(
            parcela: parcela,
            etapaNombre: etapa?.nombre,
            resumen: resumen,
            onEditar: onEditar,
            onAjustarAlertas: onAjustarAlertas,
          ),
          const SizedBox(height: 20),
          const Text(
            Environment.atribucionClima,
            style: TextStyle(fontSize: 10.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ClimaResumen extends StatelessWidget {
  final DatosClimaticos clima;

  const _ClimaResumen({required this.clima});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.thermostat, '${clima.temperaturaMax?.round() ?? '–'}°', 'máx'),
      (Icons.ac_unit, '${clima.temperaturaMin?.round() ?? '–'}°', 'mín'),
      (
        Icons.water_drop_outlined,
        '${clima.precipitacion?.round() ?? '–'} mm',
        'lluvia',
      ),
      (Icons.air, '${clima.vientoVelocidad?.round() ?? '–'} km/h', 'viento'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(color: AppColors.soft),
      ),
      child: Row(
        children: items.map((item) {
          final (icono, valor, etiqueta) = item;
          return Expanded(
            child: Column(
              children: [
                Icon(icono, size: 18, color: AppColors.greenDark),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    fontSize: 14,
                  ),
                ),
                Text(
                  etiqueta,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FichaParcela extends StatelessWidget {
  final ParcelaLocal parcela;
  final String? etapaNombre;
  final ResumenSemanal? resumen;
  final Future<void> Function() onEditar;
  final Future<void> Function() onAjustarAlertas;

  const _FichaParcela({
    required this.parcela,
    required this.etapaNombre,
    required this.resumen,
    required this.onEditar,
    required this.onAjustarAlertas,
  });

  @override
  Widget build(BuildContext context) {
    final filas = [
      ('Cultivo', parcela.cultivoNombre),
      ('Suelo', parcela.tipoSueloNombre),
      ('Etapa', etapaNombre ?? 'Calculada por fecha de siembra'),
      ('Área', '${parcela.areaMzs} manzanas'),
      ('Ubicación', parcela.ubicacionTexto),
      ('Siembra', DateFormat('d MMM yyyy', 'es').format(parcela.fechaSiembra)),
      if (resumen != null) ('Riesgo de la semana', resumen!.nivelRiesgoMaximo),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < filas.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    filas[i].$1,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    filas[i].$2,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (i < filas.length - 1) const Divider(height: 18),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onEditar(),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onAjustarAlertas(),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Alertas'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerDatosGuardados extends StatelessWidget {
  final DateTime? guardadoEn;
  final String texto;

  const _BannerDatosGuardados({required this.guardadoEn, required this.texto});

  @override
  Widget build(BuildContext context) {
    final detalle = guardadoEn == null
        ? texto
        : '$texto Última actualización: '
              '${guardadoEn!.day}/${guardadoEn!.month} '
              '${guardadoEn!.hour.toString().padLeft(2, '0')}:'
              '${guardadoEn!.minute.toString().padLeft(2, '0')}.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.amberBg,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: Color(0xFFA56800)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detalle,
              style: const TextStyle(fontSize: 12, color: Color(0xFFA56800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _BottomNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, 'Inicio'),
      (Icons.menu_book_outlined, 'Cuaderno'),
      (Icons.date_range_outlined, 'Semana'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: Color(0xFFEBDED3))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (i) {
            final active = i == index;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? AppColors.mint2 : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].$1,
                        color: active ? AppColors.greenDark : AppColors.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: active ? AppColors.greenDark : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
