import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../widgets/app_pill.dart';

class RiesgoUi {
  RiesgoUi._();

  static Color colorPara(String? nivelRiesgo) {
    switch (_normalizado(nivelRiesgo)) {
      case 'alto':
        return AppColors.red;
      case 'medio':
        return AppColors.amber;
      case 'bajo':
        return AppColors.green;
      default:
        return AppColors.muted;
    }
  }

  static Color colorFondoSuavePara(String? nivelRiesgo) {
    switch (_normalizado(nivelRiesgo)) {
      case 'alto':
        return AppColors.redBg;
      case 'medio':
        return AppColors.amberBg;
      case 'bajo':
        return AppColors.mint;
      default:
        return AppColors.soft;
    }
  }

  static AppPillVariant variantePara(String? nivelRiesgo) {
    switch (_normalizado(nivelRiesgo)) {
      case 'alto':
        return AppPillVariant.red;
      case 'medio':
        return AppPillVariant.warn;
      case 'bajo':
        return AppPillVariant.normal;
      default:
        return AppPillVariant.dark;
    }
  }

  static String? _normalizado(String? nivelRiesgo) =>
      nivelRiesgo?.trim().toLowerCase();
}
