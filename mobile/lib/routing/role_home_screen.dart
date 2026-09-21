import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/admin/presentation/screens/admin_home_screen.dart';
import '../features/auth/presentation/view_models/auth_view_model.dart';
import '../features/onboarding/presentation/screens/public_home_screen.dart';
import '../features/parcela/presentation/screens/parcela_list_screen.dart';

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    if (!auth.estaAutenticado) return const PublicHomeScreen();

    return auth.esAdmin ? const AdminHomeScreen() : const ParcelaListScreen();
  }
}
