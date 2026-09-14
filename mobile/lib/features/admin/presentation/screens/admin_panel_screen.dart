import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../data/models/regla_decision.dart';
import '../../data/services/regla_decision_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late final ReglaDecisionService _service;

  bool _cargando = true;
  bool _ejecutandoAccion = false;
  String? _error;
  List<ReglaDecision> _reglas = [];

  @override
  void initState() {
    super.initState();
    _service = ReglaDecisionService(ApiClient());
    unawaited(_cargarReglas());
  }

  Future<void> _cargarReglas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final reglas = await _service.obtenerTodas();
      if (mounted) setState(() => _reglas = reglas);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on TimeoutApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _ejecutar(
    Future<void> Function() accion,
    String mensajeExito,
  ) async {
    setState(() => _ejecutandoAccion = true);
    try {
      await accion();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeExito)));
      }
      await _cargarReglas();
    } on ApiException catch (e) {
      _mostrarError(e.message);
    } on NetworkException catch (e) {
      _mostrarError(e.message);
    } on TimeoutApiException catch (e) {
      _mostrarError(e.message);
    } finally {
      if (mounted) setState(() => _ejecutandoAccion = false);
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  Map<String, int> get _conteoPorNivel {
    final mapa = <String, int>{};
    for (final r in _reglas) {
      mapa[r.nivelRiesgo] = (mapa[r.nivelRiesgo] ?? 0) + 1;
    }
    return mapa;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Panel de administrador')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarReglas,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'MOTOR DE DECISIONES',
                style: TextStyle(
                  color: AppColors.soil,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Mantenimiento de reglas',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: ['Times New Roman', 'serif'],
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(AppRadius.cardSmall),
                  border: Border.all(color: const Color(0xFFE8D8C8)),
                ),
                child: _cargando
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _error != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.red),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _cargarReglas,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.rule_outlined,
                                color: AppColors.greenDark,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_reglas.length} reglas cargadas',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          if (_reglas.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _conteoPorNivel.entries
                                  .map(
                                    (e) =>
                                        AppPill(text: '${e.key}: ${e.value}'),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Estas acciones modifican el árbol de reglas para TODOS los '
                'usuarios de la app. Usalas solo durante la configuración '
                'inicial o una migración de contenido.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _ejecutandoAccion
                    ? null
                    : () => _confirmarYEjecutar(
                        titulo: '¿Sembrar reglas iniciales?',
                        contenido:
                            'Genera las reglas placeholder si todavía no existen. '
                            'No duplica las que ya estén cargadas.',
                        accion: _service.sembrarReglasIniciales,
                        mensajeExito:
                            'Reglas iniciales sembradas (o ya existían).',
                      ),
                icon: const Icon(Icons.grass_outlined, size: 18),
                label: const Text('Sembrar reglas iniciales'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _ejecutandoAccion
                    ? null
                    : () => _confirmarYEjecutar(
                        titulo: '¿Aplicar contenido preliminar?',
                        contenido:
                            'Sobrescribe un conjunto representativo de reglas con '
                            'contenido agronómico preliminar.',
                        accion: _service.aplicarContenidoPreliminar,
                        mensajeExito: 'Contenido preliminar aplicado.',
                      ),
                icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
                label: const Text('Aplicar contenido preliminar'),
              ),
              if (_ejecutandoAccion) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarYEjecutar({
    required String titulo,
    required String contenido,
    required Future<void> Function() accion,
    required String mensajeExito,
  }) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Text(contenido),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _ejecutar(accion, mensajeExito);
    }
  }
}
