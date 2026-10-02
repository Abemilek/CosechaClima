import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/cache/guest_parcela_migration.dart';
import '../../../../core/cache/guest_parcela_store.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routing/auth_gate.dart';
import '../../../../routing/no_animation_route.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_loading_message.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../auth/presentation/screens/login_sheet.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import '../../../bitacora/presentation/screens/bitacora_screen.dart';
import '../../../onboarding/presentation/screens/guest_parcela_detail_screen.dart';
import '../../../umbral/data/services/umbral_service.dart';
import '../../../umbral/presentation/screens/umbrales_screen.dart';
import '../../data/models/parcela.dart';
import '../view_models/parcela_view_model.dart';
import 'crear_parcela_wizard_screen.dart';
import 'detalle_parcela_screen.dart';

class ParcelaListScreen extends StatefulWidget {
  const ParcelaListScreen({super.key});

  @override
  State<ParcelaListScreen> createState() => _ParcelaListScreenState();
}

class _ParcelaListScreenState extends State<ParcelaListScreen> {
  final _store = GuestParcelaStore();
  List<GuestParcela> _locales = [];
  bool _cargandoLocales = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_recargar());
    });
  }

  Future<void> _recargar() async {
    if (!mounted) return;
    final auth = context.read<AuthViewModel>();
    final provider = context.read<ParcelaViewModel>();

    if (auth.estaAutenticado) {
      await provider.cargarParcelas();

      final enLinea =
          !provider.mostrandoDatosGuardados && provider.error == null;
      if (enLinea) {
        unawaited(UmbralService(ApiClient()).sincronizarPendientes());
        final migradas = await migrarParcelasInvitadoACuenta();
        if (migradas > 0) await provider.cargarParcelas();
      }
      unawaited(provider.cargarCatalogos());
    }

    final locales = await _store.listar();
    if (!mounted) return;
    setState(() {
      _locales = locales;
      _cargandoLocales = false;
    });
  }

  Future<void> _iniciarSesion() async {
    final ok = await mostrarLoginContextual(
      context,
      motivo: 'Iniciá sesión para no perder tus parcelas',
    );
    if (ok != true || !mounted) return;
    await _recargar();
  }

  Future<void> _cerrarSesion() async {
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: '¿Deseas cerrar la sesión?',
      mensaje: 'Vas a tener que iniciar sesión de nuevo para ver tus parcelas.',
      textoConfirmar: 'Cerrar sesión',
      esDestructivo: true,
    );
    if (!confirmado || !mounted) return;

    await context.read<AuthViewModel>().cerrarSesion();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      noAnimationRoute<void>((_) => const AuthGate()),
      (route) => false,
    );
  }

  Future<void> _nuevaParcela() async {
    final auth = context.read<AuthViewModel>();
    final creada = await Navigator.of(context).push<bool>(
      noAnimationRoute<bool>(
        (_) => CrearParcelaWizardScreen(esInvitado: !auth.estaAutenticado),
      ),
    );
    if (creada == true) unawaited(_recargar());
  }

  Future<void> _abrirDetalleLocal(GuestParcela parcela) async {
    await Navigator.of(context).push<void>(
      noAnimationRoute<void>((_) => GuestParcelaDetailScreen(parcela: parcela)),
    );
    unawaited(_recargar());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParcelaViewModel>();
    final auth = context.watch<AuthViewModel>();
    final nombre = auth.nombre;
    final esInvitado = !auth.estaAutenticado;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const AppAvatar(icon: Icons.eco_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COSECHACLIMA',
                          style: TextStyle(
                            color: AppColors.soil,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          !esInvitado && nombre != null
                              ? 'Hola, $nombre'
                              : 'Mis parcelas',
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
                  if (!esInvitado)
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.greenDark,
                      ),
                      tooltip: 'Más opciones',
                      onSelected: (opcion) {
                        if (opcion == 'cuaderno') {
                          Navigator.of(context).push(
                            noAnimationRoute<void>(
                              (_) => const BitacoraScreen(),
                            ),
                          );
                        }
                        if (opcion == 'alertas') {
                          Navigator.of(context).push(
                            noAnimationRoute<void>(
                              (_) => const UmbralesScreen(),
                            ),
                          );
                        }
                        if (opcion == 'salir') _cerrarSesion();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'cuaderno',
                          child: ListTile(
                            leading: Icon(Icons.menu_book_outlined),
                            title: Text('Mi cuaderno'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'alertas',
                          child: ListTile(
                            leading: Icon(Icons.tune),
                            title: Text('Ajustar mis alertas'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'salir',
                          child: ListTile(
                            leading: Icon(Icons.logout, color: AppColors.red),
                            title: Text(
                              'Cerrar sesión',
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
            Expanded(child: _buildBody(provider, esInvitado)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.green,
        icon: const Icon(Icons.add),
        label: const Text('Nueva parcela'),
        onPressed: _nuevaParcela,
      ),
    );
  }

  Widget _buildBody(ParcelaViewModel provider, bool esInvitado) {
    if (esInvitado) {
      if (_cargandoLocales && _locales.isEmpty) {
        return const AppLoadingMessage(message: 'Cargando tus parcelas...');
      }
      if (_locales.isEmpty) {
        return _EstadoVacio(
          icono: Icons.agriculture_outlined,
          mensaje:
              'Todavía no registrás ninguna parcela.\n'
              'Tocá "Nueva parcela" para empezar.',
          onAccion: _recargar,
          accionTexto: 'Actualizar',
        );
      }
      return Column(
        children: [
          _BannerInvitado(
            cantidad: _locales.length,
            onIniciarSesion: _iniciarSesion,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _recargar,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 100),
                itemCount: _locales.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _ParcelaLocalCard(
                  parcela: _locales[i],
                  onTap: () => _abrirDetalleLocal(_locales[i]),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final hayServidor = provider.parcelas.isNotEmpty;
    final hayLocales = _locales.isNotEmpty;

    if ((provider.cargando || _cargandoLocales) &&
        !hayServidor &&
        !hayLocales) {
      return const AppLoadingMessage(message: 'Cargando tus parcelas...');
    }

    if (provider.error != null && !hayServidor && !hayLocales) {
      return _EstadoVacio(
        icono: Icons.wifi_off,
        mensaje: provider.error!,
        accionTexto: 'Reintentar',
        onAccion: _recargar,
      );
    }

    if (!hayServidor && !hayLocales) {
      return _EstadoVacio(
        icono: Icons.agriculture_outlined,
        mensaje:
            'Todavía no registrás ninguna parcela.\n'
            'Tocá "Nueva parcela" para empezar.',
        onAccion: _recargar,
        accionTexto: 'Actualizar',
      );
    }

    final tarjetas = <Widget>[
      ...provider.parcelas.map((p) => _ParcelaCard(parcela: p)),
      ..._locales.map(
        (p) =>
            _ParcelaLocalCard(parcela: p, onTap: () => _abrirDetalleLocal(p)),
      ),
    ];

    return Column(
      children: [
        if (provider.mostrandoDatosGuardados)
          _BannerSinConexion(provider: provider),
        if (hayLocales)
          _BannerPendientes(
            cantidad: _locales.length,
            onSincronizar: _recargar,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _recargar,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 100),
              itemCount: tarjetas.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => tarjetas[i],
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerInvitado extends StatelessWidget {
  final int cantidad;
  final VoidCallback onIniciarSesion;

  const _BannerInvitado({
    required this.cantidad,
    required this.onIniciarSesion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppColors.greenDark,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cantidad == 1
                      ? 'Tu parcela está guardada solo en este teléfono. '
                            'Iniciá sesión para no perderla.'
                      : 'Tus $cantidad parcelas están guardadas solo en este '
                            'teléfono. Iniciá sesión para no perderlas.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.greenDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.greenDark,
                minimumSize: const Size(0, 40),
              ),
              onPressed: onIniciarSesion,
              child: const Text('Iniciar sesión'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerPendientes extends StatelessWidget {
  final int cantidad;
  final VoidCallback onSincronizar;

  const _BannerPendientes({
    required this.cantidad,
    required this.onSincronizar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.amberBg,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 18,
            color: Color(0xFFA56800),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cantidad == 1
                  ? 'Tenés 1 parcela guardada en este teléfono. Se va a subir '
                        'a tu cuenta cuando haya conexión.'
                  : 'Tenés $cantidad parcelas guardadas en este teléfono. Se '
                        'van a subir a tu cuenta cuando haya conexión.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFA56800)),
            ),
          ),
          TextButton(onPressed: onSincronizar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _BannerSinConexion extends StatelessWidget {
  final ParcelaViewModel provider;

  const _BannerSinConexion({required this.provider});

  @override
  Widget build(BuildContext context) {
    final guardadoEn = provider.datosGuardadosEn;
    final texto = guardadoEn == null
        ? 'Sin conexión: mostrando tus parcelas guardadas.'
        : 'Sin conexión: mostrando datos guardados de las '
              '${guardadoEn.hour.toString().padLeft(2, '0')}:'
              '${guardadoEn.minute.toString().padLeft(2, '0')}.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
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
              texto,
              style: const TextStyle(fontSize: 12, color: Color(0xFFA56800)),
            ),
          ),
          TextButton(
            onPressed: provider.cargando ? null : provider.cargarParcelas,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _ParcelaCard extends StatelessWidget {
  final Parcela parcela;

  const _ParcelaCard({required this.parcela});

  @override
  Widget build(BuildContext context) {
    final cultivos = context.read<ParcelaViewModel>().cultivos;
    String? nombreCultivo;
    for (final c in cultivos) {
      if (c.id == parcela.cultivoId) {
        nombreCultivo = c.nombre;
        break;
      }
    }

    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        onTap: () => Navigator.of(context).push(
          noAnimationRoute<void>((_) => DetalleParcelaScreen(parcela: parcela)),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.cardSmall),
            border: Border.all(color: const Color(0xFFEFE0D3)),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              const AppAvatar(icon: Icons.eco_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreCultivo ?? 'Parcela #${parcela.id}',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontFamilyFallback: ['Times New Roman', 'serif'],
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      [
                        if (parcela.municipio != null) parcela.municipio,
                        '${parcela.areaMzs} mzs',
                        if (!parcela.tieneCoordenadas) 'sin GPS',
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParcelaLocalCard extends StatelessWidget {
  final GuestParcela parcela;
  final VoidCallback onTap;

  const _ParcelaLocalCard({required this.parcela, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.cardSmall),
            border: Border.all(color: const Color(0xFFEFE0D3)),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              const AppAvatar(icon: Icons.eco_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parcela.cultivoNombre,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontFamilyFallback: ['Times New Roman', 'serif'],
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      [
                        parcela.tipoSueloNombre,
                        '${parcela.areaMzs} mzs',
                        if (parcela.municipio != null) parcela.municipio,
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String mensaje;
  final String accionTexto;
  final VoidCallback onAccion;

  const _EstadoVacio({
    required this.icono,
    required this.mensaje,
    required this.accionTexto,
    required this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icono, size: 56, color: AppColors.muted),
                  const SizedBox(height: 16),
                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.ink),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: onAccion, child: Text(accionTexto)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
