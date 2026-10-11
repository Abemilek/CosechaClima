import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/clima/open_meteo_client.dart';
import 'package:mobile/core/motor/motor_local.dart';
import 'package:mobile/core/motor/paquete_reglas.dart';
import 'package:mobile/features/clima/data/models/clima.dart';

PaqueteReglas _cargarAsset() {
  final texto = File('assets/reglas/paquete_reglas.json').readAsStringSync();
  return PaqueteReglas.fromJson(jsonDecode(texto) as Map<String, dynamic>);
}

DiaClima _dia(
  DateTime fecha, {
  double? tmax = 30,
  double? tmin = 20,
  double? lluvia = 1,
  double? viento = 10,
}) => DiaClima(
  fecha: fecha,
  temperaturaMax: tmax,
  temperaturaMin: tmin,
  precipitacion: lluvia,
  vientoVelocidad: viento,
);

SerieClima _serie(List<DiaClima> dias) =>
    SerieClima(dias: dias, descargadaEn: DateTime(2026, 10, 9), diasPasados: 0);

void main() {
  final paquete = _cargarAsset();
  final hoy = DateTime(2026, 10, 9);

  test('el paquete embebido trae 540 reglas y los catálogos esperados', () {
    expect(paquete.totalReglas, 540);
    expect(paquete.eventos.length, 6);
    expect(paquete.cultivos.length, 5);
    expect(paquete.tiposSuelo.length, 3);
    expect(paquete.etapas.length, 6);
  });

  group('eventosActivos', () {
    const u = UmbralesMotor();

    List<int> eventos({
      double? tmin,
      double? tmax,
      double? lluvia,
      double? viento,
      bool canicula = false,
    }) => MotorLocal.eventosActivos(
      temperaturaMin: tmin,
      temperaturaMax: tmax,
      precipitacion: lluvia,
      viento: viento,
      umbrales: u,
      caniculaActiva: canicula,
    );

    test('día normal = sin riesgo', () {
      expect(eventos(tmin: 20, tmax: 30, lluvia: 5, viento: 10), [
        EventoId.sinRiesgo,
      ]);
    });

    test('helada con 2 °C o menos', () {
      expect(eventos(tmin: 2), [EventoId.riesgoHelada]);
      expect(eventos(tmin: 2.1), [EventoId.sinRiesgo]);
    });

    test('umbrales de lluvia, viento y calor son inclusivos', () {
      expect(eventos(lluvia: 100), [EventoId.lluviaIntensa]);
      expect(eventos(viento: 40), [EventoId.vientoFuerte]);
      expect(eventos(tmax: 35), [EventoId.temperaturaExtrema]);
      expect(eventos(lluvia: 99.9, viento: 39.9, tmax: 34.9), [
        EventoId.sinRiesgo,
      ]);
    });

    test('mantiene el orden de desempate del servidor', () {
      expect(
        eventos(tmin: 1, tmax: 36, lluvia: 120, viento: 50, canicula: true),
        [
          EventoId.riesgoHelada,
          EventoId.lluviaIntensa,
          EventoId.vientoFuerte,
          EventoId.temperaturaExtrema,
          EventoId.canicula,
        ],
      );
    });
  });

  group('caniculaEn', () {
    final base = DateTime(2026, 10, 1);
    List<DiaClima> secos(int n) => [
      for (var i = 0; i < n; i++) _dia(base.add(Duration(days: i)), lluvia: 0),
    ];

    test('7 días secos seguidos', () {
      expect(MotorLocal.caniculaEn(secos(7), 6, 7), isTrue);
    });

    test('sin suficientes días hacia atrás no se afirma', () {
      expect(MotorLocal.caniculaEn(secos(7), 5, 7), isFalse);
    });

    test('una lluvia en la ventana la cancela; null cuenta como seco', () {
      final dias = secos(7);
      dias[3] = _dia(dias[3].fecha, lluvia: 0.5);
      expect(MotorLocal.caniculaEn(dias, 6, 7), isFalse);
      dias[3] = _dia(dias[3].fecha, lluvia: null);
      expect(MotorLocal.caniculaEn(dias, 6, 7), isTrue);
    });
  });

  group('etapaId', () {
    test('usa la etapa guardada si existe', () {
      expect(
        MotorLocal.etapaId(
          paquete,
          etapaFenologicaId: 4,
          fechaSiembra: hoy,
          hoy: hoy,
        ),
        4,
      );
    });

    test('calcula por días desde la siembra', () {
      int etapa(int dias) => MotorLocal.etapaId(
        paquete,
        etapaFenologicaId: null,
        fechaSiembra: hoy.subtract(Duration(days: dias)),
        hoy: hoy,
      );
      // Germinación 0, Plántula 11, Vegetativo 26, Floración 56, Llenado 71, Maduración 91
      expect(etapa(0), 1);
      expect(etapa(10), 1);
      expect(etapa(11), 2);
      expect(etapa(60), 4);
      expect(etapa(200), 6);
    });
  });

  group('semáforo y resumen', () {
    // Maíz (1), suelo franco (1), etapa germinación (1)
    Semaforo semaforo(
      SerieClima serie, {
      UmbralesMotor u = const UmbralesMotor(),
    }) => MotorLocal.semaforoDeHoy(
      paquete: paquete,
      serie: serie,
      hoy: hoy,
      cultivoId: 1,
      etapaFenologicaId: 1,
      tipoSueloId: 1,
      fechaSiembra: hoy,
      umbrales: u,
    );

    test('día normal: riesgo bajo con las 3 acciones', () {
      final s = semaforo(_serie([_dia(hoy)]));
      expect(s.eventoClimaticoId, EventoId.sinRiesgo);
      expect(s.nivelRiesgo, 'Bajo');
      expect(s.acciones.length, 3);
    });

    test('gana el evento de mayor riesgo', () {
      // Maíz/germinación/franco: helada = Bajo, lluvia intensa = Alto.
      final s = semaforo(_serie([_dia(hoy, tmin: 1, lluvia: 150)]));
      expect(s.eventoClimaticoId, EventoId.lluviaIntensa);
      expect(s.nivelRiesgo, 'Alto');
    });

    test('si la serie no cubre hoy, lanza MotorLocalException', () {
      expect(
        () => semaforo(_serie([_dia(DateTime(2026, 10, 1))])),
        throwsA(isA<MotorLocalException>()),
      );
    });

    test('la canícula usa los días ya pasados de la serie', () {
      final dias = [
        for (var i = 6; i >= 0; i--)
          _dia(hoy.subtract(Duration(days: i)), lluvia: 0),
      ];
      final s = semaforo(_serie(dias));
      expect(s.eventoClimaticoId, EventoId.canicula);
    });

    test('el resumen cubre hoy + 6 días y marca el día más crítico', () {
      final dias = [
        for (var i = 0; i < 8; i++)
          _dia(hoy.add(Duration(days: i)), lluvia: i == 3 ? 150 : 1),
      ];
      final r = MotorLocal.resumenSemanal(
        paquete: paquete,
        serie: _serie(dias),
        hoy: hoy,
        cultivoId: 1,
        etapaFenologicaId: 1,
        tipoSueloId: 1,
        fechaSiembra: hoy,
        umbrales: const UmbralesMotor(),
      );
      expect(r.dias.length, 7);
      expect(r.diaMasCritico, hoy.add(const Duration(days: 3)));
      expect(r.accionesDeLaSemana.length, 3);
    });

    test('semana tranquila: riesgo máximo Bajo', () {
      final dias = [
        for (var i = 0; i < 7; i++) _dia(hoy.add(Duration(days: i))),
      ];
      final r = MotorLocal.resumenSemanal(
        paquete: paquete,
        serie: _serie(dias),
        hoy: hoy,
        cultivoId: 1,
        etapaFenologicaId: 1,
        tipoSueloId: 1,
        fechaSiembra: hoy,
        umbrales: const UmbralesMotor(),
      );
      expect(r.nivelRiesgoMaximo, 'Bajo');
    });
  });
}
