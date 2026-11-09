import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'support/mock_parcel_health_repository.dart';

import 'package:my_application/models/parcel_health.dart';
import 'package:my_application/providers/parcel_health_provider.dart';
import 'package:my_application/services/disease_api_service.dart';

const _parcel = Parcel(
  id: 'tomato-field-a',
  name: 'Field',
  cropType: 'Tomatoes',
  surfaceHectares: 1.98,
  boundary: [
    LatLng(36.6800, 10.5900),
    LatLng(36.6800, 10.5920),
    LatLng(36.6790, 10.5920),
    LatLng(36.6790, 10.5900),
  ],
);

final _apiResponse = {
  'surface_totale_ha': 1.98,
  'resultats': [
    {
      'culture': 'Tomate',
      'maladie': 'Early Blight',
      'nom_fr': 'Alternariose',
      'pourcentage_infection': 15.2,
      'surface_touchee_ha': 0.3,
      'surface_touchee_m2': 3000.0,
      'niveau_risque': 'Élevé',
      'perte_rendement_t': 9.0,
      'perte_rendement_pct': 7.6,
      'traitement': 'Fongicide.',
      'fiabilite': 0.85,
      'zones': [
        {'lat': 36.6795, 'lng': 10.5910, 'rayon_m': 12.0},
        {'lat': 36.6797, 'lng': 10.5905, 'rayon_m': 12.0},
      ],
    },
    {
      'culture': 'Tomate',
      'maladie': 'Late Blight',
      'nom_fr': 'Mildiou',
      'pourcentage_infection': 4.0,
      'surface_touchee_ha': 0.08,
      'surface_touchee_m2': 800.0,
      'niveau_risque': 'Faible',
      'perte_rendement_t': 3.0,
      'perte_rendement_pct': 2.0,
      'traitement': 'Cuivre.',
      'fiabilite': 0.85,
      'zones': [
        {'lat': 36.6793, 'lng': 10.5915, 'rayon_m': 8.0},
      ],
    },
  ],
};

void main() {
  test('converts the API answer into zones and disease markers', () {
    final analysis = analysisFromApi(
      _apiResponse,
      parcel: _parcel,
      missionId: 'm1',
      detectedAt: DateTime(2026),
    );

    // 1 healthy background + 3 infected circles.
    expect(analysis.zones, hasLength(4));
    expect(
      analysis.zones.where((z) => z.status == ZoneStatus.critical),
      hasLength(2),
    );
    expect(analysis.anomalies.map((a) => a.severity), [
      Severity.high,
      Severity.low,
    ]);
    expect(analysis.anomalies.first.position, const LatLng(36.6795, 10.5910));
    expect(analysis.criticalPercent, 15);
    expect(analysis.warningPercent, 4);
    expect(analysis.healthyPercent, 81);
  });

  test('sends the parcel surface and stores the result as a mission', () async {
    late Map<String, dynamic> sent;
    final client = MockClient((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response.bytes(utf8.encode(jsonEncode(_apiResponse)), 200);
    });
    final provider = ParcelHealthProvider(
      MockParcelHealthRepository(),
      diseaseApi: DiseaseApiService(client: client, baseUrl: 'http://api'),
    );
    await provider.load();

    await provider.analyseDiseases(temperature: 22, humidity: 92);

    expect(sent['culture'], 'Tomate');
    expect(sent['polygone'], hasLength(4));
    expect(sent['humidite'], 92);
    expect(provider.selectedMission?.label, 'Disease estimation');
    expect(provider.missions.first.id, provider.selectedMission?.id);
    expect(provider.analysis?.anomalies, hasLength(2));
  });

  test('reports API errors', () async {
    final client = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode({'erreur': 'Unité inconnue'})),
        400,
      ),
    );
    final provider = ParcelHealthProvider(
      MockParcelHealthRepository(),
      diseaseApi: DiseaseApiService(client: client, baseUrl: 'http://api'),
    );
    await provider.load();

    expect(
      provider.analyseDiseases(),
      throwsA(
        isA<DiseaseApiException>().having(
          (e) => e.message,
          'message',
          'Unité inconnue',
        ),
      ),
    );
  });
}
