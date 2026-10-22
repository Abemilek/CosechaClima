import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app/app_state.dart';
import '../features/onboarding/presentation/screens/splash_screen.dart';
import '../features/parcela/presentation/screens/parcela_list_screen.dart';
import '../shared/widgets/app_loading_message.dart';

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (app.cargando) {
      return const Scaffold(
        body: AppLoadingMessage(message: 'Preparando la app...'),
      );
    }

    if (!app.onboardingVisto) return const SplashScreen();

    return const ParcelaListScreen();
  }
}
