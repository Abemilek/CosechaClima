import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/pin_input.dart';
import '../view_models/auth_view_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  String _pin = '';
  String _pinConfirm = '';

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  bool get _nombreValido => _nombreCtrl.text.trim().isNotEmpty;
  bool get _telefonoValido =>
      RegExp(r'^\d{8}$').hasMatch(_telefonoCtrl.text.trim());
  bool get _pinValido => RegExp(r'^\d{4}$').hasMatch(_pin);
  bool get _pinsCoinciden => _pinValido && _pin == _pinConfirm;

  String? get _errorPinConfirm {
    if (_pinConfirm.isEmpty || _pinConfirm.length < 4) return null;
    if (_pin != _pinConfirm) return 'Los PIN no coinciden';
    return null;
  }

  bool get _formValido => _nombreValido && _telefonoValido && _pinsCoinciden;

  Future<void> _submit() async {
    if (!_formValido) return;
    final auth = context.read<AuthViewModel>();
    final ok = await auth.registrar(
      nombre: _nombreCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      pin: _pin,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada. Ahora podés iniciar sesión.'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('CosechaClima')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: AppAvatar(
                  icon: Icons.shield_outlined,
                  size: AppAvatarSize.large,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Creá tu cuenta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: ['Times New Roman', 'serif'],
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Con tu teléfono y un PIN de 4 dígitos protegés tu parcela climática.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              const Text(
                'TU NOMBRE',
                style: TextStyle(
                  color: AppColors.soil,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nombreCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Ej: Carlos'),
              ),
              const SizedBox(height: 18),
              const Text(
                'TU TELÉFONO',
                style: TextStyle(
                  color: AppColors.soil,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 8,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '88887777',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'NUEVO PIN DE 4 DÍGITOS',
                style: TextStyle(
                  color: AppColors.soil,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              PinInput(onChanged: (v) => setState(() => _pin = v)),
              const SizedBox(height: 18),
              const Text(
                'CONFIRMÁ EL PIN',
                style: TextStyle(
                  color: AppColors.soil,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              PinInput(
                onChanged: (v) => setState(() => _pinConfirm = v),
                errorText: _errorPinConfirm,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(AppRadius.cardSmall),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAvatar(icon: Icons.shield_outlined),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tu PIN viaja cifrado (HTTPS) y se guarda con hash seguro en '
                        'nuestro servidor — nunca en texto plano. Lo necesitás para '
                        'iniciar sesión desde cualquier dispositivo.',
                        style: TextStyle(color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  auth.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (auth.cargando || !_formValido) ? null : _submit,
                child: auth.cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Registrarme'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
