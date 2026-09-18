import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AppLoadingMessage extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;

  const AppLoadingMessage({
    super.key,
    this.message = 'Cargando...',
    this.icon = Icons.hourglass_empty,
    this.color = AppColors.greenDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
