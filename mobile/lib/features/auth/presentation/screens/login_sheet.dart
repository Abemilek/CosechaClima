import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/environment.dart';
import '../../../../core/theme/app_theme.dart';
import '../view_models/auth_view_model.dart';
import 'email_auth_screen.dart';

Future<bool?> mostrarLoginContextual(
  BuildContext context, {
  required String motivo,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LoginContextualSheet(motivo: motivo),
  );
}

class _LoginContextualSheet extends StatelessWidget {
  final String motivo;

  const _LoginContextualSheet({required this.motivo});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.soft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Icon(Icons.lock_outline, size: 34, color: AppColors.greenDark),
          const SizedBox(height: 14),
          Text(
            motivo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontFamilyFallback: ['Times New Roman', 'serif'],
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crear una cuenta es gratis y toma unos segundos. '
            'Seguís pudiendo ver el clima sin cuenta cuando quieras.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),

          if (Environment.googleSignInDisponible) ...[
            _BotonGoogle(
              cargando: auth.cargando,
              onPressed: () async {
                final ok = await context.read<AuthViewModel>().loginConGoogle();
                if (ok && context.mounted) Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: 12),
          ],

          OutlinedButton.icon(
            onPressed: auth.cargando
                ? null
                : () async {
                    final ok = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => const EmailAuthScreen(),
                      ),
                    );
                    if ((ok ?? false) && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
            icon: const Icon(Icons.mail_outline, size: 20),
            label: const Text('Usar correo y contraseña'),
          ),

          if (auth.error != null) ...[
            const SizedBox(height: 14),
            Text(
              auth.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],

          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ahora no'),
          ),
        ],
      ),
    );
  }
}

class _BotonGoogle extends StatelessWidget {
  final bool cargando;
  final VoidCallback onPressed;

  const _BotonGoogle({required this.cargando, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F1F1F),
        side: const BorderSide(color: Color(0xFFDADCE0)),
        minimumSize: const Size.fromHeight(56),
      ),
      onPressed: cargando ? null : onPressed,
      icon: cargando
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const _LogoGoogle(),
      label: const Text('Continuar con Google'),
    );
  }
}

class _LogoGoogle extends StatelessWidget {
  const _LogoGoogle();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _PintorLogoGoogle()),
    );
  }
}

class _PintorLogoGoogle extends CustomPainter {
  const _PintorLogoGoogle();

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = size.width / 2;
    final grosor = size.width * 0.22;

    final rect = Rect.fromCircle(center: centro, radius: radio - grosor / 2);

    void arco(double inicioGrados, double barridoGrados, Color color) {
      final pincel = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor;
      canvas.drawArc(
        rect,
        inicioGrados * 3.1415926535 / 180,
        barridoGrados * 3.1415926535 / 180,
        false,
        pincel,
      );
    }

    arco(-15, -75, const Color(0xFFEA4335));
    arco(-90, -100, const Color(0xFFFBBC05));
    arco(170, -80, const Color(0xFF34A853));
    arco(90, -80, const Color(0xFF4285F4));

    final barra = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.52,
        size.height * 0.40,
        size.width * 0.46,
        grosor * 0.9,
      ),
      barra,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
