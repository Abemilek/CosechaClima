import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../view_models/auth_view_model.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _esRegistro = true;
  bool _mostrarPassword = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _emailValido {
    final texto = _emailCtrl.text.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto);
  }

  bool get _formValido {
    if (!_emailValido) return false;
    if (_passwordCtrl.text.length < 8) return false;
    if (_esRegistro && _nombreCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _enviar() async {
    if (!_formValido) return;

    final auth = context.read<AuthViewModel>();
    final ok = _esRegistro
        ? await auth.registrarConEmail(
            nombre: _nombreCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          )
        : await auth.loginConEmail(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );

    if (ok && mounted) Navigator.of(context).pop(true);
  }

  void _cambiarModo(bool esRegistro) {
    if (_esRegistro == esRegistro) return;
    context.read<AuthViewModel>().limpiarError();
    setState(() => _esRegistro = esRegistro);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: Text(_esRegistro ? 'Crear cuenta' : 'Iniciar sesión'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            _ConmutadorModo(esRegistro: _esRegistro, onCambio: _cambiarModo),
            const SizedBox(height: 26),

            if (_esRegistro) ...[
              const _Etiqueta('TU NOMBRE'),
              const SizedBox(height: 8),
              TextField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Ej: Carlos Méndez',
                ),
              ),
              const SizedBox(height: 18),
            ],

            const _Etiqueta('CORREO'),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'ejemplo@correo.com'),
            ),
            const SizedBox(height: 18),

            const _Etiqueta('CONTRASEÑA'),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordCtrl,
              obscureText: !_mostrarPassword,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _enviar(),
              decoration: InputDecoration(
                hintText: _esRegistro ? 'Mínimo 8 caracteres' : 'Tu contraseña',
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.muted,
                  ),
                  onPressed: () =>
                      setState(() => _mostrarPassword = !_mostrarPassword),
                ),
              ),
            ),

            if (_esRegistro) ...[
              const SizedBox(height: 8),
              Text(
                _passwordCtrl.text.isEmpty || _passwordCtrl.text.length >= 8
                    ? 'Usá al menos 8 caracteres. Mientras más larga, más segura.'
                    : 'Te faltan ${8 - _passwordCtrl.text.length} caracteres.',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      _passwordCtrl.text.isEmpty ||
                          _passwordCtrl.text.length >= 8
                      ? AppColors.muted
                      : AppColors.red,
                ),
              ),
            ],

            if (auth.error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.redBg,
                  borderRadius: BorderRadius.circular(AppRadius.cardSmall),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: AppColors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        auth.error!,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 26),
            FilledButton(
              onPressed: (auth.cargando || !_formValido) ? null : _enviar,
              child: auth.cargando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_esRegistro ? 'Crear mi cuenta' : 'Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConmutadorModo extends StatelessWidget {
  final bool esRegistro;
  final ValueChanged<bool> onCambio;

  const _ConmutadorModo({required this.esRegistro, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.paper2,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          Expanded(
            child: _OpcionModo(
              texto: 'Soy nuevo',
              activo: esRegistro,
              onTap: () => onCambio(true),
            ),
          ),
          Expanded(
            child: _OpcionModo(
              texto: 'Ya tengo cuenta',
              activo: !esRegistro,
              onTap: () => onCambio(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpcionModo extends StatelessWidget {
  final String texto;
  final bool activo;
  final VoidCallback onTap;

  const _OpcionModo({
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? AppColors.paper : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.input),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Text(
            texto,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: activo ? AppColors.greenDark : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;

  const _Etiqueta(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.soil,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
