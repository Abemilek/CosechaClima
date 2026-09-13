import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'tutorial_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.greenDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 28, 30, 30),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 120,
                        color: Color(0xFFB9F3C4),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'CosechaClima',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontFamilyFallback: ['Times New Roman', 'serif'],
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Tu semáforo de decisiones climáticas para el campo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Carazo, Nicaragua',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mint2,
                        foregroundColor: const Color(0xFF07160D),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pushReplacement<void, void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const TutorialScreen(),
                            ),
                          ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Comenzar'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Versión 1.0 · Ciclo agrícola 2026',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
