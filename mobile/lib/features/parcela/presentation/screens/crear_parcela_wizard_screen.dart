import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/cache/guest_parcela_store.dart';
import '../../../../core/cache/ubicacion_preferida_store.dart';
import '../../../../core/config/municipio_centroide.dart';
import '../../../../core/config/zona_cobertura.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_loading_message.dart';
import '../../../../shared/widgets/location_picker_field.dart';
import '../../../catalogo/data/models/catalogo.dart';
import '../../data/models/parcela.dart';
import '../view_models/parcela_view_model.dart';

class CrearParcelaWizardScreen extends StatefulWidget {
  final bool esInvitado;

  const CrearParcelaWizardScreen({super.key, this.esInvitado = false});

  @override
  State<CrearParcelaWizardScreen> createState() =>
      _CrearParcelaWizardScreenState();
}

class _CrearParcelaWizardScreenState extends State<CrearParcelaWizardScreen> {
  final _pageController = PageController();
  final _areaCtrl = TextEditingController(text: '1');
  final _comunidadCtrl = TextEditingController();
  final _latitudCtrl = TextEditingController();
  final _longitudCtrl = TextEditingController();
  final _ubicacionPreferida = UbicacionPreferidaStore();

  int _step = 0;
  static const _totalSteps = 5;

  int? _cultivoId;
  int? _tipoSueloId;
  int? _etapaId;
  DateTime _fechaSiembra = DateTime.now();
  String _fechaExactaTexto = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _municipioSeleccionado = 'Jinotepe';

  bool _municipioElegidoManualmente = false;

  bool _guardando = false;

