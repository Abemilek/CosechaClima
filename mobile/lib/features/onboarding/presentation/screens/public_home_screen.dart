import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/screens/login_sheet.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import '../../../clima/data/models/clima.dart';
import '../../../clima/data/services/clima_service.dart';
import '../../../parcela/presentation/screens/parcela_list_screen.dart';

class PublicHomeScreen extends StatefulWidget {
  const PublicHomeScreen({super.key});

  @override
  State<PublicHomeScreen> createState() => _PublicHomeScreenState();
}

class _PublicHomeScreenState extends State<PublicHomeScreen> {
  static const _latPorDefecto = 11.8500;
  static const _lonPorDefecto = -86.1990;

  late final ClimaService _climaService;

  List<PronosticoPublico> _pronostico = [];
  bool _cargando = true;
  String? _error;
  String _ubicacionTexto = 'Carazo (aproximado)';

  @override
  void initState() {
    super.initState();
    _climaService = ClimaService(ApiClient());
    unawaited(_cargarPronostico());
  }

  Future<void> _cargarPronostico({bool usarGps = false}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    var lat = _latPorDefecto;
    var lon = _lonPorDefecto;
    var textoUbicacion = 'Carazo (aproximado)';

    if (usarGps) {
      try {
        final posicion = await LocationService.obtenerUbicacionActual();
        lat = posicion.latitude;
        lon = posicion.longitude;
        textoUbicacion = 'Tu ubicación actual';
      } on LocationException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }

    List<PronosticoPublico>? resultado;
    String? error;

    try {
      resultado = await _climaService.obtenerPronosticoPublico(
        latitud: lat,
        longitud: lon,
      );
    } on ApiException catch (e) {
      error = e.message;
    } on NetworkException catch (e) {
      error = e.message;
    } on TimeoutApiException catch (e) {
      error = e.message;
    }

    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = error;
      _ubicacionTexto = textoUbicacion;
      if (resultado != null) _pronostico = resultado;
    });
  }

  Future<void> _irAMisParcelas() async {
    final auth = context.read<AuthViewModel>();

    if (!auth.estaAutenticado) {
      final ok = await mostrarLoginContextual(
        context,
        motivo: 'Para guardar tu parcela necesitás una cuenta',
      );
      if (ok != true) return;
    }

    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ParcelaListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarPronostico,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              _Encabezado(
                nombre: auth.nombre,
                estaAutenticado: auth.estaAutenticado,
              ),
              const SizedBox(height: 20),

              _TarjetaUbicacion(
                texto: _ubicacionTexto,
                onUsarGps: () => _cargarPronostico(usarGps: true),
              ),
              const SizedBox(height: 16),

              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _TarjetaError(mensaje: _error!, onReintentar: _cargarPronostico)
              else ...[
                const Text(
                  'Pronóstico de los próximos días',
                  style: _tituloSeccion,
                ),
                const SizedBox(height: 12),
                ..._pronostico.map((dia) => _TarjetaDia(dia: dia)),
              ],

              const SizedBox(height: 24),
              _TarjetaAccionPrivada(onTap: _irAMisParcelas),
            ],
          ),
        ),
      ),
    );
  }
}

const _tituloSeccion = TextStyle(
  fontFamily: 'Georgia',
  fontFamilyFallback: ['Times New Roman', 'serif'],
  fontSize: 19,
  fontWeight: FontWeight.w800,
  color: AppColors.ink,
);

class _Encabezado extends StatelessWidget {
  final String? nombre;
  final bool estaAutenticado;

  const _Encabezado({required this.nombre, required this.estaAutenticado});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'COSECHACLIMA',
                style: TextStyle(
                  color: AppColors.soil,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                estaAutenticado && nombre != null
                    ? 'Hola, $nombre'
                    : 'El clima de tu zona',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: ['Times New Roman', 'serif'],
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TarjetaUbicacion extends StatelessWidget {
  final String texto;
  final VoidCallback onUsarGps;

  const _TarjetaUbicacion({required this.texto, required this.onUsarGps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.place_outlined,
            size: 20,
            color: AppColors.greenDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: onUsarGps,
            child: const Text('Usar mi ubicación'),
          ),
        ],
      ),
    );
  }
}

class _TarjetaDia extends StatelessWidget {
  final PronosticoPublico dia;

  const _TarjetaDia({required this.dia});

  (String, IconData, Color) get _resumen {
    final lluvia = dia.precipitacion ?? 0;
    final viento = dia.vientoVelocidad ?? 0;

    if (lluvia >= 20) {
      return (
        'Lluvia fuerte esperada',
        Icons.thunderstorm_outlined,
        AppColors.red,
      );
    }
    if (lluvia >= 5) {
      return ('Puede llover', Icons.water_drop_outlined, AppColors.blue);
    }
    if (viento >= 40) {
      return ('Viento fuerte', Icons.air, AppColors.amber);
    }
    return ('Día despejado', Icons.wb_sunny_outlined, AppColors.green);
  }

  @override
  Widget build(BuildContext context) {
    final (texto, icono, color) = _resumen;
    final esHoy = DateUtils.isSameDay(dia.fecha, DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(color: AppColors.soft),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esHoy
                      ? 'Hoy'
                      : toBeginningOfSentenceCase(
                          DateFormat('EEEE d', 'es').format(dia.fecha),
                        )!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    fontSize: 15,
                  ),
                ),
                Text(
                  texto,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${dia.temperaturaMax?.round() ?? '–'}°',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppColors.ink,
                ),
              ),
              Text(
                'mín ${dia.temperaturaMin?.round() ?? '–'}°',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaError extends StatelessWidget {
  final String mensaje;
  final Future<void> Function() onReintentar;

  const _TarjetaError({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(color: AppColors.soft),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 34,
            color: AppColors.muted,
          ),
          const SizedBox(height: 10),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink, fontSize: 14),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => onReintentar(),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAccionPrivada extends StatelessWidget {
  final VoidCallback onTap;

  const _TarjetaAccionPrivada({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.greenDark,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.agriculture_outlined, color: Colors.white, size: 30),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mis parcelas',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontFamilyFallback: ['Times New Roman', 'serif'],
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Alertas y recomendaciones para tu cultivo',
                      style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
