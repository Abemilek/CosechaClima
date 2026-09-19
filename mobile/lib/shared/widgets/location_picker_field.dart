import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../controllers/location_picker_controller.dart';

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
  late final LocationPickerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LocationPickerController(
      latitudCtrl: widget.latitudCtrl,
      longitudCtrl: widget.longitudCtrl,
      onChanged: widget.onChanged,
    )..addListener(_actualizar);
  }

  @override
  void dispose() {
    _controller.removeListener(_actualizar);
    _controller.dispose();
    super.dispose();
  }

  void _actualizar() {
    if (mounted) setState(() {});
  }

  bool get _tieneCoordenadas => _controller.tieneCoordenadas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LocationCard(
          controller: _controller,
          latitud: widget.latitudCtrl.text,
          longitud: widget.longitudCtrl.text,
        ),
        if (_controller.message != null) ...[
          const SizedBox(height: 10),
          _StateMessage(controller: _controller),
        ],
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _controller.cambiarManualVisible,
          icon: Icon(
            _controller.mostrarManual ? Icons.expand_less : Icons.expand_more,
            size: 18,
          ),
          label: Text(
            _controller.mostrarManual
                ? 'Ocultar entrada manual'
                : 'Editar coordenadas manualmente',
          ),
        ),
        if (_controller.mostrarManual) ...[
          const SizedBox(height: 6),
          _ManualLocationFields(controller: _controller),
        ],
        if (!_tieneCoordenadas) ...[
          const SizedBox(height: 8),
          const Text(
            'Sin coordenadas se puede registrar la parcela, pero el clima será menos preciso.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final LocationPickerController controller;
  final String latitud;
  final String longitud;

  const _LocationCard({
    required this.controller,
    required this.latitud,
    required this.longitud,
  });

  @override
  Widget build(BuildContext context) {
    final tieneCoordenadas = controller.tieneCoordenadas;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tieneCoordenadas ? const Color(0xFFEDF8ED) : AppColors.mint,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(
          color: tieneCoordenadas ? AppColors.green : Colors.transparent,
          width: tieneCoordenadas ? 2 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconForStatus(controller.status, tieneCoordenadas),
                color: AppColors.greenDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _titleForStatus(controller.status, tieneCoordenadas),
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
            tieneCoordenadas
                ? 'Lat $latitud, Lon $longitud'
                : 'El clima cambia por zona. Detectar la parcela ayuda a calcular alertas más útiles.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: controller.estaTrabajando
                  ? null
                  : controller.continuarConGps,
              icon: Icon(
                controller.estaTrabajando
                    ? Icons.hourglass_empty
                    : tieneCoordenadas
                    ? Icons.refresh
                    : Icons.my_location,
                size: 18,
              ),
              label: Text(
                controller.estaTrabajando
                    ? _workingLabel(controller.status)
                    : tieneCoordenadas
                    ? 'Detectar de nuevo'
                    : 'Detectar mi ubicación',
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForStatus(
    LocationPickerStatus status,
    bool tieneCoordenadas,
  ) {
    if (tieneCoordenadas) return Icons.check_circle;
    switch (status) {
      case LocationPickerStatus.permissionDenied:
      case LocationPickerStatus.permissionDeniedForever:
      case LocationPickerStatus.error:
        return Icons.info_outline;
      case LocationPickerStatus.openingLocationSettings:
        return Icons.settings_outlined;
      case LocationPickerStatus.locating:
      case LocationPickerStatus.checkingHardware:
      case LocationPickerStatus.requestingPermission:
        return Icons.hourglass_empty;
      case LocationPickerStatus.idle:
      case LocationPickerStatus.success:
        return Icons.my_location;
    }
  }

  static String _titleForStatus(
    LocationPickerStatus status,
    bool tieneCoordenadas,
  ) {
    if (tieneCoordenadas) return 'Ubicación detectada';
    switch (status) {
      case LocationPickerStatus.openingLocationSettings:
        return 'GPS apagado';
      case LocationPickerStatus.requestingPermission:
        return 'Permiso de ubicación';
      case LocationPickerStatus.permissionDenied:
        return 'Permiso no concedido';
      case LocationPickerStatus.permissionDeniedForever:
        return 'Permiso bloqueado';
      case LocationPickerStatus.locating:
        return 'Detectando ubicación';
      case LocationPickerStatus.error:
        return 'No se pudo detectar';
      case LocationPickerStatus.idle:
      case LocationPickerStatus.checkingHardware:
      case LocationPickerStatus.success:
        return 'Usá tu ubicación GPS';
    }
  }

  static String _workingLabel(LocationPickerStatus status) {
    switch (status) {
      case LocationPickerStatus.checkingHardware:
        return 'Revisando GPS...';
      case LocationPickerStatus.openingLocationSettings:
        return 'Abrí Ajustes...';
      case LocationPickerStatus.requestingPermission:
        return 'Esperando permiso...';
      case LocationPickerStatus.locating:
        return 'Detectando ubicación...';
      case LocationPickerStatus.idle:
      case LocationPickerStatus.permissionDenied:
      case LocationPickerStatus.permissionDeniedForever:
      case LocationPickerStatus.success:
      case LocationPickerStatus.error:
        return 'Detectar mi ubicación';
    }
  }
}

class _StateMessage extends StatelessWidget {
  final LocationPickerController controller;

  const _StateMessage({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isWarning =
        controller.status == LocationPickerStatus.permissionDenied ||
        controller.status == LocationPickerStatus.permissionDeniedForever ||
        controller.status == LocationPickerStatus.openingLocationSettings ||
        controller.status == LocationPickerStatus.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarning ? AppColors.amberBg : AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isWarning ? Icons.info_outline : Icons.shield_outlined,
                size: 18,
                color: isWarning ? const Color(0xFFA56800) : AppColors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.message!,
                  style: const TextStyle(fontSize: 13, color: AppColors.ink),
                ),
              ),
            ],
          ),
          if (controller.requiereAjustesApp ||
              controller.status == LocationPickerStatus.openingLocationSettings)
            const SizedBox(height: 10),
          if (controller.requiereAjustesApp)
            OutlinedButton.icon(
              onPressed: controller.abrirAjustesApp,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Abrir ajustes de la app'),
            ),
          if (controller.status == LocationPickerStatus.openingLocationSettings)
            OutlinedButton.icon(
              onPressed: controller.abrirAjustesGps,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Abrir ajustes de ubicación'),
            ),
        ],
      ),
    );
  }
}

class _ManualLocationFields extends StatelessWidget {
  final LocationPickerController controller;

  const _ManualLocationFields({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _CoordinateField(
                label: 'LATITUD',
                hint: '11.85',
                controller: controller.latitudCtrl,
                onChanged: controller.notificarCambioManual,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CoordinateField(
                label: 'LONGITUD',
                hint: '-86.19',
                controller: controller.longitudCtrl,
                onChanged: controller.notificarCambioManual,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CoordinateField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _CoordinateField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.soil,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
