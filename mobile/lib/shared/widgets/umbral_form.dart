import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum SensibilidadUmbral { alta, media, baja }

class UmbralPreset {
  final double lluviaIntensaMm;
  final double vientoFuerteKmh;
  final double caniculaDias;

  const UmbralPreset({
    required this.lluviaIntensaMm,
    required this.vientoFuerteKmh,
    required this.caniculaDias,
  });
}

const Map<SensibilidadUmbral, UmbralPreset> umbralPresets = {
  SensibilidadUmbral.alta: UmbralPreset(
    lluviaIntensaMm: 70,
    vientoFuerteKmh: 30,
    caniculaDias: 5,
  ),
  SensibilidadUmbral.media: UmbralPreset(
    lluviaIntensaMm: 100,
    vientoFuerteKmh: 40,
    caniculaDias: 7,
  ),
  SensibilidadUmbral.baja: UmbralPreset(
    lluviaIntensaMm: 130,
    vientoFuerteKmh: 50,
    caniculaDias: 10,
  ),
};

SensibilidadUmbral _sensibilidadMasCercana({
  required double lluviaIntensaMm,
  required double vientoFuerteKmh,
  required double caniculaDias,
}) {
  var mejor = SensibilidadUmbral.media;
  var mejorDistancia = double.infinity;
  for (final entry in umbralPresets.entries) {
    final preset = entry.value;
    final distancia =
        (preset.lluviaIntensaMm - lluviaIntensaMm).abs() +
        (preset.vientoFuerteKmh - vientoFuerteKmh).abs() +
        (preset.caniculaDias - caniculaDias).abs();
    if (distancia < mejorDistancia) {
      mejorDistancia = distancia;
      mejor = entry.key;
    }
  }
  return mejor;
}

bool _esValorPersonalizado({
  required double lluviaIntensaMm,
  required double vientoFuerteKmh,
  required double caniculaDias,
}) {
  final cercana = _sensibilidadMasCercana(
    lluviaIntensaMm: lluviaIntensaMm,
    vientoFuerteKmh: vientoFuerteKmh,
    caniculaDias: caniculaDias,
  );
  final preset = umbralPresets[cercana]!;
  return preset.lluviaIntensaMm != lluviaIntensaMm ||
      preset.vientoFuerteKmh != vientoFuerteKmh ||
      preset.caniculaDias != caniculaDias;
}

class UmbralForm extends StatefulWidget {
  final double lluviaIntensaMm;
  final double vientoFuerteKmh;
  final double caniculaDias;
  final ValueChanged<double> onLluviaChanged;
  final ValueChanged<double> onVientoChanged;
  final ValueChanged<double> onCaniculaChanged;

  const UmbralForm({
    super.key,
    required this.lluviaIntensaMm,
    required this.vientoFuerteKmh,
    required this.caniculaDias,
    required this.onLluviaChanged,
    required this.onVientoChanged,
    required this.onCaniculaChanged,
  });

  @override
  State<UmbralForm> createState() => _UmbralFormState();
}

class _UmbralFormState extends State<UmbralForm> {
  late bool _modoAvanzado;

  @override
  void initState() {
    super.initState();
    _modoAvanzado = _esValorPersonalizado(
      lluviaIntensaMm: widget.lluviaIntensaMm,
      vientoFuerteKmh: widget.vientoFuerteKmh,
      caniculaDias: widget.caniculaDias,
    );
  }

  void _aplicarPreset(SensibilidadUmbral sensibilidad) {
    final preset = umbralPresets[sensibilidad]!;
    widget.onLluviaChanged(preset.lluviaIntensaMm);
    widget.onVientoChanged(preset.vientoFuerteKmh);
    widget.onCaniculaChanged(preset.caniculaDias);
  }

  @override
  Widget build(BuildContext context) {
    final sensibilidadActual = _sensibilidadMasCercana(
      lluviaIntensaMm: widget.lluviaIntensaMm,
      vientoFuerteKmh: widget.vientoFuerteKmh,
      caniculaDias: widget.caniculaDias,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_modoAvanzado) ...[
          const Text(
            '¿Qué tan seguido querés recibir alertas?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Con "Media" alcanza para la mayoría de las parcelas — es la opción recomendada.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _SensibilidadSelector(
            seleccionado: sensibilidadActual,
            onSelect: _aplicarPreset,
          ),
          const SizedBox(height: 14),
        ],
        _ModoAvanzadoToggle(
          activo: _modoAvanzado,
          onChanged: (activo) => setState(() => _modoAvanzado = activo),
        ),
        if (_modoAvanzado) ...[
          const SizedBox(height: 14),
          _SliderCard(
            titulo: 'Lluvia intensa',
            valor: widget.lluviaIntensaMm,
            min: 50,
            max: 150,
            divisiones: 10,
            unidad: 'mm/24h',
            onChanged: widget.onLluviaChanged,
          ),
          const SizedBox(height: 14),
          _SliderCard(
            titulo: 'Viento fuerte',
            valor: widget.vientoFuerteKmh,
            min: 20,
            max: 60,
            divisiones: 8,
            unidad: 'km/h',
            onChanged: widget.onVientoChanged,
          ),
          const SizedBox(height: 14),
          _SliderCard(
            titulo: 'Canícula',
            valor: widget.caniculaDias,
            min: 5,
            max: 15,
            divisiones: 10,
            unidad: 'días',
            onChanged: widget.onCaniculaChanged,
          ),
        ],
      ],
    );
  }
}

class _SensibilidadSelector extends StatelessWidget {
  final SensibilidadUmbral seleccionado;
  final ValueChanged<SensibilidadUmbral> onSelect;

  const _SensibilidadSelector({
    required this.seleccionado,
    required this.onSelect,
  });

  static const _opciones = [
    (SensibilidadUmbral.alta, 'Alta', 'Avisa más seguido'),
    (SensibilidadUmbral.media, 'Media', 'Recomendada'),
    (SensibilidadUmbral.baja, 'Baja', 'Solo eventos fuertes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _opciones.map((opcion) {
        final (valor, etiqueta, ayuda) = opcion;
        final activo = valor == seleccionado;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: valor == SensibilidadUmbral.baja ? 0 : 8,
            ),
            child: Material(
              color: activo ? AppColors.mint : AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.cardSmall),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.cardSmall),
                onTap: () => onSelect(valor),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.cardSmall),
                    border: Border.all(
                      color: activo ? AppColors.green : const Color(0xFFE8D8C8),
                      width: activo ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        etiqueta,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: activo ? AppColors.greenDark : AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ayuda,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ModoAvanzadoToggle extends StatelessWidget {
  final bool activo;
  final ValueChanged<bool> onChanged;

  const _ModoAvanzadoToggle({required this.activo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        onTap: () => onChanged(!activo),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                activo ? Icons.tune : Icons.tune_outlined,
                size: 18,
                color: AppColors.soil,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activo
                      ? 'Modo avanzado (ver mm, km/h y días exactos)'
                      : '¿Sos técnico o querés personalizar los números?',
                  style: const TextStyle(
                    color: AppColors.soil,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Switch(
                value: activo,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.green,
              ),
            ],
          ),
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
