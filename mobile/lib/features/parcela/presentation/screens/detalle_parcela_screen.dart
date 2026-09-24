import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/cache/parcela_cache.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routing/no_animation_route.dart';
import '../../../../shared/utils/riesgo_ui.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_loading_message.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import '../../../bitacora/data/models/bitacora.dart';
import '../../../bitacora/data/services/bitacora_service.dart';
import '../../../bitacora/presentation/screens/bitacora_screen.dart';
import '../../../catalogo/data/models/catalogo.dart';
import '../../../clima/data/models/clima.dart';
import '../../../clima/data/services/clima_service.dart';
import '../../../clima/data/services/motor_service.dart';
import '../../../umbral/presentation/screens/umbrales_screen.dart';
import '../../data/models/parcela.dart';
import '../../data/services/parcela_service.dart';
import '../view_models/parcela_view_model.dart';
import 'editar_parcela_screen.dart';

class DetalleParcelaScreen extends StatefulWidget {
  final Parcela parcela;

  const DetalleParcelaScreen({super.key, required this.parcela});

  @override
  State<DetalleParcelaScreen> createState() => _DetalleParcelaScreenState();
}

class _DetalleParcelaScreenState extends State<DetalleParcelaScreen> {
  late final ClimaService _climaService;
  late final MotorService _motorService;
  late final BitacoraService _bitacoraService;
  late final ParcelaService _parcelaService;
  late final ParcelaCache _parcelaCache;
  late Parcela _parcelaActual;

  int _tab = 0;

  bool _cargando = true;
  String? _error;
  bool _requiereUmbrales = false;

