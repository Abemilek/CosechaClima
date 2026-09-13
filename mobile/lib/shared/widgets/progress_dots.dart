import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ProgressDots extends StatelessWidget {
  final int total;
  final int activeIndex;

  const ProgressDots({super.key, required this.total, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == activeIndex;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: active ? 32 : 10,
            height: 8,
            decoration: BoxDecoration(
              color: active ? AppColors.green : const Color(0xFFDED7CF),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        );
      }),
    );
  }
}