import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_pill.dart';

class AcercaDeScreen extends StatelessWidget {
  const AcercaDeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Acerca de CosechaClima'),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            Text(
              'CosechaClima ayuda a productores de Nicaragua a anticipar riesgos '
              'climáticos y saber qué hacer en su parcela cada semana.',
              style: TextStyle(fontSize: 15, color: AppColors.ink, height: 1.4),
            ),
            SizedBox(height: 24),
            _InfoCard(
              icon: Icons.cloud_outlined,
              titulo: 'Fuente de datos climáticos',
              detalle:
                  'Usamos Open-Meteo, un servicio meteorológico gratuito y de '
                  'código abierto, para obtener temperatura, lluvia y viento '
                  'de cualquier punto de Nicaragua en tiempo casi real.',
            ),
            SizedBox(height: 14),
            _InfoCard(
              icon: Icons.rule_outlined,
              titulo: 'Motor de reglas agroclimáticas',
              detalle:
                  'Un motor de reglas compara esos datos con umbrales por '
                  'cultivo, etapa de crecimiento y tipo de suelo para calcular '
                  'el nivel de riesgo (bajo, medio o alto) y las acciones '
                  'recomendadas para la semana, igual que un boletín '
                  'agrometeorológico del INETER o el INTA.',
            ),
            SizedBox(height: 14),
            _InfoCard(
              icon: Icons.grass_outlined,
              titulo: 'Cultivos',
              detalle:
                  'Por ahora hay reglas cargadas para maíz, frijol, arroz, '
                  'sorgo y café: los principales granos básicos y el rubro de '
                  'exportación más importante de Nicaragua.',
            ),
            SizedBox(height: 14),
            _InfoCard(
              icon: Icons.verified_user_outlined,
              titulo: 'Cobertura',
              detalle:
                  'CosechaClima cubre todo el territorio de Nicaragua: los 15 '
                  'departamentos y las 2 regiones autónomas.',
            ),
            SizedBox(height: 24),
            AppPill(
              icon: Icons.school_outlined,
              text: 'Proyecto universitario',
            ),
            SizedBox(height: 8),
            Text(
              'CosechaClima es un proyecto académico sin fines de lucro.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String detalle;

  const _InfoCard({
    required this.icon,
    required this.titulo,
    required this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        border: Border.all(color: const Color(0xFFE8D8C8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.green, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detalle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
