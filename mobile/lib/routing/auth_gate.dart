import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/presentation/view_models/auth_view_model.dart';
import '../features/onboarding/presentation/screens/splash_screen.dart';
import '../features/parcela/presentation/screens/parcela_list_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<AuthViewModel>().estado;

    switch (estado) {
      case EstadoSesion.desconocido:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case EstadoSesion.autenticado:
        return const ParcelaListScreen();
      case EstadoSesion.invitado:
        return const SplashScreen();
    }
  }
}
