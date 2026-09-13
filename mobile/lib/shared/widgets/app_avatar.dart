import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum AppAvatarVariant { mint, soil }

enum AppAvatarSize { normal, large }

class AppAvatar extends StatelessWidget {
  final IconData icon;
  final AppAvatarVariant variant;
  final AppAvatarSize size;

  const AppAvatar({
    super.key,
    required this.icon,
    this.variant = AppAvatarVariant.mint,
    this.size = AppAvatarSize.normal,
  });

  @override
  Widget build(BuildContext context) {
    final dimension = size == AppAvatarSize.large ? 72.0 : 42.0;
    final bg = variant == AppAvatarVariant.soil
        ? const Color(0xFFEEE0D2)
        : AppColors.mint2;
    final fg = variant == AppAvatarVariant.soil
        ? AppColors.soil
        : AppColors.greenDark;

    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.green.withValues(alpha: 0.18),
          width: 2,
        ),
      ),
      child: Icon(icon, color: fg, size: size == AppAvatarSize.large ? 34 : 20),
    );
  }
}
