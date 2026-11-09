import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/parcel_health.dart';
import '../utils/geo_utils.dart';

/// Base URL of the disease estimation API (`Nouveau dossier/app.py`).
///
/// `10.0.2.2` is the PC as seen from the Android emulator. On a real phone,
/// run with `--dart-define=DISEASE_API_URL=http://<PC IP>:5000`.
const diseaseApiUrl = String.fromEnvironment(
  'DISEASE_API_URL',
  defaultValue: 'http://10.0.2.2:5000',
);

class DiseaseApiException implements Exception {
  const DiseaseApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sends a parcel's surface to the disease API and turns the answer into a
/// [MissionAnalysis] the health map can draw.
class DiseaseApiService {
  DiseaseApiService({http.Client? client, this.baseUrl = diseaseApiUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<MissionAnalysis> analyse(
    Parcel parcel, {
    required String missionId,
    double? temperature,
    double? humidity,
  }) async {
    final culture = apiCulture(parcel.cropType);
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/api/estimation'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'surface': parcel.surfaceHectares,
              'unite': 'ha',
              'polygone': [
                for (final p in parcel.boundary) [p.latitude, p.longitude],
              ],
              'culture': ?culture,
              'temperature': ?temperature,
              'humidite': ?humidity,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw DiseaseApiException(
        'Cannot reach the disease API at $baseUrl. Is app.py running?',
      );
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      throw DiseaseApiException(
        (body is Map ? body['erreur'] as String? : null) ??
            'Disease API error (${response.statusCode}).',
      );
    }
    return analysisFromApi(
      body as Map<String, dynamic>,
      parcel: parcel,
      missionId: missionId,
      detectedAt: DateTime.now(),
    );
  }
}

/// Maps the app's crop name to the API's crop, or `null` to estimate every
/// disease the API knows.
String? apiCulture(String cropType) {
  final crop = cropType.toLowerCase();
  if (crop.contains('tomat')) return 'Tomate';
  if (crop.contains('potato') || crop.contains('pomme de terre')) {
    return 'Pomme de terre';
  }
  if (crop.contains('pepper') || crop.contains('poivron')) return 'Poivron';
  return null;
}

Severity _severity(String niveau) => switch (niveau) {
  'Faible' => Severity.low,
  'Moyen' => Severity.medium,
  'Élevé' => Severity.high,
  _ => Severity.critical,
};

/// A circle drawn as a polygon, for the map's zone layer.
List<LatLng> circlePoints(
  LatLng centre,
  double radiusMeters, {
  int sides = 24,
}) {
  const earthRadius = 6371008.8;
  final dLat = radiusMeters / earthRadius * 180 / math.pi;
  final dLng = dLat / math.cos(centre.latitudeInRad);
  return [
    for (var i = 0; i < sides; i++)
      LatLng(
        centre.latitude + dLat * math.sin(2 * math.pi * i / sides),
        centre.longitude + dLng * math.cos(2 * math.pi * i / sides),
      ),
  ];
}

/// Converts a `POST /api/estimation` response into a [MissionAnalysis].
MissionAnalysis analysisFromApi(
  Map<String, dynamic> json, {
  required Parcel parcel,
  required String missionId,
  required DateTime detectedAt,
}) {
  final results = (json['resultats'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final zones = <HealthZone>[
    HealthZone(status: ZoneStatus.healthy, points: parcel.boundary),
  ];
  final anomalies = <Anomaly>[];
  var warning = 0.0;
  var critical = 0.0;

  for (var i = 0; i < results.length; i++) {
    final r = results[i];
    final severity = _severity(r['niveau_risque'] as String);
    final isCritical =
        severity == Severity.high || severity == Severity.critical;
    final percent = (r['pourcentage_infection'] as num).toDouble();
    if (isCritical) {
      critical += percent;
    } else {
      warning += percent;
    }

    final spots = (r['zones'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final spot in spots) {
      zones.add(
        HealthZone(
          status: isCritical ? ZoneStatus.critical : ZoneStatus.warning,
          points: circlePoints(
            LatLng(
              (spot['lat'] as num).toDouble(),
              (spot['lng'] as num).toDouble(),
            ),
            (spot['rayon_m'] as num).toDouble(),
          ),
        ),
      );
    }

    final position = spots.isEmpty
        ? polygonCentroid(parcel.boundary)
        : LatLng(
            (spots.first['lat'] as num).toDouble(),
            (spots.first['lng'] as num).toDouble(),
          );
    anomalies.add(
      Anomaly(
        id: '$missionId-$i',
        name: '${r['nom_fr']} (${r['maladie']})',
        type: AnomalyType.disease,
        severity: severity,
        confidence: (r['fiabilite'] as num?)?.toDouble() ?? .55,
        position: position,
        detectedAt: detectedAt,
        description:
            '${r['culture']} · ${percent.toStringAsFixed(1)} % of the '
            'parcel infected (${r['surface_touchee_m2']} m², '
            '${r['surface_touchee_ha']} ha) in ${spots.length} zone(s). '
            'Risk: ${r['niveau_risque']}. Estimated yield loss: '
            '${r['perte_rendement_t']} t (${r['perte_rendement_pct']} %).',
        recommendation: r['traitement'] as String,
      ),
    );
  }

  final criticalPercent = critical.clamp(0, 100).round();
  final warningPercent = warning.clamp(0, 100 - criticalPercent).round();
  final healthyPercent = 100 - criticalPercent - warningPercent;
  return MissionAnalysis(
    missionId: missionId,
    overallHealth: healthyPercent,
    healthyPercent: healthyPercent,
    warningPercent: warningPercent,
    criticalPercent: criticalPercent,
    zones: zones,
    anomalies: anomalies,
  );
}
