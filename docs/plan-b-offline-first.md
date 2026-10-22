# Plan B: motor en el dispositivo (histórico)

Este documento describía la arquitectura anterior: motor en el teléfono con un
backend delgado para cuentas, parcelas, bitácora y actualización de reglas.

Ese plan quedó **reemplazado por el Plan A: app móvil 100 % local**. La app ya
no usa cuentas, servidores, JWT ni actualización remota de reglas. El backend y
el Admin Console se conservan como código histórico/de referencia.

La arquitectura vigente está en [local-first.md](./local-first.md).
