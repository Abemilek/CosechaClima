import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../routing/no_animation_route.dart';
import '../../../../routing/role_home_screen.dart';
import '../../../../shared/widgets/progress_dots.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';

class _TutorialStep {
  final IconData icon;
  final String title;
  final String body;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.body,
  });
}

const _steps = [
  _TutorialStep(
    icon: Icons.traffic,
    title: 'Tu semáforo del día',
    body:
        'Analizamos clima, cultivo, etapa, suelo y tus umbrales para decirte '
        'si hoy hay riesgo bajo, medio o alto.',
  ),
  _TutorialStep(
    icon: Icons.checklist,
    title: '3 acciones para hoy',
    body:
        'Nada de teoría ni videos largos. Cada alerta te dice exactamente '
        'tres cosas que podés hacer en tu parcela.',
  ),
  _TutorialStep(
    icon: Icons.menu_book_outlined,
    title: 'Historial en tu bitácora',
    body:
        'Registrá qué acciones cumpliste y consultá el historial de alertas '
        'de tu parcela cuando quieras, incluso días después.',
  ),
];

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _terminarOnboarding() async {
    await context.read<AuthViewModel>().marcarOnboardingVisto();
    if (!mounted) return;

    unawaited(
      Navigator.of(context).pushReplacement<void, void>(
        noAnimationRoute<void>((_) => const RoleHomeScreen()),
      ),
    );
  }

  void _next() {
    if (_index == _steps.length - 1) {
      unawaited(_terminarOnboarding());
      return;
    }
    _pageController.jumpToPage(_index + 1);
  }

  void _back() {
    if (_index == 0) {
      Navigator.of(context).pop();
      return;
    }
    _pageController.jumpToPage(_index - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.greenDark,
                  ),
                  Expanded(
                    child: Text(
                      '${_index + 1} de ${_steps.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
              ProgressDots(total: _steps.length, activeIndex: _index),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _TutorialPage(step: _steps[i]),
                ),
              ),
              FilledButton(
                onPressed: _next,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _index == _steps.length - 1 ? '¡Comenzar!' : 'Siguiente',
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => unawaited(_terminarOnboarding()),
                child: const Text('Omitir tutorial'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  final _TutorialStep step;

  const _TutorialPage({required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 190,
          height: 190,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          child: Icon(step.icon, size: 84, color: AppColors.green),
        ),
        const SizedBox(height: 32),
        Text(
          step.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: ['Times New Roman', 'serif'],
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          step.body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
