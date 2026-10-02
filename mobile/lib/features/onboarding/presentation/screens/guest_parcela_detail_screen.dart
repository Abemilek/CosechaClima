import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/cache/guest_parcela_migration.dart';
import '../../../../core/cache/guest_parcela_store.dart';
import '../../../../core/cache/parcela_cache.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routing/no_animation_route.dart';
import '../../../../routing/role_home_screen.dart';
import '../../../../shared/utils/riesgo_ui.dart';
import '../../../../shared/widgets/app_loading_message.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../../auth/presentation/screens/login_sheet.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import '../../../clima/data/models/clima.dart';
import '../../../clima/data/services/motor_service.dart';

class GuestParcelaDetailScreen extends StatefulWidget {
  final GuestParcela parcela;

  const GuestParcelaDetailScreen({super.key, required this.parcela});

  @override
  State<GuestParcelaDetailScreen> createState() =>
      _GuestParcelaDetailScreenState();
}

class _GuestParcelaDetailScreenState extends State<GuestParcelaDetailScreen> {
  late final MotorService _motorService;
  final _cache = ParcelaCache();
  ResumenSemanal? _resumen;
  bool _cargando = true;
  String? _error;
  DateTime? _planGuardadoEn;
  bool _migrando = false;

  @override
  void initState() {
    super.initState();
    _motorService = MotorService(ApiClient());
    unawaited(_cargar());
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    ResumenSemanal? resultado;
    String? error;
    DateTime? guardadoEn;

    Future<void> usarCache() async {
      final cache = await _cache.obtenerResumenLocal(widget.parcela.idLocal);
      if (cache == null) return;
      resultado = cache.resumen;
      guardadoEn = cache.guardadoEn;
    }

    try {
      final calculado = await _motorService.obtenerResumenSemanalAnonimo(
        cultivoId: widget.parcela.cultivoId,
        etapaFenologicaId: widget.parcela.etapaFenologicaId,
        tipoSueloId: widget.parcela.tipoSueloId,
        latitud: widget.parcela.latitud,
        longitud: widget.parcela.longitud,
        fechaSiembra: widget.parcela.fechaSiembra,
      );
      resultado = calculado;
      unawaited(
        _cache.guardarResumenLocal(
          idLocal: widget.parcela.idLocal,
          resumen: calculado,
        ),
      );
    } on NetworkException catch (e) {
      await usarCache();
      if (resultado == null) error = e.message;
    } on TimeoutApiException catch (e) {
      await usarCache();
      if (resultado == null) error = e.message;
    } on ApiException catch (e) {
      if (e.esErrorDeServidor) await usarCache();
      if (resultado == null) error = e.message;
    }

    if (!mounted) return;
    final plan = resultado;
    setState(() {
      _cargando = false;
      _error = error;
      _planGuardadoEn = guardadoEn;
      if (plan != null) _resumen = plan;
    });
  }

  Future<void> _iniciarSesionYGuardar() async {
    final autenticado = await mostrarLoginContextual(
      context,
      motivo:
          'Iniciá sesión para no perder esta parcela y recibir tu plan cada semana.',
    );
    if (autenticado != true || !mounted) return;

    setState(() => _migrando = true);
    final migradas = await migrarParcelasInvitadoACuenta();
    if (!mounted) return;
    setState(() => _migrando = false);

    if (migradas > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            migradas == 1
                ? 'Tu parcela se guardó en tu cuenta.'
                : 'Tus $migradas parcelas se guardaron en tu cuenta.',
          ),
        ),
      );
    }

    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      noAnimationRoute<void>((_) => const RoleHomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(widget.parcela.cultivoNombre),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!auth.estaAutenticado)
              _BannerGuardarDatos(
                cargando: _migrando,
                onIniciarSesion: _iniciarSesionYGuardar,
              ),
            if (_planGuardadoEn != null)
              _BannerPlanGuardado(guardadoEn: _planGuardadoEn!),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const AppLoadingMessage(message: 'Calculando tu plan...');
    }
    if (_error != null) {
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
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _cargar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final resumen = _resumen;
    if (resumen == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            '${widget.parcela.cultivoNombre} · ${widget.parcela.tipoSueloNombre}',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontFamilyFallback: ['Times New Roman', 'serif'],
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RiesgoUi.colorFondoSuavePara(resumen.nivelRiesgoMaximo),
              borderRadius: BorderRadius.circular(AppRadius.cardSmall),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppPill(
                      text: 'Riesgo ${resumen.nivelRiesgoMaximo}',
                      variant: RiesgoUi.variantePara(resumen.nivelRiesgoMaximo),
                    ),
                    if (resumen.diaMasCritico != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        DateFormat(
                          'EEEE d',
                          'es',
                        ).format(resumen.diaMasCritico!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  resumen.descripcionAlerta,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'TU PLAN PARA ESTA SEMANA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          ...resumen.accionesDeLaSemana.map(
            (accion) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(accion)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerPlanGuardado extends StatelessWidget {
  final DateTime guardadoEn;

  const _BannerPlanGuardado({required this.guardadoEn});

  @override
  Widget build(BuildContext context) {
    final hora =
        '${guardadoEn.hour.toString().padLeft(2, '0')}:'
        '${guardadoEn.minute.toString().padLeft(2, '0')}';
    final dia = '${guardadoEn.day}/${guardadoEn.month}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
              'Sin conexión: este es tu plan guardado el $dia a las $hora.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFA56800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerGuardarDatos extends StatelessWidget {
  final bool cargando;
  final VoidCallback onIniciarSesion;

  const _BannerGuardarDatos({
    required this.cargando,
    required this.onIniciarSesion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_outlined,
            color: AppColors.greenDark,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'No perdás tus datos: iniciá sesión para guardar esta parcela.',
              style: TextStyle(fontSize: 12.5, color: AppColors.greenDark),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 36),
            ),
            onPressed: cargando ? null : onIniciarSesion,
            child: cargando
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Iniciar sesión'),
          ),
        ],
      ),
    );
  }
}
