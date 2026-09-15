import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/pin_input.dart';
import '../../../parcela/presentation/screens/parcela_list_screen.dart';
import '../view_models/auth_view_model.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _telefonoCtrl = TextEditingController();
  String _pin = '';

  @override
  void dispose() {
    _telefonoCtrl.dispose();
    super.dispose();
  }

  bool get _telefonoValido =>
      RegExp(r'^\d{8}$').hasMatch(_telefonoCtrl.text.trim());
  bool get _pinValido => RegExp(r'^\d{4}$').hasMatch(_pin);
  bool get _formValido => _telefonoValido && _pinValido;

  Future<void> _submit() async {
    if (!_formValido) return;
    final auth = context.read<AuthViewModel>();
    final ok = await auth.login(telefono: _telefonoCtrl.text.trim(), pin: _pin);
    if (ok && mounted) {
      await Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const ParcelaListScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Center(
                child: AppAvatar(
                  icon: Icons.shield_outlined,
                  size: AppAvatarSize.large,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Iniciá sesión',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: ['Times New Roman', 'serif'],
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ingresá tu número de teléfono y tu PIN de 4 dígitos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 28),
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
              const SizedBox(height: 20),
              const Text(
                'PIN DE 4 DÍGITOS',
                style: TextStyle(
                  color: AppColors.soil,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              PinInput(onChanged: (v) => setState(() => _pin = v)),
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
                    : const Text('Iniciar sesión'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegisterScreen(),
                    ),
                  ),
                  child: const Text('¿No tenés cuenta? Registrate'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
