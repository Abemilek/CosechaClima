import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/admin/presentation/screens/admin_home_screen.dart';
import '../features/auth/presentation/view_models/auth_view_model.dart';
import '../features/parcela/presentation/screens/parcela_list_screen.dart';

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final esAdmin = context.select<AuthViewModel, bool>((auth) => auth.esAdmin);
    return esAdmin ? const AdminHomeScreen() : const ParcelaListScreen();
  }
}
