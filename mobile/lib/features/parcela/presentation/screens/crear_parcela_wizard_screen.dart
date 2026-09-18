import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_choice_card.dart';
import '../../../../shared/widgets/app_loading_message.dart';
import '../../../../shared/widgets/location_picker_field.dart';
import '../../../../shared/widgets/progress_dots.dart';
import '../../../catalogo/data/models/catalogo.dart';
import '../../data/models/parcela.dart';
import '../view_models/parcela_view_model.dart';

class CrearParcelaWizardScreen extends StatefulWidget {
  const CrearParcelaWizardScreen({super.key});

  @override
  State<CrearParcelaWizardScreen> createState() =>
      _CrearParcelaWizardScreenState();
}

class _CrearParcelaWizardScreenState extends State<CrearParcelaWizardScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const _totalSteps = 4;

  int? _cultivoId;
  int? _tipoSueloId;
  int? _etapaId;
  DateTime _fechaSiembra = DateTime.now();

  final _areaCtrl = TextEditingController(text: '1');
  final _municipioCtrl = TextEditingController();
  final _comunidadCtrl = TextEditingController();
  final _latitudCtrl = TextEditingController();
  final _longitudCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(context.read<ParcelaViewModel>().cargarCatalogos());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _areaCtrl.dispose();
    _municipioCtrl.dispose();
    _comunidadCtrl.dispose();
    _latitudCtrl.dispose();
    _longitudCtrl.dispose();
    super.dispose();
  }

  bool get _puedeAvanzar {
    switch (_step) {
      case 0:
        return _cultivoId != null;
      case 1:
        return _tipoSueloId != null;
      case 2:
        return true;
      case 3:
        return double.tryParse(_areaCtrl.text.trim()) != null;
      default:
        return false;
    }
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.jumpToPage(step);
  }

  Future<void> _submit() async {
    final request = ParcelaRequest(
      cultivoId: _cultivoId!,
      tipoSueloId: _tipoSueloId!,
      etapaFenologicaId: _etapaId,
      fechaSiembra: _fechaSiembra,
      areaMzs: double.parse(_areaCtrl.text.trim()),
      latitud: _latitudCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_latitudCtrl.text.trim()),
      longitud: _longitudCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_longitudCtrl.text.trim()),
      municipio: _municipioCtrl.text.trim().isEmpty
          ? null
          : _municipioCtrl.text.trim(),
      comunidad: _comunidadCtrl.text.trim().isEmpty
          ? null
          : _comunidadCtrl.text.trim(),
    );

    final provider = context.read<ParcelaViewModel>();
    final ok = await provider.crearParcela(request);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else if (provider.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(provider.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParcelaViewModel>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _step == 0
                        ? Navigator.of(context).pop()
                        : _goTo(_step - 1),
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.greenDark,
                  ),
                  const Expanded(
                    child: Text(
                      'CosechaClima',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontFamilyFallback: ['Times New Roman', 'serif'],
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Paso ${_step + 1} de $_totalSteps',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ProgressDots(total: _totalSteps, activeIndex: _step),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _step = i),
                  children: [
                    _CultivoStep(
                      cultivos: provider.cultivos,
                      selectedId: _cultivoId,
                      onSelect: (id) => setState(() => _cultivoId = id),
                    ),
                    _SueloStep(
                      tiposSuelo: provider.tiposSuelo,
                      selectedId: _tipoSueloId,
                      onSelect: (id) => setState(() => _tipoSueloId = id),
                    ),
                    _FechaStep(
                      fecha: _fechaSiembra,
                      etapas: provider.etapas,
                      etapaId: _etapaId,
                      onFechaChanged: (f) => setState(() => _fechaSiembra = f),
                      onEtapaChanged: (id) => setState(() => _etapaId = id),
                    ),
                    _UbicacionStep(
                      areaCtrl: _areaCtrl,
                      municipioCtrl: _municipioCtrl,
                      comunidadCtrl: _comunidadCtrl,
                      latitudCtrl: _latitudCtrl,
                      longitudCtrl: _longitudCtrl,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: !_puedeAvanzar || provider.cargando
                    ? null
                    : (_step == _totalSteps - 1
                          ? _submit
                          : () => _goTo(_step + 1)),
                child: provider.cargando
                    ? const Text('Guardando...')
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _step == _totalSteps - 1
                                ? 'Guardar parcela'
                                : 'Continuar',
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _step == _totalSteps - 1
                                ? Icons.check
                                : Icons.arrow_forward,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconoPara(String nombre) {
  final n = nombre.toLowerCase();
  if (n.contains('arcill')) return Icons.water_drop_outlined;
  if (n.contains('aren')) return Icons.air;
  if (n.contains('franco')) return Icons.grain;
  if (n.contains('maíz') || n.contains('maiz')) return Icons.eco_outlined;
  if (n.contains('frijol') || n.contains('fríjol')) return Icons.eco;
  return Icons.eco_outlined;
}

class _StepHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StepHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: ['Times New Roman', 'serif'],
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.muted, fontSize: 15),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CultivoStep extends StatelessWidget {
  final List<Cultivo> cultivos;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  const _CultivoStep({
    required this.cultivos,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (cultivos.isEmpty) {
      return const AppLoadingMessage(message: 'Cargando cultivos...');
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            title: '¿Qué sembraste?',
            subtitle:
                'Seleccioná el cultivo principal para recibir alertas según sus necesidades hídricas.',
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: cultivos.map((c) {
              return AppChoiceCard(
                icon: _iconoPara(c.nombre),
                title: c.nombre,
                subtitle: c.nombreCientifico ?? '',
                selected: selectedId == c.id,
                onTap: () => onSelect(c.id),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.cardSmall),
              border: Border.all(color: const Color(0x1C6F5239)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.amber, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cada cultivo tiene umbrales diferentes para sequía, lluvia y viento.',
                    style: TextStyle(color: AppColors.ink),
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

class _SueloStep extends StatelessWidget {
  final List<TipoSuelo> tiposSuelo;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  const _SueloStep({
    required this.tiposSuelo,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (tiposSuelo.isEmpty) {
      return const AppLoadingMessage(message: 'Cargando tipos de suelo...');
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            title: '¿Qué tipo de suelo tenés?',
            subtitle:
                'El suelo cambia el riesgo: el arcilloso se encharca, el arenoso se seca rápido.',
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: tiposSuelo.map((s) {
              return AppChoiceCard(
                icon: _iconoPara(s.nombre),
                title: s.nombre,
                subtitle: s.descripcion ?? '',
                selected: selectedId == s.id,
                avatarVariant: AppAvatarVariant.soil,
                onTap: () => onSelect(s.id),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FechaStep extends StatelessWidget {
  final DateTime fecha;
  final List<EtapaFenologica> etapas;
  final int? etapaId;
  final ValueChanged<DateTime> onFechaChanged;
  final ValueChanged<int?> onEtapaChanged;

  const _FechaStep({
    required this.fecha,
    required this.etapas,
    required this.etapaId,
    required this.onFechaChanged,
    required this.onEtapaChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            title: '¿Cuándo sembraste?',
            subtitle:
                'Con esta fecha se puede estimar la etapa fenológica del cultivo.',
          ),
          _FechaRapida(
            titulo: 'Esta semana',
            subtitulo: 'Recién comenzando',
            seleccionado: fecha.difference(ahora).inDays.abs() <= 7,
            onTap: () =>
                onFechaChanged(ahora.subtract(const Duration(days: 3))),
          ),
          const SizedBox(height: 10),
          _FechaRapida(
            titulo: 'Hace 2-3 semanas',
            subtitulo: 'Crecimiento temprano',
            seleccionado: false,
            onTap: () =>
                onFechaChanged(ahora.subtract(const Duration(days: 18))),
          ),
          const SizedBox(height: 10),
          _FechaRapida(
            titulo: 'Hace más de un mes',
            subtitulo: 'Etapa avanzada',
            seleccionado: false,
            onTap: () =>
                onFechaChanged(ahora.subtract(const Duration(days: 45))),
          ),
          const SizedBox(height: 18),
          const Text(
            'O ELEGÍ UNA FECHA EXACTA',
            style: TextStyle(
              color: AppColors.soil,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.input),
            onTap: () async {
              final elegida = await showDatePicker(
                context: context,
                initialDate: fecha,
                firstDate: DateTime(2000),
                lastDate: ahora,
              );
              if (elegida != null) onFechaChanged(elegida);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.green, width: 2),
                borderRadius: BorderRadius.circular(AppRadius.input),
                color: AppColors.paper,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('dd/MM/yyyy').format(fecha)),
                  const Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppColors.green,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (etapas.isNotEmpty) ...[
            const Text(
              'ETAPA FENOLÓGICA (OPCIONAL)',
              style: TextStyle(
                color: AppColors.soil,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: etapaId,
              decoration: const InputDecoration(
                hintText: 'Se puede calcular más adelante',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Sin especificar'),
                ),
                ...etapas.map(
                  (e) => DropdownMenuItem(value: e.id, child: Text(e.nombre)),
                ),
              ],
              onChanged: onEtapaChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _FechaRapida extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final bool seleccionado;
  final VoidCallback onTap;

  const _FechaRapida({
    required this.titulo,
    required this.subtitulo,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? const Color(0xFFEDF8ED) : AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.cardSmall),
            border: Border.all(
              color: seleccionado ? AppColors.green : const Color(0xFFEFE0D3),
              width: seleccionado ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.eco_outlined, color: AppColors.greenDark),
              const SizedBox(width: 14),
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
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UbicacionStep extends StatelessWidget {
  final TextEditingController areaCtrl;
  final TextEditingController municipioCtrl;
  final TextEditingController comunidadCtrl;
  final TextEditingController latitudCtrl;
  final TextEditingController longitudCtrl;
  final VoidCallback onChanged;

  const _UbicacionStep({
    required this.areaCtrl,
    required this.municipioCtrl,
    required this.comunidadCtrl,
    required this.latitudCtrl,
    required this.longitudCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            title: 'Ubicación y área',
            subtitle:
                'Necesitamos dónde está tu parcela para consultar el clima real, día a día.',
          ),
          const Text(
            'ÁREA (MANZANAS)',
            style: TextStyle(
              color: AppColors.soil,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: areaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(hintText: 'Ej: 1.5'),
          ),
          const SizedBox(height: 20),
          LocationPickerField(
            latitudCtrl: latitudCtrl,
            longitudCtrl: longitudCtrl,
            onChanged: onChanged,
          ),
          const SizedBox(height: 20),
          const Text(
            'MUNICIPIO (OPCIONAL)',
            style: TextStyle(
              color: AppColors.soil,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: municipioCtrl,
            decoration: const InputDecoration(hintText: 'Ej: Jinotepe'),
          ),
          const SizedBox(height: 18),
          const Text(
            'COMUNIDAD (OPCIONAL)',
            style: TextStyle(
              color: AppColors.soil,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: comunidadCtrl,
            decoration: const InputDecoration(hintText: 'Ej: El Rosario'),
          ),
        ],
      ),
    );
  }
}
