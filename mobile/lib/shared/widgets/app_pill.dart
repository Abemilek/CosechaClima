import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum AppPillVariant { normal, warn, red, dark }

class AppPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final AppPillVariant variant;

  const AppPill({
    super.key,
    required this.text,
    this.icon,
    this.variant = AppPillVariant.normal,
  });

  Color get _bg {
    switch (variant) {
      case AppPillVariant.warn:
        return AppColors.amberBg;
      case AppPillVariant.red:
        return AppColors.redBg;
      case AppPillVariant.dark:
        return Colors.white.withOpacity(0.14);
      case AppPillVariant.normal:
        return AppColors.green.withOpacity(0.1);
    }
  }

  Color get _fg {
    switch (variant) {
      case AppPillVariant.warn:
        return const Color(0xFFA56800);
      case AppPillVariant.red:
        return const Color(0xFFB01111);
      case AppPillVariant.dark:
        return Colors.white;
      case AppPillVariant.normal:
        return AppColors.greenDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: _fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: _fg,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
