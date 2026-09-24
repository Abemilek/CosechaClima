import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/zona_cobertura.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_loading_message.dart';
import '../../../../shared/widgets/location_picker_field.dart';
import '../../../../shared/widgets/umbral_form.dart';
import '../../../catalogo/data/models/catalogo.dart';
import '../../../umbral/data/models/umbral.dart';
import '../../../umbral/data/services/umbral_service.dart';
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
  final _areaCtrl = TextEditingController(text: '1');
  final _municipioCtrl = TextEditingController(text: 'Jinotepe');
  final _comunidadCtrl = TextEditingController();
  final _latitudCtrl = TextEditingController();
  final _longitudCtrl = TextEditingController();

  int _step = 0;
  static const _totalSteps = 5;

  int? _cultivoId;
  int? _tipoSueloId;
  int? _etapaId;
  DateTime _fechaSiembra = DateTime.now();
  String _fechaExactaTexto = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _municipioSeleccionado = 'Jinotepe';

  double _lluviaIntensaMm = 100;
  double _vientoFuerteKmh = 40;
  double _caniculaDias = 7;
  String _variedadCultivo = 'Criollo';
  bool _tieneRiego = false;
  TimeOfDay _horarioSms = const TimeOfDay(hour: 6, minute: 0);
  bool _guardando = false;

  static const _municipios = [
    _MunicipioOption(
      nombre: 'Diriamba',
      subtitulo: 'Cuna del Gueguense',
      icono: Icons.home_outlined,
    ),
    _MunicipioOption(
      nombre: 'Jinotepe',
      subtitulo: 'Cabecera Departamental',
      icono: Icons.location_on_outlined,
    ),
    _MunicipioOption(
      nombre: 'San Marcos',
      subtitulo: 'Corazón de la Meseta',
      icono: Icons.eco_outlined,
    ),
    _MunicipioOption(
      nombre: 'Dolores',
      subtitulo: 'Zona productiva',
      icono: Icons.settings_outlined,
    ),
  ];

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
        return _municipioSeleccionado.trim().isNotEmpty;
      case 2:
        return true;
      case 3:
        return _tipoSueloId != null;
      case 4:
        return double.tryParse(_areaCtrl.text.trim()) != null;
      default:
        return false;
    }
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.jumpToPage(step);
  }

  void _seleccionarFecha(DateTime fecha, {int? etapaId}) {
    setState(() {
      _fechaSiembra = fecha;
      _fechaExactaTexto = DateFormat('yyyy-MM-dd').format(fecha);
      _etapaId = etapaId ?? _etapaId;
    });
  }

  Future<void> _submit() async {
    setState(() => _guardando = true);

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
      municipio: _municipioSeleccionado,
      comunidad: _comunidadCtrl.text.trim().isEmpty
          ? null
          : _comunidadCtrl.text.trim(),
    );

    final provider = context.read<ParcelaViewModel>();
    final ok = await provider.crearParcela(request);
    if (!mounted) return;

    if (!ok) {
      setState(() => _guardando = false);
      if (provider.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(provider.error!)));
      }
      return;
    }

    try {
      final horario =
          '${_horarioSms.hour.toString().padLeft(2, '0')}:'
          '${_horarioSms.minute.toString().padLeft(2, '0')}';
      await UmbralService(ApiClient()).guardar(
        UmbralRequest(
          lluviaIntensaMm: _lluviaIntensaMm.round(),
          vientoFuerteKmh: _vientoFuerteKmh.round(),
          caniculaDias: _caniculaDias.round(),
          variedadCultivo: _variedadCultivo,
          tieneRiego: _tieneRiego,
          horarioSms: horario,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on NetworkException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on TimeoutApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParcelaViewModel>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: _PrototypeScreen(
          child: Column(
            children: [
              _PrototypeTopBar(
                step: _step,
                totalSteps: _totalSteps,
                title: _step <= 1
                    ? 'CosechaClima'
                    : _step == 4
                    ? 'Umbrales'
                    : 'Paso ${_step + 1} de $_totalSteps',
                onBack: () =>
                    _step == 0 ? Navigator.of(context).pop() : _goTo(_step - 1),
              ),
              const SizedBox(height: 10),
              _ProgressDots(total: _totalSteps, activeIndex: _step),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _step = i),
                  children: [
                    _CropStep(
                      cultivos: provider.cultivos,
                      selectedId: _cultivoId,
                      onSelect: (id) => setState(() => _cultivoId = id),
                    ),
                    _LocationStep(
                      municipio: _municipioSeleccionado,
                      municipioCtrl: _municipioCtrl,
                      comunidadCtrl: _comunidadCtrl,
                      latitudCtrl: _latitudCtrl,
                      longitudCtrl: _longitudCtrl,
                      onMunicipioChanged: (value) {
                        setState(() {
                          _municipioSeleccionado = value;
                          _municipioCtrl.text = value;
                        });
                      },
                      onChanged: () => setState(() {}),
                    ),
                    _DateStep(
                      fecha: _fechaSiembra,
                      fechaExactaTexto: _fechaExactaTexto,
                      etapas: provider.etapas,
                      etapaId: _etapaId,
                      onFechaChanged: _seleccionarFecha,
                      onFechaExactaChanged: (value) {
                        final parsed = DateTime.tryParse(value.trim());
                        setState(() {
                          _fechaExactaTexto = value;
                          if (parsed != null) _fechaSiembra = parsed;
                        });
                      },
                    ),
                    _SoilStep(
                      tiposSuelo: provider.tiposSuelo,
                      selectedId: _tipoSueloId,
                      onSelect: (id) => setState(() => _tipoSueloId = id),
                    ),
                    _ThresholdsStep(
                      lluviaIntensaMm: _lluviaIntensaMm,
                      vientoFuerteKmh: _vientoFuerteKmh,
                      caniculaDias: _caniculaDias,
                      variedadCultivo: _variedadCultivo,
                      tieneRiego: _tieneRiego,
                      horarioSms: _horarioSms,
                      variedades: _variedades,
                      horarios: _horarios,
                      areaCtrl: _areaCtrl,
                      onLluviaChanged: (v) =>
                          setState(() => _lluviaIntensaMm = v),
                      onVientoChanged: (v) =>
                          setState(() => _vientoFuerteKmh = v),
                      onCaniculaChanged: (v) =>
                          setState(() => _caniculaDias = v),
                      onVariedadChanged: (v) => setState(
                        () => _variedadCultivo = v ?? _variedadCultivo,
                      ),
                      onRiegoChanged: (v) => setState(() => _tieneRiego = v),
                      onHorarioChanged: (v) =>
                          setState(() => _horarioSms = v ?? _horarioSms),
                      onAreaChanged: () => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _PrototypeButton(
                text: _step == _totalSteps - 1
                    ? (_guardando || provider.cargando
                          ? 'Guardando...'
                          : '¡Ver mi semáforo!')
                    : _step == 1
                    ? 'Confirmar ubicación'
                    : _step == 3
                    ? 'Configurar alertas'
                    : _step == 2
                    ? 'Siguiente paso'
                    : 'Continuar',
                icon: _step == _totalSteps - 1
                    ? Icons.list_alt_outlined
                    : Icons.arrow_forward,
                onPressed: !_puedeAvanzar || _guardando || provider.cargando
                    ? null
                    : (_step == _totalSteps - 1
                          ? _submit
                          : () => _goTo(_step + 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrototypeScreen extends StatelessWidget {
  final Widget child;

  const _PrototypeScreen({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: child,
    );
  }
}

class _PrototypeTopBar extends StatelessWidget {
  final int step;
  final int totalSteps;
  final String title;
  final VoidCallback onBack;

  const _PrototypeTopBar({
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              _IconButtonBox(icon: Icons.arrow_back, onPressed: onBack),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
        ),
        if (step <= 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                step == 0 ? 'Registro de cultivo' : 'Registro',
                style: _eyebrowStyle,
              ),
              Text(
                '${step + 1} de $totalSteps',
                style: _eyebrowStyle.copyWith(color: AppColors.green),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int total;
  final int activeIndex;

  const _ProgressDots({required this.total, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final active = index == activeIndex;
        return Container(
          width: active ? 32 : 10,
          height: 8,
          margin: EdgeInsets.only(right: index == total - 1 ? 0 : 8),
          decoration: BoxDecoration(
            color: active ? AppColors.green : const Color(0xFFDED7CF),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}

class _PrototypeStack extends StatelessWidget {
  final List<Widget> children;
  final double topMargin;

  const _PrototypeStack({required this.children, this.topMargin = 24});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(top: topMargin, bottom: 18),
      children: _spaced(children, 18),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? eyebrow;

  const _StepHeader({
    required this.title,
    required this.subtitle,
    this.eyebrow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(eyebrow!, style: _eyebrowStyle),
          const SizedBox(height: 8),
        ],
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: ['Times New Roman', 'serif'],
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.05,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.muted, fontSize: 15),
        ),
      ],
    );
  }
}

class _CropStep extends StatelessWidget {
  final List<Cultivo> cultivos;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  const _CropStep({
    required this.cultivos,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (cultivos.isEmpty) {
      return const AppLoadingMessage(message: 'Cargando cultivos...');
    }
    return _PrototypeStack(
      topMargin: 24,
      children: [
        const _StepHeader(
          title: '¿Qué sembraste?',
          subtitle:
              'Seleccioná el cultivo principal para recibir alertas según sus necesidades hídricas.',
        ),
        _ChoiceGrid(
          children: cultivos.take(2).map((cultivo) {
            final esFrijol = _normalizar(cultivo.nombre).contains('frijol');
            return _ChoiceTile(
              icon: Icons.eco_outlined,
              title: cultivo.nombre,
              subtitle: esFrijol
                  ? 'Phaseolus'
                  : cultivo.nombreCientifico ?? 'Zea mays',
              selected: selectedId == cultivo.id,
              avatarVariant: esFrijol
                  ? AppAvatarVariant.soil
                  : AppAvatarVariant.mint,
              onTap: () => onSelect(cultivo.id),
            );
          }).toList(),
        ),
        const _InfoCard(
          variant: _InfoCardVariant.flat,
          icon: Icons.warning_amber_outlined,
          text:
              'El maíz y el frijol tienen umbrales diferentes para sequía, lluvia y viento.',
        ),
      ],
    );
  }
}

class _LocationStep extends StatelessWidget {
  final String municipio;
  final TextEditingController municipioCtrl;
  final TextEditingController comunidadCtrl;
  final TextEditingController latitudCtrl;
  final TextEditingController longitudCtrl;
  final ValueChanged<String> onMunicipioChanged;
  final VoidCallback onChanged;

  const _LocationStep({
    required this.municipio,
    required this.municipioCtrl,
    required this.comunidadCtrl,
    required this.latitudCtrl,
    required this.longitudCtrl,
    required this.onMunicipioChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final lat = double.tryParse(latitudCtrl.text.trim());
    final lon = double.tryParse(longitudCtrl.text.trim());
    final tieneCoordenadas = lat != null && lon != null;
    final fueraDeCarazo =
        tieneCoordenadas && !ZonaCobertura.estaDentroDeCarazo(lat, lon);

    return _PrototypeStack(
      topMargin: 24,
      children: [
        const _StepHeader(
          title: 'Ubicación de parcela',
          subtitle:
              'El GPS da el clima exacto de tu parcela. El municipio es solo un '
              'respaldo aproximado para cuando no podés activar el GPS.',
        ),
        LocationPickerField(
          latitudCtrl: latitudCtrl,
          longitudCtrl: longitudCtrl,
          onChanged: onChanged,
        ),
        if (fueraDeCarazo)
          const _InfoCard(
            variant: _InfoCardVariant.warning,
            icon: Icons.warning_amber_outlined,
            title: 'Fuera de la zona calibrada',
            text:
                'Estas coordenadas parecen estar fuera de Carazo. La app solo tiene '
                'reglas agronómicas validadas para ese departamento, así que las '
                'alertas acá podrían no ser precisas.',
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Municipio (respaldo sin GPS)',
                  style: _eyebrowStyle,
                ),
                Text(
                  'Carazo',
                  style: _eyebrowStyle.copyWith(color: AppColors.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ChoiceGrid(
              children: _CrearParcelaWizardScreenState._municipios.map((m) {
                return _ChoiceTile(
                  icon: m.icono,
                  title: m.nombre,
                  subtitle: m.subtitulo,
                  selected: municipio == m.nombre,
                  compactTitle: true,
                  minHeight: 116,
                  onTap: () => onMunicipioChanged(m.nombre),
                );
              }).toList(),
            ),
          ],
        ),
        _TextFieldBlock(
          label: 'COMUNIDAD (OPCIONAL)',
          controller: comunidadCtrl,
          hintText: 'Ej: El Rosario',
        ),
      ],
    );
  }
}

class _DateStep extends StatelessWidget {
  final DateTime fecha;
  final String fechaExactaTexto;
  final List<EtapaFenologica> etapas;
  final int? etapaId;
  final void Function(DateTime fecha, {int? etapaId}) onFechaChanged;
  final ValueChanged<String> onFechaExactaChanged;

  const _DateStep({
    required this.fecha,
    required this.fechaExactaTexto,
    required this.etapas,
    required this.etapaId,
    required this.onFechaChanged,
    required this.onFechaExactaChanged,
  });

  int? _etapaPorNombre(String nombre) {
    final normalizedName = _normalizar(nombre);
    final match = etapas.where(
      (e) => _normalizar(e.nombre).contains(normalizedName),
    );
    return match.isEmpty ? null : match.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    return _PrototypeStack(
      topMargin: 30,
      children: [
        const _StepHeader(
          title: '¿Cuándo sembraste?',
          subtitle:
              'Con esta fecha calculamos automáticamente la etapa: germinación, crecimiento, floración o llenado de grano.',
        ),
        _ChoiceRowTile(
          title: 'Esta semana',
          subtitle: 'Recién comenzando',
          pill: 'Germinación',
          selected: fecha.difference(ahora).inDays.abs() <= 7,
          onTap: () => onFechaChanged(
            ahora.subtract(const Duration(days: 3)),
            etapaId: _etapaPorNombre('germinacion'),
          ),
        ),
        _ChoiceRowTile(
          title: 'Hace 2-3 semanas',
          subtitle: 'Crecimiento temprano',
          pill: 'Crecimiento',
          selected:
              fecha
                  .difference(ahora.subtract(const Duration(days: 18)))
                  .inDays
                  .abs() <=
              4,
          onTap: () => onFechaChanged(
            ahora.subtract(const Duration(days: 18)),
            etapaId:
                _etapaPorNombre('plantula') ?? _etapaPorNombre('desarrollo'),
          ),
        ),
        _ChoiceRowTile(
          title: 'Hace más de un mes',
          subtitle: 'Etapa de maduración',
          pill: 'Floración',
          warn: true,
          selected:
              fecha
                  .difference(ahora.subtract(const Duration(days: 45)))
                  .inDays
                  .abs() <=
              8,
          onTap: () => onFechaChanged(
            ahora.subtract(const Duration(days: 45)),
            etapaId: _etapaPorNombre('floracion'),
          ),
        ),
        _TextFieldBlock(
          label: 'O selecciona una fecha exacta',
          controller: TextEditingController(text: fechaExactaTexto),
          hintText: '2026-06-10',
          keyboardType: TextInputType.datetime,
          onChanged: onFechaExactaChanged,
        ),
      ],
    );
  }
}

class _SoilStep extends StatelessWidget {
  final List<TipoSuelo> tiposSuelo;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  const _SoilStep({
    required this.tiposSuelo,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (tiposSuelo.isEmpty) {
      return const AppLoadingMessage(message: 'Cargando tipos de suelo...');
    }
    return _PrototypeStack(
      topMargin: 26,
      children: [
        const _StepHeader(
          title: '¿Qué tipo de suelo tenés?',
          subtitle:
              'El suelo cambia el riesgo: el arcilloso se encharca, el arenoso se seca rápido y el franco responde mejor.',
        ),
        _ChoiceGrid(
          children: [
            ...tiposSuelo.map((suelo) {
              final n = _normalizar(suelo.nombre);
              return _ChoiceTile(
                icon: n.contains('aren')
                    ? Icons.air
                    : Icons.water_drop_outlined,
                title: suelo.nombre,
                subtitle: _soilSubtitle(suelo.nombre),
                selected: selectedId == suelo.id,
                avatarVariant: AppAvatarVariant.soil,
                onTap: () => onSelect(suelo.id),
              );
            }),
            _ChoiceTile(
              icon: Icons.chat_bubble_outline,
              title: 'No sé',
              subtitle: 'Usar ayuda técnica',
              selected: false,
              onTap: () {
                if (tiposSuelo.isNotEmpty) onSelect(tiposSuelo.first.id);
              },
            ),
          ],
        ),
        const _InfoCard(
          variant: _InfoCardVariant.warning,
          title: 'Recomendación del informe V5.1',
          text:
              'El tipo de suelo es parte del motor de reglas: evento climático, cultivo, etapa y suelo.',
        ),
      ],
    );
  }
}

class _ThresholdsStep extends StatelessWidget {
  final double lluviaIntensaMm;
  final double vientoFuerteKmh;
  final double caniculaDias;
  final String variedadCultivo;
  final bool tieneRiego;
  final TimeOfDay horarioSms;
  final List<String> variedades;
  final List<TimeOfDay> horarios;
  final TextEditingController areaCtrl;
  final ValueChanged<double> onLluviaChanged;
  final ValueChanged<double> onVientoChanged;
  final ValueChanged<double> onCaniculaChanged;
  final ValueChanged<String?> onVariedadChanged;
  final ValueChanged<bool> onRiegoChanged;
  final ValueChanged<TimeOfDay?> onHorarioChanged;
  final VoidCallback onAreaChanged;

  const _ThresholdsStep({
    required this.lluviaIntensaMm,
    required this.vientoFuerteKmh,
    required this.caniculaDias,
    required this.variedadCultivo,
    required this.tieneRiego,
    required this.horarioSms,
    required this.variedades,
    required this.horarios,
    required this.areaCtrl,
    required this.onLluviaChanged,
    required this.onVientoChanged,
    required this.onCaniculaChanged,
    required this.onVariedadChanged,
    required this.onRiegoChanged,
    required this.onHorarioChanged,
    required this.onAreaChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _PrototypeStack(
      topMargin: 22,
      children: [
        const _StepHeader(
          eyebrow: 'CONFIGURACION PERSONAL',
          title: 'Ajustá tus alertas',
          subtitle:
              'Podés dejar los valores recomendados o adaptarlos a tu experiencia en la parcela.',
        ),
        UmbralForm(
          lluviaIntensaMm: lluviaIntensaMm,
          vientoFuerteKmh: vientoFuerteKmh,
          caniculaDias: caniculaDias,
          onLluviaChanged: onLluviaChanged,
          onVientoChanged: onVientoChanged,
          onCaniculaChanged: onCaniculaChanged,
        ),
        _TextFieldBlock(
          label: 'AREA (MANZANAS)',
          controller: areaCtrl,
          hintText: 'Ej: 1.5',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => onAreaChanged(),
        ),
        _SelectBlock<String>(
          label: 'Variedad del cultivo',
          value: variedadCultivo,
          items: variedades,
          itemLabel: (v) => v == 'Criollo' ? 'Criollo tradicional' : v,
          onChanged: onVariedadChanged,
        ),
        _ToggleCard(
          title: 'Disponibilidad de riego',
          subtitle: 'Modifica las acciones ante sequía.',
          value: tieneRiego,
          onChanged: onRiegoChanged,
        ),
        _SelectBlock<TimeOfDay>(
          label: 'Horario de alertas SMS',
          value: horarioSms,
          items: horarios,
          itemLabel: (h) => h.format(context),
          onChanged: onHorarioChanged,
        ),
      ],
    );
  }
}

class _ChoiceGrid extends StatelessWidget {
  final List<Widget> children;

  const _ChoiceGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.96,
      children: children,
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final AppAvatarVariant avatarVariant;
  final bool compactTitle;
  final double minHeight;

  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.avatarVariant = AppAvatarVariant.mint,
    this.compactTitle = false,
    this.minHeight = 138,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEDF8ED) : AppColors.paper,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.green : const Color(0xFFEFE0D3),
              width: selected ? 2 : 1,
            ),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppAvatar(icon: icon, variant: avatarVariant),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: const ['Times New Roman', 'serif'],
                  fontSize: compactTitle ? 17 : 22,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceRowTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String pill;
  final bool selected;
  final bool warn;
  final VoidCallback onTap;

  const _ChoiceRowTile({
    required this.title,
    required this.subtitle,
    required this.pill,
    required this.selected,
    required this.onTap,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEDF8ED) : AppColors.paper,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.green : const Color(0xFFEFE0D3),
              width: selected ? 2 : 1,
            ),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              const AppAvatar(icon: Icons.eco_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontFamilyFallback: ['Times New Roman', 'serif'],
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _Pill(text: pill, warn: warn),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final _InfoCardVariant variant;
  final IconData? icon;
  final String? title;
  final String text;

  const _InfoCard({
    required this.variant,
    required this.text,
    this.icon,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (variant) {
      _InfoCardVariant.warning => AppColors.amberBg,
      _InfoCardVariant.mint => AppColors.mint,
      _InfoCardVariant.flat => AppColors.paper,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: variant == _InfoCardVariant.flat ? null : AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            _PillIcon(icon: icon!),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(text, style: const TextStyle(color: AppColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillIcon extends StatelessWidget {
  final IconData icon;

  const _PillIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.amberBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Icon(icon, color: const Color(0xFFA56800), size: 16),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool warn;

  const _Pill({required this.text, this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: warn
            ? AppColors.amberBg
            : AppColors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: warn ? const Color(0xFFA56800) : AppColors.greenDark,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TextFieldBlock extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _TextFieldBlock({
    required this.label,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(hintText: hintText),
        ),
      ],
    );
  }
}

class _SelectBlock<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  const _SelectBlock({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 66),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8D8C8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrototypeButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;

  const _PrototypeButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(text),
      ),
    );
  }
}

class _IconButtonBox extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _IconButtonBox({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: AppColors.greenDark,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

enum _InfoCardVariant { flat, mint, warning }

class _MunicipioOption {
  final String nombre;
  final String subtitulo;
  final IconData icono;

  const _MunicipioOption({
    required this.nombre,
    required this.subtitulo,
    required this.icono,
  });
}

List<Widget> _spaced(List<Widget> children, double gap) {
  final spaced = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    spaced.add(children[i]);
    if (i < children.length - 1) spaced.add(SizedBox(height: gap));
  }
  return spaced;
}

String _normalizar(String value) {
  return value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}

String _soilSubtitle(String nombre) {
  final normalized = _normalizar(nombre);
  if (normalized.contains('franco')) return 'Equilibrado';
  if (normalized.contains('arcill')) return 'Retiene agua';
  if (normalized.contains('aren')) return 'Drena rápido';
  return 'Usar ayuda técnica';
}

const _eyebrowStyle = TextStyle(
  color: AppColors.soil,
  fontSize: 12,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);

const _labelStyle = TextStyle(
  color: AppColors.soil,
  fontSize: 12,
  fontWeight: FontWeight.w900,
  letterSpacing: 0,
);
