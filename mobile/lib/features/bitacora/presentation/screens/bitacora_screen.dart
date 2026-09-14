import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../data/models/bitacora.dart';
import '../../data/services/bitacora_service.dart';

class BitacoraScreen extends StatefulWidget {
  final int? parcelaId;
  final bool mostrarAppBar;

  const BitacoraScreen({super.key, this.parcelaId, this.mostrarAppBar = true});

  @override
  State<BitacoraScreen> createState() => _BitacoraScreenState();
}

class _BitacoraScreenState extends State<BitacoraScreen> {
  late final BitacoraService _service;
  List<BitacoraEntry> _entradas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = BitacoraService(ApiClient());
    unawaited(_cargar());
  }

  List<BitacoraEntry> get _entradasFiltradas => widget.parcelaId == null
      ? _entradas
      : _entradas.where((e) => e.parcelaId == widget.parcelaId).toList();

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    List<BitacoraEntry>? entradas;
    String? error;
    try {
      entradas = await _service.obtenerMias();
    } on ApiException catch (e) {
      error = e.message;
    } on NetworkException catch (e) {
      error = e.message;
    } on TimeoutApiException catch (e) {
      error = e.message;
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = error;
          if (entradas != null) _entradas = entradas;
        });
      }
    }
  }

  Future<void> _marcarAccion(BitacoraEntry entrada, int numero) async {
    try {
      await _service.marcarAccion(entrada.id, numero);
      if (!mounted) return;
      await _cargar();
    } on ApiException catch (e) {
      _mostrarError(e.message);
    } on NetworkException catch (e) {
      _mostrarError(e.message);
    } on TimeoutApiException catch (e) {
      _mostrarError(e.message);
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  Future<void> _verResumen() async {
    try {
      final resumen = await _service.obtenerResumen();
      if (!mounted) return;
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Resumen para compartir'),
            content: SingleChildScrollView(child: Text(resumen)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
    } on ApiException catch (e) {
      _mostrarError(e.message);
    } on NetworkException catch (e) {
      _mostrarError(e.message);
    } on TimeoutApiException catch (e) {
      _mostrarError(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(onRefresh: _cargar, child: _buildBody());
    if (!widget.mostrarAppBar) return body;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Bitácora de campo'),
        actions: [
          IconButton(
            tooltip: 'Ver resumen para compartir',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: _entradasFiltradas.isEmpty ? null : _verResumen,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Center(child: Text(_error!)),
        ],
      );
    }
    final entradas = _entradasFiltradas;
    if (entradas.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Center(child: Text('Todavía no hay entradas en la bitácora.')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entradas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _TimelineCard(
        entrada: entradas[i],
        onMarcar: (numero) => _marcarAccion(entradas[i], numero),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final BitacoraEntry entrada;
  final ValueChanged<int> onMarcar;

  const _TimelineCard({required this.entrada, required this.onMarcar});

  Color get _borderColor {
    switch (entrada.nivelRiesgo.toLowerCase()) {
      case 'alto':
        return AppColors.red;
      case 'medio':
        return AppColors.amber;
      default:
        return AppColors.green;
    }
  }

  AppPillVariant get _pillVariant {
    switch (entrada.nivelRiesgo.toLowerCase()) {
      case 'alto':
        return AppPillVariant.red;
      case 'medio':
        return AppPillVariant.warn;
      default:
        return AppPillVariant.normal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border(left: BorderSide(color: _borderColor, width: 4)),
        boxShadow: AppShadows.soft,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppPill(
                text: 'Riesgo ${entrada.nivelRiesgo}',
                variant: _pillVariant,
              ),
              Text(
                DateFormat('dd MMM, HH:mm', 'es').format(entrada.fecha),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _accionTile(1, entrada.accion1Texto, entrada.accion1Completada),
          _accionTile(2, entrada.accion2Texto, entrada.accion2Completada),
          _accionTile(3, entrada.accion3Texto, entrada.accion3Completada),
          if (entrada.notas != null && entrada.notas!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entrada.notas!,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _accionTile(int numero, String texto, bool completada) {
    return InkWell(
      onTap: completada ? null : () => onMarcar(numero),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              completada ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: completada ? AppColors.green : AppColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                  decoration: completada ? TextDecoration.lineThrough : null,
                  color: completada ? AppColors.muted : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
