import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../network/network_exception.dart';

/// Un día de pronóstico u observación.
class DiaClima {
  final DateTime fecha;
  final double? temperaturaMax;
  final double? temperaturaMin;
  final double? precipitacion;
  final double? vientoVelocidad;
  final double? humedadRelativa;

  const DiaClima({
    required this.fecha,
    this.temperaturaMax,
    this.temperaturaMin,
    this.precipitacion,
    this.vientoVelocidad,
    this.humedadRelativa,
  });

  factory DiaClima.fromJson(Map<String, dynamic> json) => DiaClima(
    fecha: DateTime.parse(json['fecha'] as String),
    temperaturaMax: (json['tmax'] as num?)?.toDouble(),
    temperaturaMin: (json['tmin'] as num?)?.toDouble(),
    precipitacion: (json['pp'] as num?)?.toDouble(),
    vientoVelocidad: (json['viento'] as num?)?.toDouble(),
    humedadRelativa: (json['hum'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'fecha': fecha.toIso8601String(),
    'tmax': temperaturaMax,
    'tmin': temperaturaMin,
    'pp': precipitacion,
    'viento': vientoVelocidad,
    'hum': humedadRelativa,
  };
}

/// Serie diaria continua: días pasados + hoy + pronóstico.
class SerieClima {
  final List<DiaClima> dias;
  final DateTime descargadaEn;
  final int diasPasados;
  final bool desdeCache;

  const SerieClima({
    required this.dias,
    required this.descargadaEn,
    required this.diasPasados,
    this.desdeCache = false,
  });

  SerieClima comoCache() => SerieClima(
    dias: dias,
    descargadaEn: descargadaEn,
    diasPasados: diasPasados,
    desdeCache: true,
  );

  /// Índice del día [hoy] (solo fecha) en la serie, o null si la serie no lo cubre.
  int? indiceDe(DateTime hoy) {
    for (var i = 0; i < dias.length; i++) {
      final d = dias[i].fecha;
      if (d.year == hoy.year && d.month == hoy.month && d.day == hoy.day) {
        return i;
      }
    }
    return null;
  }
}

/// Cliente directo de Open-Meteo (api.open-meteo.com).
///
/// Términos de la API gratuita: uso no comercial, atribución CC BY 4.0 y cuota
/// diaria por IP. Cada teléfono consulta directamente y usa su propia cuota.
/// Si CosechaClima pasa a uso comercial hay que contratar el plan de pago de
/// Open-Meteo.
class OpenMeteoClient {
  static const atribucion = 'Datos meteorológicos: Open-Meteo.com (CC BY 4.0)';
  static const _host = 'api.open-meteo.com';
  static const _zonaHoraria = 'America/Managua';

  // Open-Meteo admite hasta 92 días pasados y 16 de pronóstico.
  static const maxDiasPasados = 92;
  static const maxDiasPronostico = 16;

  final http.Client _client;
  final Duration timeout;

  OpenMeteoClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  Future<SerieClima> obtener({
    required double latitud,
    required double longitud,
    required int diasPasados,
    required int diasPronostico,
  }) async {
    final uri = Uri.https(_host, '/v1/forecast', {
      'latitude': latitud.toStringAsFixed(4),
      'longitude': longitud.toStringAsFixed(4),
      'daily':
          'temperature_2m_max,temperature_2m_min,precipitation_sum,'
          'wind_speed_10m_max,relative_humidity_2m_mean',
      'timezone': _zonaHoraria,
      'past_days': diasPasados.clamp(0, maxDiasPasados).toString(),
      'forecast_days': diasPronostico.clamp(1, maxDiasPronostico).toString(),
    });

    final http.Response respuesta;
    try {
      respuesta = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const NetworkTimeoutException();
    } on SocketException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }

    if (respuesta.statusCode == 429) {
      throw const NetworkException(
        'El servicio de clima está recibiendo muchas consultas. Probá en unos minutos.',
      );
    }
    if (respuesta.statusCode != 200) {
      throw const NetworkException(
        'El servicio de clima no está disponible por ahora.',
      );
    }

    try {
      return _parsear(
        jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>,
        diasPasados,
      );
    } on FormatException {
      throw const NetworkException('Respuesta inválida del servicio de clima.');
    } on TypeError {
      throw const NetworkException('Respuesta inválida del servicio de clima.');
    }
  }

  SerieClima _parsear(Map<String, dynamic> json, int diasPasados) {
    final diario = json['daily'] as Map<String, dynamic>;
    final tiempos = (diario['time'] as List<dynamic>).cast<String>();
    if (tiempos.isEmpty) {
      throw const FormatException('Sin datos diarios');
    }

    double? valor(String clave, int i) {
      final lista = diario[clave] as List<dynamic>?;
      if (lista == null || i >= lista.length) return null;
      return (lista[i] as num?)?.toDouble();
    }

    return SerieClima(
      diasPasados: diasPasados,
      descargadaEn: DateTime.now(),
      dias: [
        for (var i = 0; i < tiempos.length; i++)
          DiaClima(
            fecha: DateTime.parse(tiempos[i]),
            temperaturaMax: valor('temperature_2m_max', i),
            temperaturaMin: valor('temperature_2m_min', i),
            precipitacion: valor('precipitation_sum', i),
            vientoVelocidad: valor('wind_speed_10m_max', i),
            humedadRelativa: valor('relative_humidity_2m_mean', i),
          ),
      ],
    );
  }
}