  DatosClimaticos? _clima;
  Semaforo? _semaforo;
  DateTime? _climaGuardadoEn;
  final Set<int> _accionesRegistradas = {};

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    _climaService = ClimaService(client);
    _motorService = MotorService(client);
    _bitacoraService = BitacoraService(client);
    _parcelaService = ParcelaService(client);
    _parcelaCache = ParcelaCache();
    _parcelaActual = widget.parcela;
    unawaited(_cargarTodo());
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _cargando = true;
      _error = null;
      _requiereUmbrales = false;
      _clima = null;
      _semaforo = null;
      _climaGuardadoEn = null;
    });

    try {
      final parcela = await _parcelaService.obtenerPorId(_parcelaActual.id);
      if (!mounted) return;
      setState(() => _parcelaActual = parcela);

      if (!parcela.puedeConsultarClima) {
        setState(() {
          _error =
              'Esta parcela no tiene coordenadas GPS ni municipio registrado.\n'
              'Editala para poder consultar el clima.';
        });
        return;
      }

      final clima = await _climaService.actualizar(parcela.id);
      if (!mounted) return;
      final semaforo = await _motorService.obtenerSemaforo(parcela.id);
      if (!mounted) return;
      setState(() {
        _clima = clima;
        _semaforo = semaforo;
        _climaGuardadoEn = null;
      });
      unawaited(
        _parcelaCache.guardar(
          parcelaId: parcela.id,
          clima: clima,
          semaforo: semaforo,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _requiereUmbrales =
            e.esNoEncontrado && e.message.toLowerCase().contains('umbral');
      });
    } on NetworkException catch (e) {
      await _usarCacheOMostrarError(e.message);
    } on TimeoutApiException catch (e) {
      await _usarCacheOMostrarError(e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _usarCacheOMostrarError(String mensajeError) async {
    final cache = await _parcelaCache.obtener(_parcelaActual.id);
    if (!mounted) return;
    if (cache != null) {
      setState(() {
        _clima = cache.clima;
        _semaforo = cache.semaforo;
        _climaGuardadoEn = cache.guardadoEn;
        _error = null;
      });
    } else {
      setState(() => _error = mensajeError);
    }
  }

  Future<void> _registrarEnBitacora() async {
    final semaforo = _semaforo;
    if (semaforo == null) return;

    final eventos = context.read<ParcelaViewModel>().eventosClimaticos;
    if (eventos.isEmpty) {
      _mostrarError(
        'No se pudo cargar el catálogo de eventos climáticos. Probá de nuevo.',
      );
      unawaited(context.read<ParcelaViewModel>().cargarCatalogos());
      return;
    }

    final eventoId = await _elegirEventoClimatico(eventos);
    if (eventoId == null || !mounted) return;

    try {
      await _bitacoraService.crear(
        BitacoraRequest(
          parcelaId: _parcelaActual.id,
          fecha: semaforo.fecha,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardado en tu bitácora de campo')),
        );
      }
    } on ApiException catch (e) {
      _mostrarError(e.message);
    } on NetworkException catch (e) {
      _mostrarError(e.message);
    } on TimeoutApiException catch (e) {
      _mostrarError(e.message);
    }
  }

  Future<int?> _elegirEventoClimatico(List<EventoClimatico> eventos) {
    int seleccionado = eventos.first.id;
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
        (_) => EditarParcelaScreen(parcela: _parcelaActual),
      ),
    );
    if (actualizada == true) unawaited(_cargarTodo());
  }

  Future<void> _eliminarParcela() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar esta parcela?'),
        content: const Text(
          'Se va a eliminar la parcela de tu lista. Esta acción no se puede deshacer desde la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final ok = await context.read<ParcelaViewModel>().eliminarParcela(
      _parcelaActual.id,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      final error = context.read<ParcelaViewModel>().error;
      if (error != null) _mostrarError(error);
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  Future<void> _abrirSms() async {
    final semaforo = _semaforo;
    if (semaforo == null) return;
    final acciones = semaforo.acciones.take(3).toList();
    final cuerpo = StringBuffer(
      'ALERTA CosechaClima: riesgo ${semaforo.nivelRiesgo} - ${semaforo.descripcionAlerta}. ',
    );
    for (var i = 0; i < acciones.length; i++) {
      cuerpo.write('${i + 1}) ${acciones[i]}. ');
    }
    final uri = Uri(
      scheme: 'sms',
      path: '',
      queryParameters: {'body': cuerpo.toString()},
    );
    final abierto = await launchUrl(uri);
    if (!abierto && mounted) {
      _mostrarError('No se pudo abrir la app de mensajes en este dispositivo.');
    }
  }

  Color get _colorRiesgo => RiesgoUi.colorPara(_semaforo?.nivelRiesgo);

  @override
  Widget build(BuildContext context) {
    final nombre = context.watch<AuthViewModel>().nombre;
    final parcela = _parcelaActual;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.greenDark,
                  ),
                  const AppAvatar(icon: Icons.eco_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BUENOS DÍAS,',
                          style: TextStyle(
                            color: AppColors.soil,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          nombre ?? 'Agricultor',
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontFamilyFallback: ['Times New Roman', 'serif'],
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final guardado = await Navigator.of(context).push<bool>(
                        noAnimationRoute<bool>((_) => const UmbralesScreen()),
                      );
                      if (guardado == true) unawaited(_cargarTodo());
                    },
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
                      if (opcion == 'editar') _editarParcela();
                      if (opcion == 'eliminar') _eliminarParcela();
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
            if (parcela.tieneCoordenadas && !parcela.estaEnZonaCubierta)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: _AvisoBanner(
                  icono: Icons.warning_amber_outlined,
                  color: AppColors.amber,
                  colorFondo: AppColors.amberBg,
                  texto:
                      'Esta parcela parece estar fuera de Carazo. Las alertas están '
                      'calibradas solo para ese departamento y podrían no ser precisas acá.',
                ),
              )
            else if (!parcela.tieneCoordenadas && parcela.puedeConsultarClima)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: _AvisoBanner(
                  icono: Icons.info_outline,
                  color: AppColors.green,
                  colorFondo: AppColors.mint,
                  texto:
                      'Estás viendo el clima aproximado del municipio, no el de tu '
                      'parcela exacta. Agregá el GPS para mayor precisión.',
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _HomeTab(
                    cargando: _cargando,
                    error: _error,
                    requiereUmbrales: _requiereUmbrales,
                    sinCoordenadas: !parcela.tieneCoordenadas,
                    clima: _clima,
                    semaforo: _semaforo,
                    parcela: parcela,
                    colorRiesgo: _colorRiesgo,
                    climaGuardadoEn: _climaGuardadoEn,
                    accionesRegistradas: _accionesRegistradas,
                    onReintentar: _cargarTodo,
                    onIrAUmbrales: () async {
                      final guardado = await Navigator.of(context).push<bool>(
                        noAnimationRoute<bool>((_) => const UmbralesScreen()),
                      );
                      if (guardado == true) unawaited(_cargarTodo());
                    },
                    onEditar: _editarParcela,
                    onToggleAccion: (i) => setState(() {
                      if (_accionesRegistradas.contains(i)) {
                        _accionesRegistradas.remove(i);
                      } else {
                        _accionesRegistradas.add(i);
                      }
                    }),
                    onGuardarBitacora: _registrarEnBitacora,
                  ),
                  _AlertasTab(
                    cargando: _cargando,
                    error: _error,
                    requiereUmbrales: _requiereUmbrales,
                    sinCoordenadas: !parcela.tieneCoordenadas,
                    semaforo: _semaforo,
                    colorRiesgo: _colorRiesgo,
                    climaGuardadoEn: _climaGuardadoEn,
                    onReintentar: _cargarTodo,
                    onIrAUmbrales: () async {
                      final guardado = await Navigator.of(context).push<bool>(
                        noAnimationRoute<bool>((_) => const UmbralesScreen()),
                      );
                      if (guardado == true) unawaited(_cargarTodo());
                    },
                    onEditar: _editarParcela,
                    onAbrirSms: _abrirSms,
                  ),
                  BitacoraScreen(parcelaId: parcela.id, mostrarAppBar: false),
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

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _BottomNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, 'Inicio'),
      (Icons.warning_amber_outlined, 'Alertas'),
      (Icons.calendar_month_outlined, 'Bitácora'),
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
                        color: active
                            ? AppColors.greenDark
                            : const Color(0xFF403831),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: active
                              ? AppColors.greenDark
                              : const Color(0xFF403831),
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

class _AvisoBanner extends StatelessWidget {
  final IconData icono;
  final Color color;
  final Color colorFondo;
  final String texto;

  const _AvisoBanner({
    required this.icono,
    required this.color,
    required this.colorFondo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _CacheBanner extends StatelessWidget {
  final DateTime guardadoEn;

  const _CacheBanner({required this.guardadoEn});

  @override
  Widget build(BuildContext context) {
    final formato = DateFormat('dd MMM, HH:mm', 'es').format(guardadoEn);
    return _AvisoBanner(
      icono: Icons.cloud_off_outlined,
      color: AppColors.soil,
      colorFondo: AppColors.soft,
      texto:
          'Sin conexión — mostrando datos guardados. Última actualización: $formato.',
    );
  }
}

class _HomeTab extends StatelessWidget {
  final bool cargando;
  final String? error;
  final bool requiereUmbrales;
  final bool sinCoordenadas;
  final DatosClimaticos? clima;
  final Semaforo? semaforo;
  final Parcela parcela;
  final Color colorRiesgo;
  final DateTime? climaGuardadoEn;
  final Set<int> accionesRegistradas;
  final Future<void> Function() onReintentar;
  final VoidCallback onIrAUmbrales;
  final VoidCallback onEditar;
  final ValueChanged<int> onToggleAccion;
  final VoidCallback onGuardarBitacora;

  const _HomeTab({
    required this.cargando,
    required this.error,
    required this.requiereUmbrales,
    required this.sinCoordenadas,
    required this.clima,
    required this.semaforo,
    required this.parcela,
    required this.colorRiesgo,
    required this.climaGuardadoEn,
    required this.accionesRegistradas,
    required this.onReintentar,
    required this.onIrAUmbrales,
    required this.onEditar,
    required this.onToggleAccion,
    required this.onGuardarBitacora,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const AppLoadingMessage(message: 'Consultando clima...');
    }

    if (error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.info_outline, size: 48, color: AppColors.muted),
          const SizedBox(height: 16),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink),
          ),
          const SizedBox(height: 24),
          if (sinCoordenadas)
            FilledButton.icon(
              onPressed: onEditar,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Agregar coordenadas ahora'),
            )
          else if (requiereUmbrales)
            FilledButton(
              onPressed: onIrAUmbrales,
              child: const Text('Configurar mis umbrales'),
            )
          else
            OutlinedButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
        ],
      );
    }

    if (clima == null && semaforo == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          _DetailStateMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Aún no hay clima calculado',
            message:
                'No encontramos datos de clima o semáforo para esta parcela. '
                'Actualizá para pedir un nuevo cálculo al servidor.',
            action: OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualizar clima'),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        if (climaGuardadoEn != null) ...[
          _CacheBanner(guardadoEn: climaGuardadoEn!),
          const SizedBox(height: 4),
        ],
        if (clima != null)
          _SummaryCard(clima: clima!, parcela: parcela, semaforo: semaforo),
        const SizedBox(height: 16),
        if (semaforo != null) ...[
          _RiskCard(semaforo: semaforo!, color: colorRiesgo),
          const SizedBox(height: 20),
          const Text(
            'Tus 3 acciones de hoy',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontFamilyFallback: ['Times New Roman', 'serif'],
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          ...semaforo!.acciones.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ActionTile(
                numero: entry.key + 1,
                texto: entry.value,
                completada: accionesRegistradas.contains(entry.key),
                color: colorRiesgo,
                onTap: () => onToggleAccion(entry.key),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onGuardarBitacora,
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Guardar en mi bitácora'),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Actualizar clima'),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Expanded(
                child: _SourceCard(
                  icon: Icons.cloud_outlined,
                  titulo: 'Open-Meteo',
                  detalle: 'Clima horario en tiempo real.',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _SourceCard(
                  icon: Icons.rule_outlined,
                  titulo: 'Motor de reglas',
                  detalle: 'Acciones según cultivo y etapa.',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DetailStateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  const _DetailStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 48, color: AppColors.muted),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: ['Times New Roman', 'serif'],
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        action,
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DatosClimaticos clima;
  final Parcela parcela;
  final Semaforo? semaforo;

  const _SummaryCard({
    required this.clima,
    required this.parcela,
    required this.semaforo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppPill(
                icon: Icons.location_on_outlined,
                text: parcela.municipio ?? 'Parcela #${parcela.id}',
                variant: AppPillVariant.dark,
              ),
              if (semaforo != null)
                AppPill(
                  text: 'Riesgo ${semaforo!.nivelRiesgo}',
                  variant: RiesgoUi.variantePara(semaforo!.nivelRiesgo),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${clima.temperaturaMax?.round() ?? '–'}',
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: ['Times New Roman', 'serif'],
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8, left: 2),
                    child: Text(
                      '°C',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const Icon(Icons.cloud_outlined, size: 40, color: Colors.white),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0x47FFFFFF)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metric('Humedad', '${clima.humedadRelativa?.round() ?? '–'}%'),
              _metric(
                'Viento',
                '${clima.vientoVelocidad?.round() ?? '–'} km/h',
              ),
              _metric('Lluvia', '${clima.precipitacion?.round() ?? '–'} mm'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String valor) => Column(
    children: [
      Text(
        valor,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      Text(
        label.toUpperCase(),
        style: const TextStyle(color: Color(0xADFFFFFF), fontSize: 11),
      ),
    ],
  );
}

class _RiskCard extends StatelessWidget {
  final Semaforo semaforo;
  final Color color;

  const _RiskCard({required this.semaforo, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPill(
                  text: 'Alerta ${semaforo.nivelRiesgo}',
                  variant: RiesgoUi.variantePara(semaforo.nivelRiesgo),
                ),
                const SizedBox(height: 10),
                Text(
                  semaforo.descripcionAlerta,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontFamilyFallback: ['Times New Roman', 'serif'],
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final int numero;
  final String texto;
  final bool completada;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.numero,
    required this.texto,
    required this.completada,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: completada ? const Color(0xFFEEF8ED) : AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.cardSmall),
            border: Border.all(color: const Color(0xFFEADCCF)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$numero',
                    style: TextStyle(color: color, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    decoration: completada ? TextDecoration.lineThrough : null,
                    color: completada ? AppColors.muted : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                completada ? Icons.check_circle : Icons.radio_button_unchecked,
                color: completada ? AppColors.green : AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String detalle;

  const _SourceCard({
    required this.icon,
    required this.titulo,
    required this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppPill(icon: icon, text: titulo),
          const SizedBox(height: 8),
          Text(
            detalle,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _AlertasTab extends StatelessWidget {
  final bool cargando;
  final String? error;
  final bool requiereUmbrales;
  final bool sinCoordenadas;
  final Semaforo? semaforo;
  final Color colorRiesgo;
  final DateTime? climaGuardadoEn;
  final Future<void> Function() onReintentar;
  final VoidCallback onIrAUmbrales;
  final VoidCallback onEditar;
  final Future<void> Function() onAbrirSms;

  const _AlertasTab({
    required this.cargando,
    required this.error,
    required this.requiereUmbrales,
    required this.sinCoordenadas,
    required this.semaforo,
    required this.colorRiesgo,
    required this.climaGuardadoEn,
    required this.onReintentar,
    required this.onIrAUmbrales,
    required this.onEditar,
    required this.onAbrirSms,
  });

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const AppLoadingMessage(message: 'Calculando alertas...');
    }

    if (error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          _DetailStateMessage(
            icon: sinCoordenadas ? Icons.my_location : Icons.info_outline,
            title: sinCoordenadas
                ? 'Faltan coordenadas'
                : requiereUmbrales
                ? 'Faltan umbrales'
                : 'No se pudo calcular',
            message: error!,
            action: sinCoordenadas
                ? FilledButton.icon(
                    onPressed: onEditar,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Agregar coordenadas'),
                  )
                : requiereUmbrales
                ? FilledButton(
                    onPressed: onIrAUmbrales,
                    child: const Text('Configurar umbrales'),
                  )
                : OutlinedButton.icon(
                    onPressed: onReintentar,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reintentar'),
                  ),
          ),
        ],
      );
    }

    if (semaforo == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          _DetailStateMessage(
            icon: Icons.warning_amber_outlined,
            title: 'Sin alerta calculada',
            message:
                'Todavía no hay una alerta para esta parcela. Actualizá para '
                'consultar clima y reglas de decisión.',
            action: OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualizar alerta'),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (climaGuardadoEn != null) ...[
          _CacheBanner(guardadoEn: climaGuardadoEn!),
          const SizedBox(height: 10),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Protocolo de alerta',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontFamilyFallback: ['Times New Roman', 'serif'],
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            AppPill(
              text: semaforo!.nivelRiesgo,
              variant: RiesgoUi.variantePara(semaforo!.nivelRiesgo),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorRiesgo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colorRiesgo.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorRiesgo,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      semaforo!.descripcionAlerta,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...semaforo!.acciones.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: colorRiesgo.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${e.key + 1}',
                      style: TextStyle(
                        color: colorRiesgo,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: colorRiesgo),
          onPressed: onAbrirSms,
          icon: const Icon(Icons.sms_outlined, size: 18),
          label: const Text('Preparar SMS'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(AppRadius.cardSmall),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sobre este botón',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text(
                'Abre tu app de mensajes con la alerta ya escrita, para que se la '
                'envíes a un contacto de confianza. Funciona con señal de '
                'telefonía aunque no tengas datos móviles — pero para calcular '
                'la alerta en sí, la app sí necesita conexión al servidor.',
                style: TextStyle(fontSize: 13, color: AppColors.ink),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
