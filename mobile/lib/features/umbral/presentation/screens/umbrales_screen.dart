import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_loading_message.dart';
import '../../data/models/umbral.dart';
import '../../data/services/umbral_service.dart';

class UmbralesScreen extends StatefulWidget {
  const UmbralesScreen({super.key});

  @override
  State<UmbralesScreen> createState() => _UmbralesScreenState();
}

class _UmbralesScreenState extends State<UmbralesScreen> {
  late final UmbralService _service;

  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  double _lluviaIntensaMm = 100;
  double _vientoFuerteKmh = 40;
  double _caniculaDias = 7;
  String _variedadCultivo = 'Criollo';
  bool _tieneRiego = false;
  TimeOfDay _horarioSms = const TimeOfDay(hour: 6, minute: 0);

  static const _variedades = ['Criollo', 'Hibrido', 'Mejorado'];
  static const _horarios = [
    TimeOfDay(hour: 5, minute: 0),
    TimeOfDay(hour: 6, minute: 0),
    TimeOfDay(hour: 7, minute: 0),
    TimeOfDay(hour: 8, minute: 0),
  ];

  @override
  void initState() {
    super.initState();
    _service = UmbralService(ApiClient());
    unawaited(_cargar());
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    String? error;
    try {
      final umbral = await _service.obtenerMios();
      if (umbral != null) {
        _lluviaIntensaMm = umbral.lluviaIntensaMm.toDouble().clamp(50, 150);
        _vientoFuerteKmh = umbral.vientoFuerteKmh.toDouble().clamp(20, 60);
        _caniculaDias = umbral.caniculaDias.toDouble().clamp(5, 15);
        _variedadCultivo = _variedades.contains(umbral.variedadCultivo)
            ? umbral.variedadCultivo
            : _variedades.first;
        _tieneRiego = umbral.tieneRiego;
        final partes = umbral.horarioSms.split(':');
        final h = TimeOfDay(
          hour: int.parse(partes[0]),
          minute: int.parse(partes[1]),
        );
        _horarioSms = _horarios.contains(h) ? h : _horarios[1];
      }
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
        });
      }
    }
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final horario =
          '${_horarioSms.hour.toString().padLeft(2, '0')}:'
          '${_horarioSms.minute.toString().padLeft(2, '0')}';
      await _service.guardar(
        UmbralRequest(
          lluviaIntensaMm: _lluviaIntensaMm.round(),
          vientoFuerteKmh: _vientoFuerteKmh.round(),
          caniculaDias: _caniculaDias.round(),
          variedadCultivo: _variedadCultivo,
          tieneRiego: _tieneRiego,
          horarioSms: horario,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Umbrales guardados')));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on NetworkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on TimeoutApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Umbrales')),
      body: _cargando
          ? const AppLoadingMessage(message: 'Cargando umbrales...')
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'CONFIGURACIÓN PERSONAL',
                    style: TextStyle(
                      color: AppColors.soil,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ajustá tus alertas',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: ['Times New Roman', 'serif'],
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Podés dejar los valores recomendados o adaptarlos a tu experiencia en la parcela.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                  _SliderCard(
                    titulo: 'Lluvia intensa',
                    valor: _lluviaIntensaMm,
                    min: 50,
                    max: 150,
                    divisiones: 10,
                    unidad: 'mm/24h',
                    onChanged: (v) => setState(() => _lluviaIntensaMm = v),
                  ),
                  const SizedBox(height: 14),
                  _SliderCard(
                    titulo: 'Viento fuerte',
                    valor: _vientoFuerteKmh,
                    min: 20,
                    max: 60,
                    divisiones: 8,
                    unidad: 'km/h',
                    onChanged: (v) => setState(() => _vientoFuerteKmh = v),
                  ),
                  const SizedBox(height: 14),
                  _SliderCard(
                    titulo: 'Canícula',
                    valor: _caniculaDias,
                    min: 5,
                    max: 15,
                    divisiones: 10,
                    unidad: 'días',
                    onChanged: (v) => setState(() => _caniculaDias = v),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'VARIEDAD DEL CULTIVO',
                    style: TextStyle(
                      color: AppColors.soil,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _variedadCultivo,
                    items: _variedades
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(
                      () => _variedadCultivo = v ?? _variedadCultivo,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ToggleCard(
                    titulo: 'Disponibilidad de riego',
                    subtitulo: 'Modifica las acciones ante sequía.',
                    valor: _tieneRiego,
                    onChanged: (v) => setState(() => _tieneRiego = v),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'HORARIO DE ALERTAS',
                    style: TextStyle(
                      color: AppColors.soil,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TimeOfDay>(
                    initialValue: _horarioSms,
                    items: _horarios
                        .map(
                          (h) => DropdownMenuItem(
                            value: h,
                            child: Text(h.format(context)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _horarioSms = v ?? _horarioSms),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: const TextStyle(color: AppColors.red)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: Text(
                      _guardando ? 'Guardando...' : 'Guardar umbrales',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SliderCard extends StatelessWidget {
  final String titulo;
  final double valor;
  final double min;
  final double max;
  final int divisiones;
  final String unidad;
  final ValueChanged<double> onChanged;

  const _SliderCard({
    required this.titulo,
    required this.valor,
    required this.min,
    required this.max,
    required this.divisiones,
    required this.unidad,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                '${valor.round()} $unidad',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.greenDark,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.green,
              thumbColor: AppColors.green,
              inactiveTrackColor: AppColors.soft,
            ),
            child: Slider(
              value: valor,
              min: min,
              max: max,
              divisions: divisiones,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final bool valor;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitulo,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: valor,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.green,
          ),
        ],
      ),
    );
  }
}
