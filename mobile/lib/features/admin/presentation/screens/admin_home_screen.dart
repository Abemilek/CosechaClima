import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../routing/auth_gate.dart';
import '../../../../routing/no_animation_route.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import 'admin_panel_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    await context.read<AuthViewModel>().cerrarSesion();
    if (!context.mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      noAnimationRoute<void>((_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nombre = context.select<AuthViewModel, String?>(
      (auth) => auth.nombre,
    );

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                const AppAvatar(icon: Icons.admin_panel_settings_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ADMINISTRACIÓN',
                        style: TextStyle(
                          color: AppColors.soil,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        nombre ?? 'Admin',
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontFamilyFallback: ['Times New Roman', 'serif'],
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  icon: const Icon(Icons.logout),
                  color: AppColors.muted,
                  onPressed: () => _cerrarSesion(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Herramientas de gestión',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontFamilyFallback: ['Times New Roman', 'serif'],
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Este espacio queda separado de la experiencia del productor.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            _AdminActionCard(
              icon: Icons.rule_outlined,
              title: 'Motor de decisiones',
              subtitle: 'Sembrar y mantener reglas agronómicas.',
              onTap: () => Navigator.of(context).push<void>(
                noAnimationRoute<void>((_) => const AdminPanelScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.cardSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.cardSmall),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.cardSmall),
            border: Border.all(color: const Color(0xFFE8D8C8)),
          ),
          child: Row(
            children: [
              AppAvatar(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