  static const _municipios = [
    _MunicipioOption(
      nombre: 'Diriamba',
      subtitulo: 'Cuna del Güegüense',
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
    _MunicipioOption(
      nombre: 'El Rosario',
      subtitulo: 'Zona productiva',
      icono: Icons.eco_outlined,
    ),
    _MunicipioOption(
      nombre: 'La Conquista',
      subtitulo: 'Zona alta de Carazo',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'La Paz de Carazo',
      subtitulo: 'Zona productiva',
      icono: Icons.eco_outlined,
    ),
    _MunicipioOption(
      nombre: 'Santa Teresa',
      subtitulo: 'Zona productiva',
      icono: Icons.eco_outlined,
    ),
    _MunicipioOption(
      nombre: 'Boaco',
      subtitulo: 'Departamento',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Chinandega',
      subtitulo: 'Departamento',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Chontales',
      subtitulo: 'Departamento',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Estelí',
      subtitulo: 'Departamento',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Granada',
      subtitulo: 'Departamento',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Jinotega',
      subtitulo: 'Departamento (café)',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'León',
      subtitulo: 'Departamento',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Madriz',
      subtitulo: 'Departamento',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Managua',
      subtitulo: 'Departamento',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Masaya',
      subtitulo: 'Departamento',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Matagalpa',
      subtitulo: 'Departamento (café)',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Nueva Segovia',
      subtitulo: 'Departamento (café)',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Rivas',
      subtitulo: 'Departamento',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Río San Juan',
      subtitulo: 'Departamento',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Región Autónoma de la Costa Caribe Norte',
      subtitulo: 'Región autónoma',
      icono: Icons.terrain_outlined,
    ),
    _MunicipioOption(
      nombre: 'Región Autónoma de la Costa Caribe Sur',
      subtitulo: 'Región autónoma',
      icono: Icons.terrain_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(context.read<ParcelaViewModel>().cargarCatalogos());
    unawaited(_cargarUbicacionPreferida());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _areaCtrl.dispose();
    _comunidadCtrl.dispose();
    _latitudCtrl.dispose();
    _longitudCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarUbicacionPreferida() async {
    final guardado = await _ubicacionPreferida.obtener();
    if (!mounted || guardado == null) return;
    if (_municipios.any((m) => m.nombre == guardado)) {
      setState(() => _municipioSeleccionado = guardado);
    }
  }

  void _seleccionarMunicipio(String municipio) {
    setState(() {
      _municipioSeleccionado = municipio;
      _municipioElegidoManualmente = true;
    });
  }

  void _onCoordenadasCambiaron() {
    final lat = double.tryParse(_latitudCtrl.text.trim());
    final lon = double.tryParse(_longitudCtrl.text.trim());
    setState(() {
      if (_municipioElegidoManualmente || lat == null || lon == null) return;
      final cercano = MunicipioCentroide.masCercano(lat, lon);
      if (cercano != null) _municipioSeleccionado = cercano;
    });
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

    if (widget.esInvitado) {
      final guardada = await _guardarInvitado(provider, request);
      if (!mounted) return;
      setState(() => _guardando = false);
      if (!guardada) return;
      await _ubicacionPreferida.guardar(request.municipio ?? '');
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }

    final ok = await provider.crearParcela(request);
    if (!mounted) return;

    if (!ok) {
      setState(() => _guardando = false);
      if (provider.error != null) _mostrarSnack(provider.error!);
      return;
    }

    setState(() => _guardando = false);
    if (provider.guardadaLocalmente) {
      _mostrarSnack(
        'Guardamos tu parcela en el teléfono. La subimos a tu cuenta '
        'cuando tengas internet.',
      );
    }
    await _ubicacionPreferida.guardar(request.municipio ?? '');
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<bool> _guardarInvitado(
    ParcelaViewModel provider,
    ParcelaRequest request,
  ) async {
    Cultivo? cultivo;
    for (final c in provider.cultivos) {
      if (c.id == request.cultivoId) {
        cultivo = c;
        break;
      }
    }
    TipoSuelo? suelo;
    for (final s in provider.tiposSuelo) {
      if (s.id == request.tipoSueloId) {
        suelo = s;
        break;
      }
    }
    if (cultivo == null || suelo == null) {
      _mostrarSnack(
        'No se pudieron cargar los cultivos. Revisá tu conexión e intentá '
        'de nuevo.',
      );
      return false;
    }

    final latitud =
        request.latitud ?? MunicipioCentroide.latitud(request.municipio);
    final longitud =
        request.longitud ?? MunicipioCentroide.longitud(request.municipio);
    if (latitud == null || longitud == null) {
      _mostrarSnack(
        'Necesitamos tu ubicación GPS o un municipio de la lista para '
        'calcular el clima.',
      );
      return false;
    }

    await GuestParcelaStore().agregar(
      cultivoId: cultivo.id,
      cultivoNombre: cultivo.nombre,
      tipoSueloId: suelo.id,
      tipoSueloNombre: suelo.nombre,
      etapaFenologicaId: request.etapaFenologicaId,
      latitud: latitud,
      longitud: longitud,
      municipio: request.municipio,
      comunidad: request.comunidad,
      fechaSiembra: request.fechaSiembra,
      areaMzs: request.areaMzs,
    );
    return true;
  }

  void _mostrarSnack(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParcelaViewModel>();
    final sinCatalogos =
        provider.cultivos.isEmpty && provider.tiposSuelo.isEmpty;

    if (sinCatalogos && !provider.cargando && provider.error != null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          elevation: 0,
          title: const Text('Nueva parcela'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 40,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 12),
                Text(
                  provider.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => provider.cargarCatalogos(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                    ? 'Confirmar'
                    : 'Paso ${_step + 1} de $_totalSteps',
                onBack: () =>
                    _step == 0 ? Navigator.of(context).pop() : _goTo(_step - 1),
              ),
              const SizedBox(height: 10),
              _ProgressDots(total: _totalSteps, activeIndex: _step),
              if (widget.esInvitado) ...[
                const SizedBox(height: 12),
                const _AvisoInvitado(),
              ],
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
                      comunidadCtrl: _comunidadCtrl,
                      latitudCtrl: _latitudCtrl,
                      longitudCtrl: _longitudCtrl,
                      onMunicipioChanged: _seleccionarMunicipio,
                      onChanged: _onCoordenadasCambiaron,
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
                    _ConfirmStep(
                      areaCtrl: _areaCtrl,
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
                    : _step >= 2
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

class _AvisoInvitado extends StatelessWidget {
  const _AvisoInvitado();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 16, color: AppColors.greenDark),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Estás sin cuenta: esta parcela queda guardada en este teléfono. '
              'Iniciá sesión para no perderla.',
              style: TextStyle(fontSize: 11.5, color: AppColors.greenDark),
            ),
          ),
        ],
      ),
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
          children: cultivos.asMap().entries.map((entry) {
            final indice = entry.key;
            final cultivo = entry.value;
            return _ChoiceTile(
              icon: _iconoPara(cultivo.nombre),
              title: cultivo.nombre,
              subtitle: cultivo.nombreCientifico ?? cultivo.nombre,
              selected: selectedId == cultivo.id,
              avatarVariant: indice.isEven
                  ? AppAvatarVariant.mint
                  : AppAvatarVariant.soil,
              onTap: () => onSelect(cultivo.id),
            );
          }).toList(),
        ),
        const _InfoCard(
          variant: _InfoCardVariant.flat,
          icon: Icons.warning_amber_outlined,
          text:
              'Cada cultivo tiene umbrales propios de sequía, lluvia y viento; '
              'elegí el que sembraste para que las alertas sean precisas.',
        ),
      ],
    );
  }

