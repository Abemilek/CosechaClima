import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/clima/open_meteo_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/riesgo_ui.dart';
import '../../../../shared/widgets/app_loading_message.dart';
import '../../../../shared/widgets/app_pill.dart';
import '../../data/models/clima.dart';

/// Resumen de la semana. El cálculo lo hace la pantalla de detalle (motor local);
/// esta pestaña solo lo muestra, así que no hace ninguna petición propia.
class ResumenSemanalTab extends StatelessWidget {
  final ResumenSemanal? resumenSemanal;
  final bool cargando;
  final String? error;
  final bool sinCoordenadas;
  final Future<void> Function() onRefrescar;

  const ResumenSemanalTab({
    super.key,
    required this.resumenSemanal,
    required this.cargando,
    required this.error,
    required this.sinCoordenadas,
    required this.onRefrescar,
  });

  @override
  Widget build(BuildContext context) {
    if (sinCoordenadas) {
      return const _MensajeCentrado(
        icono: Icons.location_off_outlined,
        texto:
            'Agregá la ubicación de tu parcela para ver el resumen de la semana.',
      );
    }
    if (cargando) {
      return const AppLoadingMessage(message: 'Calculando la semana...');
    }
    final mensajeError = error;
    if (mensajeError != null) {
      return _MensajeCentrado(
        icono: Icons.cloud_off_outlined,
        texto: mensajeError,
        onReintentar: onRefrescar,
      );
    }
    final resumen = resumenSemanal;
    if (resumen == null || resumen.dias.isEmpty) {
      return const _MensajeCentrado(
        icono: Icons.cloud_off_outlined,
        texto: 'No hay pronóstico disponible por ahora.',
      );
    }

    return RefreshIndicator(
      onRefresh: onRefrescar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          const Text(
            'RESUMEN DE LA SEMANA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: resumen.dias.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _DiaChip(dia: resumen.dias[i]),
            ),
          ),
          const SizedBox(height: 20),
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
            'ACCIONES PARA ESTA SEMANA',
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
          const SizedBox(height: 8),
          const Text(
            'Este resumen se recalcula con el pronóstico más reciente; no hace '
            'falta revisarlo todos los días, con una vez a la semana alcanza '
            'para programar tus labores.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            OpenMeteoClient.atribucion,
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _DiaChip extends StatelessWidget {
  final DiaResumenSemanal dia;

  const _DiaChip({required this.dia});

  @override
  Widget build(BuildContext context) {
    final color = RiesgoUi.colorPara(dia.nivelRiesgo);
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: RiesgoUi.colorFondoSuavePara(dia.nivelRiesgo),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('EEE', 'es').format(dia.fecha),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('d').format(dia.fecha),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MensajeCentrado extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback? onReintentar;

  const _MensajeCentrado({
    required this.icono,
    required this.texto,
    this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            if (onReintentar != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onReintentar,
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
