import 'package:flutter/material.dart';

Future<bool> mostrarConfirmacion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoConfirmar = 'Confirmar',
  String textoCancelar = 'Cancelar',
  bool esDestructivo = false,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(textoCancelar),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: esDestructivo
              ? TextButton.styleFrom(foregroundColor: Colors.red)
              : null,
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return resultado ?? false;
}