  static IconData _iconoPara(String nombreCultivo) {
    final nombre = _normalizar(nombreCultivo);
    if (nombre.contains('cafe')) return Icons.coffee_outlined;
    if (nombre.contains('arroz')) return Icons.water_drop_outlined;
    if (nombre.contains('frijol')) return Icons.spa_outlined;
    if (nombre.contains('maiz')) return Icons.eco_outlined;
    if (nombre.contains('sorgo')) return Icons.grass_outlined;
    return Icons.eco_outlined;
  }
}

class _LocationStep extends StatefulWidget {
  final String municipio;
  final TextEditingController comunidadCtrl;
  final TextEditingController latitudCtrl;
  final TextEditingController longitudCtrl;
  final ValueChanged<String> onMunicipioChanged;
  final VoidCallback onChanged;

  const _LocationStep({
    required this.municipio,
    required this.comunidadCtrl,
    required this.latitudCtrl,
    required this.longitudCtrl,
    required this.onMunicipioChanged,
    required this.onChanged,
  });

  @override
  State<_LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<_LocationStep> {
  final _busquedaCtrl = TextEditingController();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  List<_MunicipioOption> get _filtrados {
    final consulta = _normalizar(_busquedaCtrl.text.trim());
    if (consulta.isEmpty) {
      return _CrearParcelaWizardScreenState._municipios;
    }
    return _CrearParcelaWizardScreenState._municipios
        .where(
          (m) =>
              _normalizar(m.nombre).contains(consulta) ||
              _normalizar(m.subtitulo).contains(consulta),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final lat = double.tryParse(widget.latitudCtrl.text.trim());
    final lon = double.tryParse(widget.longitudCtrl.text.trim());
    final tieneCoordenadas = lat != null && lon != null;
    final fueraDeNicaragua =
        tieneCoordenadas && !ZonaCobertura.estaDentroDeNicaragua(lat, lon);
    final consulta = _busquedaCtrl.text.trim();
    final filtrados = _filtrados;

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
          latitudCtrl: widget.latitudCtrl,
          longitudCtrl: widget.longitudCtrl,
          onChanged: widget.onChanged,
        ),
        if (fueraDeNicaragua)
          const _InfoCard(
            variant: _InfoCardVariant.warning,
            icon: Icons.warning_amber_outlined,
            title: 'Fuera de la zona calibrada',
            text:
                'Estas coordenadas parecen estar fuera de Nicaragua. Por ahora la '
                'app solo tiene pronóstico y reglas agronómicas para el territorio '
                'nacional, así que las alertas acá podrían no ser precisas.',
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Municipio o departamento (respaldo sin GPS)',
                    style: _eyebrowStyle,
                  ),
                ),
                if (widget.municipio.isNotEmpty) ...[
                  const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      widget.municipio,
                      overflow: TextOverflow.ellipsis,
                      style: _eyebrowStyle.copyWith(color: AppColors.green),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _busquedaCtrl,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Buscá tu municipio o departamento',
                suffixIcon: _busquedaCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(_busquedaCtrl.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (filtrados.isEmpty)
              _SinResultadosUbicacion(consulta: consulta)
            else if (consulta.isNotEmpty)
              ...filtrados.map(_crearFila)
            else ...[
              const _GrupoUbicacion(titulo: 'CARAZO'),
              ...filtrados.where((m) => m.esCarazo).map(_crearFila),
              const _GrupoUbicacion(titulo: 'RESTO DEL PAÍS'),
              ...filtrados.where((m) => !m.esCarazo).map(_crearFila),
            ],
          ],
        ),
        _TextFieldBlock(
          label: 'COMUNIDAD (OPCIONAL)',
          controller: widget.comunidadCtrl,
          hintText: 'Ej: El Rosario',
        ),
      ],
    );
  }

  Widget _crearFila(_MunicipioOption municipio) {
    final seleccionado = widget.municipio == municipio.nombre;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: seleccionado ? const Color(0xFFEDF8ED) : AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            FocusScope.of(context).unfocus();
            widget.onMunicipioChanged(municipio.nombre);
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: seleccionado ? AppColors.green : const Color(0xFFEFE0D3),
                width: seleccionado ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  municipio.icono,
                  size: 20,
                  color: seleccionado ? AppColors.greenDark : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        municipio.nombre,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        municipio.subtitulo,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  seleccionado
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: seleccionado ? AppColors.green : AppColors.soft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GrupoUbicacion extends StatelessWidget {
  final String titulo;

  const _GrupoUbicacion({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(titulo, style: _eyebrowStyle),
    );
  }
}

class _SinResultadosUbicacion extends StatelessWidget {
  final String consulta;

  const _SinResultadosUbicacion({required this.consulta});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFE0D3)),
      ),
      child: Text(
        'No encontramos "$consulta". Probá con otro nombre o usá el GPS.',
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
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
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  final TextEditingController areaCtrl;
  final VoidCallback onAreaChanged;

  const _ConfirmStep({required this.areaCtrl, required this.onAreaChanged});

  @override
  Widget build(BuildContext context) {
    return _PrototypeStack(
      topMargin: 22,
      children: [
        const _StepHeader(
          eyebrow: 'ÚLTIMO PASO',
          title: 'Casi listo',
          subtitle:
              'Solo falta el tamaño de tu parcela. Las alertas van a usar los '
              'valores recomendados y los podés ajustar cuando quieras.',
        ),
        _TextFieldBlock(
          label: 'AREA (MANZANAS)',
          controller: areaCtrl,
          hintText: 'Ej: 1.5',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => onAreaChanged(),
        ),
        const _InfoCard(
          variant: _InfoCardVariant.flat,
          icon: Icons.check_circle_outline,
          title: 'Valores recomendados',
          text:
              'Lluvia intensa 100 mm · viento fuerte 40 km/h · canícula 7 días. '
              'Podés cambiarlos después en "Ajustar mis alertas", dentro de tu '
              'parcela.',
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

  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.avatarVariant = AppAvatarVariant.mint,
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
          constraints: const BoxConstraints(minHeight: 138),
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
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: ['Times New Roman', 'serif'],
                  fontSize: 22,
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

  static const _municipiosCarazo = {
    'Diriamba',
    'Jinotepe',
    'San Marcos',
    'Dolores',
    'El Rosario',
    'La Conquista',
    'La Paz de Carazo',
    'Santa Teresa',
  };

  bool get esCarazo => _municipiosCarazo.contains(nombre);
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
