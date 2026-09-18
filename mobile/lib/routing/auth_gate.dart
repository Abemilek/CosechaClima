import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/presentation/view_models/auth_view_model.dart';
import '../features/onboarding/presentation/screens/splash_screen.dart';
import '../shared/widgets/app_loading_message.dart';
import 'role_home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<AuthViewModel>().estado;

    switch (estado) {
      case EstadoSesion.desconocido:
        return const Scaffold(
          body: AppLoadingMessage(message: 'Preparando la app...'),
        );
      case EstadoSesion.autenticado:
        return const RoleHomeScreen();
      case EstadoSesion.invitado:
        return const SplashScreen();
    }
  }
}
