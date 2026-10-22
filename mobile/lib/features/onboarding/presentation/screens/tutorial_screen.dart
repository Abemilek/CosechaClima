import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/app/app_state.dart';
import '../../../../core/config/environment.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../routing/no_animation_route.dart';
import '../../../../shared/widgets/progress_dots.dart';
import '../../../parcela/presentation/screens/parcela_list_screen.dart';

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
    title: 'Tu semáforo de riesgo',
    body:
        'Revisamos el clima de tu zona junto con tu cultivo, la etapa y el '
        'suelo para decirte si el riesgo es bajo, medio o alto.',
  ),
  _TutorialStep(
    icon: Icons.checklist,
    title: 'Tu plan de la semana',
    body:
        'Sin teoría ni videos largos: te damos pocas acciones concretas para '
        'hacer en tu parcela y el día más delicado de la semana.',
  ),
  _TutorialStep(
    icon: Icons.menu_book_outlined,
    title: 'Tu cuaderno de campo',
    body:
        'Marcá lo que ya hiciste y quedate con el historial de tu parcela. '
        'Todo se guarda en tu teléfono, sin cuentas ni servidores.',
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
    await context.read<AppState>().marcarOnboardingVisto();
    if (!mounted) return;

    unawaited(
      Navigator.of(context).pushReplacement<void, void>(
        noAnimationRoute<void>((_) => const ParcelaListScreen()),
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
      Navigator.of(context).maybePop();
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
              const SizedBox(height: 6),
              const Text(
                Environment.atribucionClima,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: AppColors.muted),
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
