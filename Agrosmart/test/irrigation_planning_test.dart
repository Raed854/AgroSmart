import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_application/models/irrigation_plan.dart';
import 'package:my_application/models/irrigation_record.dart';
import 'package:my_application/models/parcel_health.dart';
import 'package:my_application/screens/irrigation_planning_screen.dart';
import 'package:my_application/services/irrigation_plan_repository.dart';
import 'package:my_application/services/irrigation_planner_service.dart';
import 'package:my_application/services/irrigation_repository.dart';
import 'package:my_application/services/weather_service.dart';

const _parcel = Parcel(
  id: 'p1',
  name: 'Oliviers Nord',
  cropType: 'Olive',
  surfaceHectares: 1.5,
  boundary: [LatLng(36.8, 10.1), LatLng(36.81, 10.1), LatLng(36.81, 10.11)],
);

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);

String _iso(int offset) {
  final d = _today.add(Duration(days: offset));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

http.Response _weatherResponse({double rainDay1 = 0}) => http.Response(
  jsonEncode({
    'daily': {
      'time': [for (var i = 0; i < 5; i++) _iso(i)],
      'temperature_2m_max': [24, 25, 22, 26, 27],
      'temperature_2m_min': [12, 13, 11, 14, 15],
      'precipitation_sum': [0, rainDay1, 0, 0, 0],
      'precipitation_probability_max': [5, 80, 10, 0, 0],
      'et0_fao_evapotranspiration': [3.1, 1.2, 2.8, 3.5, 3.6],
    },
  }),
  200,
);

http.Response _aiResponse() => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text': jsonEncode({
                  'resume': 'Pluie mardi, irrigation lundi et jeudi.',
                  'planning': [
                    {
                      'date': _iso(0),
                      'action': 'irriguer',
                      'quantite_litres': 2500,
                      'humidite_prevue': 45,
                      'raison': 'Sol sec',
                    },
                    {
                      'date': _iso(1),
                      'action': 'ne_pas_irriguer',
                      'quantite_litres': 0,
                      'humidite_prevue': 50,
                      'raison': 'Pluie',
                    },
                    {
                      'date': _iso(2),
                      'action': 'verifier',
                      'quantite_litres': null,
                      'humidite_prevue': 44,
                      'raison': 'Contrôler',
                    },
                    {
                      'date': _iso(3),
                      'action': 'Irriguer',
                      'quantite_litres': 2000,
                      'humidite_prevue': 46,
                      'raison': 'ET0 élevée',
                    },
                    {
                      'date': _iso(4),
                      'action': 'Ne pas irriguer',
                      'quantite_litres': 0,
                      'humidite_prevue': 41,
                      'raison': 'Réserve suffisante',
                    },
                  ],
                  'conseils': ['Irriguer tôt le matin'],
                }),
              },
            ],
          },
        },
      ],
    }),
  ),
  200,
);

class _FakeRecords implements IrrigationRepository {
  _FakeRecords(this.records);

  final List<IrrigationRecord> records;

  @override
  Future<List<IrrigationRecord>> fetchRecords(String parcelId) async => records;

  @override
  Future<Map<String, int>> countRecords() async => {};

  @override
  Future<void> saveRecord(IrrigationRecord record) async {}

  @override
  Future<void> deleteRecord(IrrigationRecord record) async {}
}

void main() {
  test('formats liters like the planning table', () {
    expect(formatLiters(2500), '2 500 L');
    expect(formatLiters(0), '0 L');
    expect(formatLiters(null), '—');
    expect(frenchDayName(DateTime(2026, 11, 9)), 'Lundi');
  });

  test('weather signature ignores noise but catches real changes', () {
    WeatherDay day(double rain, double et0) => WeatherDay(
      date: _today,
      tempMax: 25,
      tempMin: 12,
      rainMm: rain,
      et0Mm: et0,
    );
    expect(
      weatherSignature([day(0.1, 3.1)]),
      weatherSignature([day(0.3, 3.15)]),
    );
    expect(
      weatherSignature([day(0, 3.1)]) == weatherSignature([day(8, 3.1)]),
      isFalse,
    );
    expect(humiditySignature(30, 'r1') == humiditySignature(45, 'r1'), isFalse);
  });

  test('parses the forecast and the AI planning', () async {
    late Map<String, dynamic> sent;
    final client = MockClient((request) async {
      if (request.url.host == 'api.open-meteo.com') {
        return _weatherResponse(rainDay1: 9);
      }
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return _aiResponse();
    });
    final weather = await WeatherService(client: client)
        .forecast(const LatLng(36.8, 10.1));
    expect(weather, hasLength(5));
    expect(weather[1].rainMm, 9);
    expect(weather[1].rainProbability, 80);

    final plan = await IrrigationPlannerService(client: client, apiKey: 'test')
        .generate(
          parcel: _parcel,
          history: const [],
          weather: weather,
          soilHumidity: 30,
          weatherSignature: weatherSignature(weather),
          humiditySignature: humiditySignature(30, null),
          now: _today,
        );

    final user = jsonDecode(
      ((sent['contents'] as List).first['parts'] as List).first['text']
          as String,
    );
    expect(user['humidite_sol_mesuree_pct'], 30);
    expect((user['previsions_meteo'] as List)[1]['pluie_mm'], 9);

    expect(plan.days.map((d) => d.action), [
      PlanAction.irrigate,
      PlanAction.skip,
      PlanAction.check,
      PlanAction.irrigate,
      PlanAction.skip,
    ]);
    expect(plan.days[2].liters, isNull);
    expect(plan.totalLiters, 4500);
    expect(plan.irrigationDays, 2);

    final restored = IrrigationPlan.fromJson(
      jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>,
    );
    expect(restored.totalLiters, 4500);
    expect(restored.weatherSignature, plan.weatherSignature);
  });

  test('reports a missing Gemini key', () async {
    expect(
      () => IrrigationPlannerService(apiKey: '').generate(
        parcel: _parcel,
        history: const [],
        weather: const [],
        soilHumidity: null,
        weatherSignature: 'none',
        humiditySignature: '-|-',
      ),
      throwsA(isA<IrrigationPlannerException>()),
    );
  });

  testWidgets('regenerates only when the forecast changes', (tester) async {
    var rain = 0.0;
    var aiCalls = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'api.open-meteo.com') {
        return _weatherResponse(rainDay1: rain);
      }
      aiCalls++;
      return _aiResponse();
    });
    final plans = InMemoryIrrigationPlanRepository();
    Widget screen() => MaterialApp(
      home: ParcelIrrigationPlanScreen(
        parcel: _parcel,
        irrigationRepository: _FakeRecords(const []),
        planRepository: plans,
        planner: IrrigationPlannerService(client: client, apiKey: 'test'),
        weather: WeatherService(client: client),
      ),
    );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(aiCalls, 1);
    expect(find.text(frenchDayName(_today)), findsOneWidget);
    expect(find.text('Vérifier humidité'), findsOneWidget);
    expect(find.text('2 500 L'), findsOneWidget);

    // Same forecast: the saved planning is reused.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(aiCalls, 1);

    // Rain announced: the AI recomputes.
    rain = 12;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(aiCalls, 2);
    expect(find.textContaining('prévisions météo ont changé'), findsOneWidget);
  });
}
