import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../routing/auth_gate.dart';
import '../../../../routing/no_animation_route.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_loading_message.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import '../../../bitacora/presentation/screens/bitacora_screen.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ParcelaViewModel>();
      unawaited(provider.cargarParcelas());
      unawaited(provider.cargarCatalogos());
    });
  }

  Future<void> _cerrarSesion() async {
    await context.read<AuthViewModel>().cerrarSesion();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      noAnimationRoute<void>((_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParcelaViewModel>();
    final nombre = context.watch<AuthViewModel>().nombre;

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
                          nombre != null ? 'Hola, $nombre' : 'Mis parcelas',
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
                    tooltip: 'Toda mi bitácora',
                    icon: const Icon(Icons.menu_book_outlined),
                    color: AppColors.greenDark,
                    onPressed: () => Navigator.of(context).push(
                      noAnimationRoute<void>((_) => const BitacoraScreen()),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Umbrales de riesgo',
                    icon: const Icon(Icons.tune),
                    color: AppColors.greenDark,
                    onPressed: () => Navigator.of(context).push(
                      noAnimationRoute<void>((_) => const UmbralesScreen()),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    icon: const Icon(Icons.logout),
                    color: AppColors.muted,
                    onPressed: _cerrarSesion,
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(provider)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.green,
        icon: const Icon(Icons.add),
        label: const Text('Nueva parcela'),
        onPressed: () async {
          final creada = await Navigator.of(context).push<bool>(
            noAnimationRoute<bool>((_) => const CrearParcelaWizardScreen()),
          );
          if (creada == true) unawaited(provider.cargarParcelas());
        },
      ),
    );
  }

  Widget _buildBody(ParcelaViewModel provider) {
    if (provider.cargando && provider.parcelas.isEmpty) {
      return const AppLoadingMessage(message: 'Cargando tus parcelas...');
    }

    if (provider.error != null && provider.parcelas.isEmpty) {
      return _EstadoVacio(
        icono: Icons.wifi_off,
        mensaje: provider.error!,
        accionTexto: 'Reintentar',
        onAccion: provider.cargarParcelas,
      );
    }

    if (provider.parcelas.isEmpty) {
      return _EstadoVacio(
        icono: Icons.agriculture_outlined,
        mensaje:
            'Todavía no registrás ninguna parcela.\nTocá "Nueva parcela" para empezar.',
        onAccion: provider.cargarParcelas,
        accionTexto: 'Actualizar',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 100),
      itemCount: provider.parcelas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _ParcelaCard(parcela: provider.parcelas[i]),
    );
  }
}

class _ParcelaCard extends StatelessWidget {
  final Parcela parcela;

  const _ParcelaCard({required this.parcela});

  @override
  Widget build(BuildContext context) {
    final cultivo = context.read<ParcelaViewModel>().cultivos.where(
      (c) => c.id == parcela.cultivoId,
    );
    final nombreCultivo = cultivo.isNotEmpty
        ? cultivo.first.nombre
        : 'Parcela #${parcela.id}';

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
                      nombreCultivo,
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
