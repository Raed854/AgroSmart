import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/irrigation_plan.dart';
import '../utils/network_error.dart';

class WeatherException implements Exception {
  const WeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Daily forecast from Open-Meteo (free, no API key).
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _daily = [
    'temperature_2m_max',
    'temperature_2m_min',
    'precipitation_sum',
    'precipitation_probability_max',
    'et0_fao_evapotranspiration',
  ];

  Future<List<WeatherDay>> forecast(LatLng position, {int days = 7}) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': position.latitude.toStringAsFixed(4),
      'longitude': position.longitude.toStringAsFixed(4),
      'daily': _daily.join(','),
      'timezone': 'auto',
      'forecast_days': '$days',
    });
    http.Response? response;
    Object? lastError;
    // One retry: mobile networks often drop the first request.
    for (var attempt = 0; attempt < 2 && response == null; attempt++) {
      try {
        response = await _client.get(uri).timeout(const Duration(seconds: 20));
      } catch (e) {
        lastError = e;
      }
    }
    if (response == null) {
      throw WeatherException(
        'Prévisions météo indisponibles '
        '(${describeNetworkError(lastError!)}).',
      );
    }
    if (response.statusCode != 200) {
      throw WeatherException(
        'Prévisions météo indisponibles (${response.statusCode}).',
      );
    }
    try {
      final daily =
          (jsonDecode(response.body) as Map<String, dynamic>)['daily']
              as Map<String, dynamic>;
      final dates = daily['time'] as List<dynamic>;
      double at(String key, int i) =>
          ((daily[key] as List<dynamic>?)?[i] as num?)?.toDouble() ?? 0;
      return [
        for (var i = 0; i < dates.length; i++)
          WeatherDay(
            date: DateTime.parse(dates[i] as String),
            tempMax: at('temperature_2m_max', i),
            tempMin: at('temperature_2m_min', i),
            rainMm: at('precipitation_sum', i),
            et0Mm: at('et0_fao_evapotranspiration', i),
            rainProbability:
                ((daily['precipitation_probability_max'] as List<dynamic>?)?[i]
                        as num?)
                    ?.round(),
          ),
      ];
    } catch (_) {
      throw const WeatherException('Réponse météo illisible.');
    }
  }
}
