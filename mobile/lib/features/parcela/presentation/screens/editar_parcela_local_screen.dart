import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/municipio_centroide.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_loading_message.dart';
import '../../../../shared/widgets/location_picker_field.dart';
import '../../../catalogo/presentation/view_models/catalogo_view_model.dart';
import '../../data/models/parcela_local.dart';
import '../../data/services/parcela_local_store.dart';

class EditarParcelaLocalScreen extends StatefulWidget {
  final ParcelaLocal parcela;

  const EditarParcelaLocalScreen({super.key, required this.parcela});

  @override
  State<EditarParcelaLocalScreen> createState() =>
      _EditarParcelaLocalScreenState();
}

class _EditarParcelaLocalScreenState extends State<EditarParcelaLocalScreen> {
  late final TextEditingController _areaCtrl;
  late final TextEditingController _municipioCtrl;
  late final TextEditingController _comunidadCtrl;
  late final TextEditingController _latitudCtrl;
  late final TextEditingController _longitudCtrl;
  late final TextEditingController _fechaCtrl;

  late int _cultivoId;
  late int _tipoSueloId;
  int? _etapaId;
  late DateTime _fechaSiembra;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.parcela;
    _areaCtrl = TextEditingController(text: _numero(p.areaMzs));
    _municipioCtrl = TextEditingController(text: p.municipio ?? '');
    _comunidadCtrl = TextEditingController(text: p.comunidad ?? '');
    _latitudCtrl = TextEditingController(text: p.latitud.toStringAsFixed(6));
    _longitudCtrl = TextEditingController(text: p.longitud.toStringAsFixed(6));
    _fechaCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(p.fechaSiembra),
    );
    _cultivoId = p.cultivoId;
    _tipoSueloId = p.tipoSueloId;
    _etapaId = p.etapaFenologicaId;
    _fechaSiembra = p.fechaSiembra;
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _municipioCtrl.dispose();
    _comunidadCtrl.dispose();
    _latitudCtrl.dispose();
    _longitudCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  String _numero(double valor) {
    if (valor == valor.roundToDouble()) return valor.round().toString();
    return valor.toString();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaSiembra,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Fecha de siembra',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
    );
    if (elegida == null) return;
    setState(() {
      _fechaSiembra = elegida;
      _fechaCtrl.text = DateFormat('yyyy-MM-dd').format(elegida);
    });
  }

  Future<void> _guardar() async {
    final provider = context.read<CatalogoViewModel>();
    final cultivo = provider.cultivoPorId(_cultivoId);
    final suelo = provider.sueloPorId(_tipoSueloId);
    final area = double.tryParse(_areaCtrl.text.trim());
    final fecha = DateTime.tryParse(_fechaCtrl.text.trim());

    if (cultivo == null || suelo == null) {
      _mostrarError('Elegí un cultivo y un tipo de suelo válidos.');
      return;
    }
    if (area == null || area <= 0) {
      _mostrarError('El área debe ser un número mayor que cero.');
      return;
    }
    if (fecha == null) {
      _mostrarError('La fecha de siembra debe tener el formato AAAA-MM-DD.');
      return;
    }
    final hoy = DateTime.now();
    final fechaSinHora = DateTime(fecha.year, fecha.month, fecha.day);
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    if (fechaSinHora.isAfter(hoySinHora)) {
      _mostrarError('La fecha de siembra no puede estar en el futuro.');
      return;
    }

    final municipio = _municipioCtrl.text.trim();
    var latitud = double.tryParse(_latitudCtrl.text.trim());
    var longitud = double.tryParse(_longitudCtrl.text.trim());
    if (latitud == null || longitud == null) {
      latitud = MunicipioCentroide.latitud(municipio);
      longitud = MunicipioCentroide.longitud(municipio);
    }
    if (latitud == null || longitud == null) {
      _mostrarError(
        'Necesitamos coordenadas GPS o un municipio conocido de Nicaragua.',
      );
      return;
    }

    setState(() => _guardando = true);
    final actualizada = ParcelaLocal(
      id: widget.parcela.id,
      cultivoId: cultivo.id,
      cultivoNombre: cultivo.nombre,
      tipoSueloId: suelo.id,
      tipoSueloNombre: suelo.nombre,
      etapaFenologicaId: _etapaId,
      latitud: latitud,
      longitud: longitud,
      municipio: municipio.isEmpty ? null : municipio,
      comunidad: _comunidadCtrl.text.trim().isEmpty
          ? null
          : _comunidadCtrl.text.trim(),
      fechaSiembra: fecha,
      areaMzs: area,
      creadaEn: widget.parcela.creadaEn,
      actualizadaEn: DateTime.now(),
    );

    try {
      await ParcelaLocalStore().actualizar(actualizada);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Parcela actualizada')));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _mostrarError('No se pudo guardar la parcela en este teléfono.');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CatalogoViewModel>();
    final appBar = AppBar(title: const Text('Editar parcela'));

    if (!provider.cargado) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: appBar,
        body: provider.error == null
            ? const AppLoadingMessage(message: 'Cargando catálogos...')
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        provider.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => provider.cargarCatalogos(forzar: true),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
      );
    }

    final cultivoId =
        provider.cultivoPorId(_cultivoId)?.id ?? provider.cultivos.first.id;
    final sueloId =
        provider.sueloPorId(_tipoSueloId)?.id ?? provider.tiposSuelo.first.id;
    final etapaId = provider.etapaPorId(_etapaId)?.id;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: appBar,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _Etiqueta('CULTIVO'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: cultivoId,
              items: provider.cultivos
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _cultivoId = v ?? _cultivoId),
            ),
            const SizedBox(height: 18),
            const _Etiqueta('TIPO DE SUELO'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: sueloId,
              items: provider.tiposSuelo
                  .map(
                    (s) => DropdownMenuItem(value: s.id, child: Text(s.nombre)),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _tipoSueloId = v ?? _tipoSueloId),
            ),
            const SizedBox(height: 18),
            const _Etiqueta('ETAPA FENOLÓGICA'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: etapaId,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Calcular automáticamente por fecha'),
                ),
                ...provider.etapas.map(
                  (e) => DropdownMenuItem(value: e.id, child: Text(e.nombre)),
                ),
              ],
              onChanged: (v) => setState(() => _etapaId = v),
            ),
            const SizedBox(height: 18),
            const _Etiqueta('FECHA DE SIEMBRA'),
            const SizedBox(height: 8),
            TextField(
              controller: _fechaCtrl,
              keyboardType: TextInputType.datetime,
              onChanged: (value) {
                final parsed = DateTime.tryParse(value.trim());
                if (parsed != null) setState(() => _fechaSiembra = parsed);
              },
              decoration: InputDecoration(
                hintText: 'AAAA-MM-DD',
                suffixIcon: IconButton(
                  tooltip: 'Elegir fecha',
                  onPressed: _elegirFecha,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _Etiqueta('ÁREA (MANZANAS)'),
            const SizedBox(height: 8),
            TextField(
              controller: _areaCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: 'Ej: 1.5'),
            ),
            const SizedBox(height: 18),
            LocationPickerField(
              latitudCtrl: _latitudCtrl,
              longitudCtrl: _longitudCtrl,
              onChanged: () {},
            ),
            const SizedBox(height: 18),
            const _Etiqueta('MUNICIPIO O DEPARTAMENTO (RESPALDO SIN GPS)'),
            const SizedBox(height: 8),
            TextField(
              controller: _municipioCtrl,
              decoration: const InputDecoration(hintText: 'Ej: Jinotepe'),
            ),
            const SizedBox(height: 18),
            const _Etiqueta('COMUNIDAD (OPCIONAL)'),
            const SizedBox(height: 8),
            TextField(
              controller: _comunidadCtrl,
              decoration: const InputDecoration(hintText: 'Ej: El Rosario'),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'Guardando...' : 'Guardar cambios'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Los cambios quedan guardados en este teléfono.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;

  const _Etiqueta(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.soil,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
