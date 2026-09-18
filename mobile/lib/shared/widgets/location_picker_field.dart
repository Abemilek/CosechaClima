import 'package:flutter/material.dart';

import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';

class LocationPickerField extends StatefulWidget {
  final TextEditingController latitudCtrl;
  final TextEditingController longitudCtrl;
  final VoidCallback onChanged;

  const LocationPickerField({
    super.key,
    required this.latitudCtrl,
    required this.longitudCtrl,
    required this.onChanged,
  });

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  bool _detectando = false;
  String? _errorGps;
  bool _mostrarManual = false;

  bool get _tieneCoordenadas =>
      widget.latitudCtrl.text.trim().isNotEmpty &&
      widget.longitudCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _mostrarManual = _tieneCoordenadas;
  }

  Future<void> _detectarUbicacion() async {
    setState(() {
      _detectando = true;
      _errorGps = null;
    });
    try {
      final posicion = await LocationService.obtenerUbicacionActual();
      widget.latitudCtrl.text = posicion.latitude.toStringAsFixed(6);
      widget.longitudCtrl.text = posicion.longitude.toStringAsFixed(6);
      widget.onChanged();
    } on LocationException catch (e) {
      setState(() {
        _errorGps = e.message;
        _mostrarManual = true;
      });
    } finally {
      if (mounted) setState(() => _detectando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _tieneCoordenadas ? const Color(0xFFEDF8ED) : AppColors.mint,
            borderRadius: BorderRadius.circular(AppRadius.cardSmall),
            border: Border.all(
              color: _tieneCoordenadas ? AppColors.green : Colors.transparent,
              width: _tieneCoordenadas ? 2 : 0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _tieneCoordenadas ? Icons.check_circle : Icons.my_location,
                    color: AppColors.greenDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _tieneCoordenadas
                          ? 'Ubicación detectada'
                          : 'Usá tu ubicación GPS',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _tieneCoordenadas
                    ? 'Lat ${widget.latitudCtrl.text}, Lon ${widget.longitudCtrl.text}'
                    : 'Es la forma más fácil y precisa — solo necesitás dar permiso una vez.',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _detectando ? null : _detectarUbicacion,
                  icon: _detectando
                      ? const Icon(Icons.hourglass_empty, size: 18)
                      : Icon(
                          _tieneCoordenadas ? Icons.refresh : Icons.my_location,
                          size: 18,
                        ),
                  label: Text(
                    _tieneCoordenadas
                        ? 'Detectar de nuevo'
                        : 'Detectar mi ubicación',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_errorGps != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.amberBg,
              borderRadius: BorderRadius.circular(AppRadius.cardSmall),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFFA56800),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorGps!,
                    style: const TextStyle(fontSize: 13, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => setState(() => _mostrarManual = !_mostrarManual),
          icon: Icon(
            _mostrarManual ? Icons.expand_less : Icons.expand_more,
            size: 18,
          ),
          label: Text(
            _mostrarManual
                ? 'Ocultar entrada manual'
                : 'Ingresar coordenadas a mano',
          ),
        ),
        if (_mostrarManual) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LATITUD',
                      style: TextStyle(
                        color: AppColors.soil,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: widget.latitudCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      onChanged: (_) => setState(widget.onChanged),
                      decoration: const InputDecoration(hintText: '11.85'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LONGITUD',
                      style: TextStyle(
                        color: AppColors.soil,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: widget.longitudCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      onChanged: (_) => setState(widget.onChanged),
                      decoration: const InputDecoration(hintText: '-86.19'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        if (!_tieneCoordenadas) ...[
          const SizedBox(height: 8),
          const Text(
            'Sin coordenadas no se va a poder consultar el clima de esta parcela.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}
