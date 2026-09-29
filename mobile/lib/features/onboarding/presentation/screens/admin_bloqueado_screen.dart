import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../routing/auth_gate.dart';
import '../../../../routing/no_animation_route.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';

class AdminBloqueadoScreen extends StatelessWidget {
  const AdminBloqueadoScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmado = await mostrarConfirmacion(
      context,
      titulo: '¿Deseas cerrar la sesión?',
      mensaje: 'Vas a tener que iniciar sesión de nuevo.',
      textoConfirmar: 'Cerrar sesión',
      esDestructivo: true,
    );
    if (!confirmado || !context.mounted) return;

    await context.read<AuthViewModel>().cerrarSesion();
    if (!context.mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      noAnimationRoute<void>((_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                size: 72,
                color: AppColors.green,
              ),
              const SizedBox(height: 20),
              const Text(
                'Esta cuenta es de administrador',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: ['Times New Roman', 'serif'],
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'La app móvil es solo para productores. Para gestionar usuarios, '
                'reglas de alertas y el historial del sistema, ingresá al panel '
                'administrativo desde una computadora.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              OutlinedButton(
                onPressed: () => _cerrarSesion(context),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
