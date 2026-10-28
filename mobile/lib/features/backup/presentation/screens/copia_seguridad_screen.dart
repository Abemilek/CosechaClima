import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../data/services/local_backup_service.dart';

class CopiaSeguridadScreen extends StatefulWidget {
  const CopiaSeguridadScreen({super.key});

  @override
  State<CopiaSeguridadScreen> createState() => _CopiaSeguridadScreenState();
}

class _CopiaSeguridadScreenState extends State<CopiaSeguridadScreen> {
  final _service = LocalBackupService();
  String? _respaldo;
  bool _cargando = true;
  bool _restaurando = false;

  @override
  void initState() {
    super.initState();
    unawaited(_generar());
  }

  Future<void> _generar() async {
    setState(() => _cargando = true);
    try {
      final respaldo = await _service.exportar();
      if (!mounted) return;
      setState(() => _respaldo = respaldo);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo generar la copia.')),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _copiar() async {
    final respaldo = _respaldo;
    if (respaldo == null) return;
    await Clipboard.setData(ClipboardData(text: respaldo));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copia copiada. Guardala en un lugar seguro.'),
      ),
    );
  }

  Future<void> _verTexto() async {
    final respaldo = _respaldo;
    if (respaldo == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Texto de la copia'),
        content: SizedBox(
          width: double.maxFinite,
          height: 360,
          child: SingleChildScrollView(
            child: SelectableText(
              respaldo,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _restaurarDesdePortapapeles() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final texto = data?.text?.trim();
    if (texto == null || texto.isEmpty) {
      _mostrarError('El portapapeles está vacío.');
      return;
    }
    await _restaurar(texto);
  }

  Future<void> _restaurarDesdeTexto() async {
    final controller = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar desde texto'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Pegá aquí el respaldo JSON de CosechaClima',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (texto == null || texto.isEmpty) return;
    await _restaurar(texto);
  }

  Future<void> _restaurar(String texto) async {
    final confirmar = await mostrarConfirmacion(
      context,
      titulo: '¿Restaurar esta copia?',
      mensaje:
          'Se van a reemplazar las parcelas, la bitácora y los umbrales que '
          'están en este teléfono por los de la copia.',
      textoConfirmar: 'Restaurar',
      esDestructivo: true,
    );
    if (!confirmar || !mounted) return;

    setState(() => _restaurando = true);
    try {
      final resultado = await _service.importar(texto);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restaurado: ${resultado.parcelas} parcelas y '
            '${resultado.entradasBitacora} entradas de bitácora.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on FormatException catch (e) {
      _mostrarError(e.message);
    } catch (_) {
      _mostrarError('La copia está dañada o no tiene el formato esperado.');
    } finally {
      if (mounted) setState(() => _restaurando = false);
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Copia de seguridad')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(AppRadius.cardSmall),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.phone_android, color: AppColors.greenDark),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tus parcelas, tu bitácora y tus alertas viven solo en '
                      'este teléfono. Si cambiás de teléfono o desinstalás la '
                      'app, vas a necesitar esta copia para recuperarlos.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.greenDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'EXPORTAR',
              style: TextStyle(
                color: AppColors.soil,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Copiá el respaldo y guardalo en WhatsApp, correo o un archivo '
              'personal. Contiene todo lo que registraste en la app.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _cargando || _respaldo == null ? null : _copiar,
              icon: const Icon(Icons.copy_all_outlined),
              label: Text(
                _cargando ? 'Preparando copia...' : 'Copiar respaldo',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _cargando || _respaldo == null ? null : _verTexto,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Ver texto del respaldo'),
            ),
            const SizedBox(height: 28),
            const Text(
              'RESTAURAR',
              style: TextStyle(
                color: AppColors.soil,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Restaurar reemplaza los datos actuales por los de la copia. '
              'Hacelo solo si estás seguro.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _restaurando ? null : _restaurarDesdePortapapeles,
              icon: const Icon(Icons.content_paste_go),
              label: const Text('Restaurar desde el portapapeles'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _restaurando ? null : _restaurarDesdeTexto,
              icon: const Icon(Icons.edit_note),
              label: const Text('Pegar el respaldo manualmente'),
            ),
            if (_restaurando) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
