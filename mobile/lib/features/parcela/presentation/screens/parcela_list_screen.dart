import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../routing/no_animation_route.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_loading_message.dart';
import '../../../backup/presentation/screens/copia_seguridad_screen.dart';
import '../../../bitacora/presentation/screens/bitacora_screen.dart';
import '../../../onboarding/presentation/screens/acerca_de_screen.dart';
import '../../../onboarding/presentation/screens/public_home_screen.dart';
import '../../../umbral/presentation/screens/umbrales_screen.dart';
import '../../data/models/parcela_local.dart';
import '../../data/services/parcela_local_store.dart';
import 'crear_parcela_wizard_screen.dart';
import 'parcela_local_detail_screen.dart';

class ParcelaListScreen extends StatefulWidget {
  const ParcelaListScreen({super.key});

  @override
  State<ParcelaListScreen> createState() => _ParcelaListScreenState();
}

class _ParcelaListScreenState extends State<ParcelaListScreen> {
  final _store = ParcelaLocalStore();
  List<ParcelaLocal> _parcelas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    unawaited(_recargar());
  }

  Future<void> _recargar() async {
    final parcelas = await _store.listar();
    if (!mounted) return;
    setState(() {
      _parcelas = parcelas;
      _cargando = false;
    });
  }

  Future<void> _nuevaParcela() async {
    final creada = await Navigator.of(context).push<bool>(
      noAnimationRoute<bool>((_) => const CrearParcelaWizardScreen()),
    );
    if (creada == true) unawaited(_recargar());
  }

  Future<void> _abrirParcela(ParcelaLocal parcela) async {
    await Navigator.of(context).push<void>(
      noAnimationRoute<void>((_) => ParcelaLocalDetailScreen(parcela: parcela)),
    );
    unawaited(_recargar());
  }

  Future<void> _abrir(Widget pantalla) async {
    final resultado = await Navigator.of(context)
        .push<bool>(noAnimationRoute<bool>((_) => pantalla));
    if (resultado == true) unawaited(_recargar());
  }

  Future<void> _abrirMenu(String opcion) async {
    switch (opcion) {
      case 'clima':
        await Navigator.of(
          context,
        ).push<void>(noAnimationRoute<void>((_) => const PublicHomeScreen()));
        break;
      case 'cuaderno':
        await _abrir(const BitacoraScreen());
        break;
      case 'alertas':
        await _abrir(const UmbralesScreen());
        break;
      case 'copia':
        await _abrir(const CopiaSeguridadScreen());
        break;
      case 'acerca':
        await Navigator.of(context)
            .push<void>(noAnimationRoute<void>((_) => const AcercaDeScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COSECHACLIMA',
                          style: TextStyle(
                            color: AppColors.soil,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Mis parcelas',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontFamilyFallback: ['Times New Roman', 'serif'],
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.greenDark,
                    ),
                    tooltip: 'Más opciones',
                    onSelected: (opcion) => unawaited(_abrirMenu(opcion)),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'clima',
                        child: ListTile(
                          leading: Icon(Icons.wb_sunny_outlined),
                          title: Text('Clima de mi zona'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
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
                        value: 'copia',
                        child: ListTile(
                          leading: Icon(Icons.cloud_download_outlined),
                          title: Text('Copia de seguridad'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'acerca',
                        child: ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('Acerca de CosechaClima'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
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

  Widget _buildBody() {
    if (_cargando) {
      return const AppLoadingMessage(message: 'Cargando tus parcelas...');
    }
    if (_parcelas.isEmpty) {
      return _EstadoVacio(onCrear: _nuevaParcela);
    }

    return Column(
      children: [
        _BannerLocal(
          cantidad: _parcelas.length,
          onCopia: () => unawaited(_abrir(const CopiaSeguridadScreen())),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _recargar,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 100),
              itemCount: _parcelas.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _ParcelaCard(
                parcela: _parcelas[i],
                onTap: () => _abrirParcela(_parcelas[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ParcelaCard extends StatelessWidget {
  final ParcelaLocal parcela;
  final VoidCallback onTap;

  const _ParcelaCard({required this.parcela, required this.onTap});

  IconData get _icono {
    final nombre = parcela.cultivoNombre.toLowerCase();
    if (nombre.contains('café') || nombre.contains('cafe')) {
      return Icons.coffee_outlined;
    }
    if (nombre.contains('arroz')) return Icons.water_drop_outlined;
    if (nombre.contains('frijol')) return Icons.spa_outlined;
    if (nombre.contains('sorgo')) return Icons.grass_outlined;
    return Icons.eco_outlined;
  }

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
              AppAvatar(icon: _icono),
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
                        parcela.municipio ?? parcela.ubicacionTexto,
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

class _BannerLocal extends StatelessWidget {
  final int cantidad;
  final VoidCallback onCopia;

  const _BannerLocal({required this.cantidad, required this.onCopia});

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
                Icons.phone_android,
                color: AppColors.greenDark,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cantidad == 1
                      ? 'Tu parcela está guardada solo en este teléfono.'
                      : 'Tus $cantidad parcelas están guardadas solo en este '
                            'teléfono.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.greenDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: Colors.transparent,
              ),
              onPressed: onCopia,
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
              label: const Text('Hacer copia de seguridad'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final VoidCallback onCrear;

  const _EstadoVacio({required this.onCrear});

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
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.agriculture_outlined,
                      size: 56,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Todavía no registrás ninguna parcela',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: ['Times New Roman', 'serif'],
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Registrá tu cultivo, tu suelo y tu ubicación para ver el '
                    'semáforo de riesgo y el plan de la semana. Todo queda en '
                    'tu teléfono.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onCrear,
                    icon: const Icon(Icons.add),
                    label: const Text('Registrar mi primera parcela'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
