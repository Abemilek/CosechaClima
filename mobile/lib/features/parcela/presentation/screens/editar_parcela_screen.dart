import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/location_picker_field.dart';
import '../../data/models/parcela.dart';
import '../view_models/parcela_view_model.dart';

class EditarParcelaScreen extends StatefulWidget {
  final Parcela parcela;

  const EditarParcelaScreen({super.key, required this.parcela});

  @override
  State<EditarParcelaScreen> createState() => _EditarParcelaScreenState();
}

class _EditarParcelaScreenState extends State<EditarParcelaScreen> {
  late final TextEditingController _areaCtrl;
  late final TextEditingController _municipioCtrl;
  late final TextEditingController _comunidadCtrl;
  late final TextEditingController _latitudCtrl;
  late final TextEditingController _longitudCtrl;
  int? _etapaId;

  @override
  void initState() {
    super.initState();
    final p = widget.parcela;
    _areaCtrl = TextEditingController(text: p.areaMzs.toString());
    _municipioCtrl = TextEditingController(text: p.municipio ?? '');
    _comunidadCtrl = TextEditingController(text: p.comunidad ?? '');
    _latitudCtrl = TextEditingController(text: p.latitud?.toString() ?? '');
    _longitudCtrl = TextEditingController(text: p.longitud?.toString() ?? '');
    _etapaId = p.etapaFenologicaId;
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    _municipioCtrl.dispose();
    _comunidadCtrl.dispose();
    _latitudCtrl.dispose();
    _longitudCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final provider = context.read<ParcelaViewModel>();
    final area = double.tryParse(_areaCtrl.text.trim());

    final request = ParcelaUpdateRequest(
      latitud: _latitudCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_latitudCtrl.text.trim()),
      longitud: _longitudCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_longitudCtrl.text.trim()),
      areaMzs: area,
      municipio: _municipioCtrl.text.trim().isEmpty
          ? null
          : _municipioCtrl.text.trim(),
      comunidad: _comunidadCtrl.text.trim().isEmpty
          ? null
          : _comunidadCtrl.text.trim(),
    );

    final etapaCambio = _etapaId != widget.parcela.etapaFenologicaId
        ? _etapaId
        : null;

    final ok = await provider.actualizarParcela(
      widget.parcela.id,
      request,
      nuevaEtapaId: etapaCambio,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Parcela actualizada')));
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
      appBar: AppBar(title: const Text('Editar parcela')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                controller: _areaCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(hintText: 'Ej: 1.5'),
              ),
              const SizedBox(height: 20),
              LocationPickerField(
                latitudCtrl: _latitudCtrl,
                longitudCtrl: _longitudCtrl,
                onChanged: () {},
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
                controller: _municipioCtrl,
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
                controller: _comunidadCtrl,
                decoration: const InputDecoration(hintText: 'Ej: El Rosario'),
              ),
              if (provider.etapas.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'ETAPA FENOLÓGICA',
                  style: TextStyle(
                    color: AppColors.soil,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: _etapaId,
                  decoration: const InputDecoration(
                    hintText: 'Sin especificar',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sin especificar'),
                    ),
                    ...provider.etapas.map(
                      (e) =>
                          DropdownMenuItem(value: e.id, child: Text(e.nombre)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _etapaId = v),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: provider.cargando ? null : _guardar,
                child: provider.cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
