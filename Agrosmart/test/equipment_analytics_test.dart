import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_application/models/maintenance_record.dart';
import 'package:my_application/models/materiel.dart';
import 'package:my_application/services/ai_analytics_service.dart';
import 'package:my_application/services/equipment_analytics.dart';

Materiel _materiel({
  String id = 'm1',
  MaterielCondition condition = MaterielCondition.good,
  DateTime? purchase,
}) => Materiel(
  id: id,
  name: 'Tracteur $id',
  category: MaterielCategory.harvest,
  brand: 'Brand',
  model: 'X',
  serialNumber: 'S',
  purchaseDate: purchase ?? DateTime(2022, 1, 1),
  purchasePrice: 100000,
  condition: condition,
  status: MaterielStatus.available,
);

MaintenanceRecord _record(
  String id,
  MaintenanceRecordType type,
  DateTime date, {
  double cost = 100,
  double? quantity,
  String materielId = 'm1',
}) => MaintenanceRecord(
  id: id,
  materielId: materielId,
  type: type,
  date: date,
  cost: cost,
  quantity: quantity,
);

void main() {
  final now = DateTime(2026, 11, 9);

  test('sums fuel and groups it by month', () {
    final a = FleetAnalytics.compute(
      [_materiel()],
      [
        _record(
          'f1',
          MaintenanceRecordType.fuel,
          DateTime(2026, 10, 3),
          cost: 200,
          quantity: 100,
        ),
        _record(
          'f2',
          MaintenanceRecordType.fuel,
          DateTime(2026, 11, 2),
          cost: 100,
          quantity: 50,
        ),
      ],
      now: now,
    );
    expect(a.totalLitres, 150);
    expect(a.totalFuelCost, 300);
    expect(a.monthlyFuel, hasLength(12));
    expect(a.monthlyFuel.last.litres, 50);
    expect(a.monthlyFuel[10].litres, 100);
    expect(a.equipments.single.pricePerLitre, 2);
  });

  test('predicts next maintenance from the history interval', () {
    final a = FleetAnalytics.compute(
      [_materiel()],
      [
        _record('m1', MaintenanceRecordType.maintenance, DateTime(2026, 3, 1)),
        _record('m2', MaintenanceRecordType.maintenance, DateTime(2026, 6, 1)),
        _record('m3', MaintenanceRecordType.maintenance, DateTime(2026, 9, 1)),
      ],
      now: now,
    );
    final e = a.equipments.single;
    expect(e.intervalFromHistory, isTrue);
    expect(e.maintenanceIntervalDays, 92);
    expect(e.nextMaintenance, DateTime(2026, 12, 2));
    expect(e.urgency, MaintenanceUrgency.soon);
  });

  test('broken equipment is overdue and has a shorter life', () {
    final a = FleetAnalytics.compute(
      [
        _materiel(id: 'ok'),
        _materiel(id: 'ko', condition: MaterielCondition.broken),
      ],
      const [],
      now: now,
    );
    final ok = a.equipments.first;
    final ko = a.equipments.last;
    expect(ko.urgency, MaintenanceUrgency.overdue);
    expect(ko.expectedLifeYears, lessThan(ok.expectedLifeYears));
    expect(ok.remainingLifeYears, closeTo(ok.expectedLifeYears - 4.85, .05));
  });

  test('AI service parses the Gemini JSON answer', () async {
    final client = MockClient((request) async {
      expect(request.headers['x-goog-api-key'], 'test-key');
      expect(request.url.host, 'generativelanguage.googleapis.com');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'resume': 'Parc en bon état.',
                        'consommation': ['Stable'],
                        'maintenances': [
                          {
                            'materiel': 'Tracteur m1',
                            'date_prevue': '2026-12-01',
                            'priorite': 'haute',
                            'raison': 'Vidange',
                          },
                        ],
                        'duree_vie': [
                          {
                            'materiel': 'Tracteur m1',
                            'annees_restantes': 8,
                            'commentaire': 'OK',
                          },
                        ],
                        'recommandations': ['Contrôler les filtres'],
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
    });
    final report = await AiAnalyticsService(
      client: client,
      apiKey: 'test-key',
    ).analyse(FleetAnalytics.compute([_materiel()], const [], now: now));
    expect(report.summary, 'Parc en bon état.');
    expect(report.maintenances.single.date, DateTime(2026, 12, 1));
    expect(report.lifespans.single.remainingYears, 8);
  });

  test('AI service reports a missing key', () {
    expect(
      AiAnalyticsService(apiKey: '')
          .analyse(FleetAnalytics.compute(const [], const [], now: now)),
      throwsA(isA<AiAnalyticsException>()),
    );
  });
}
