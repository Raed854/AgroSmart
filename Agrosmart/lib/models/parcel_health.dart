import 'package:latlong2/latlong.dart';

/// Domain models for the Parcel Health Map.
///
/// Each model exposes a `fromJson` factory so the mock repository can later be
/// swapped for a FastAPI-backed one without touching the UI.

enum AnomalyType {
  disease('Disease', 'disease'),
  waterStress('Water Stress', 'water_stress'),
  weed('Weed Detection', 'weed'),
  growth('Growth Problems', 'growth');

  const AnomalyType(this.label, this.apiValue);

  final String label;
  final String apiValue;

  static AnomalyType fromApi(String value) =>
      values.firstWhere((type) => type.apiValue == value);
}

enum Severity {
  low('Low', 'low'),
  medium('Medium', 'medium'),
  high('High', 'high'),
  critical('Critical', 'critical');

  const Severity(this.label, this.apiValue);

  final String label;
  final String apiValue;

  static Severity fromApi(String value) =>
      values.firstWhere((severity) => severity.apiValue == value);
}

enum ZoneStatus {
  healthy('healthy'),
  warning('warning'),
  critical('critical');

  const ZoneStatus(this.apiValue);

  final String apiValue;

  static ZoneStatus fromApi(String value) =>
      values.firstWhere((status) => status.apiValue == value);
}

List<LatLng> _pointsFromJson(List<dynamic> json) => json
    .map(
      (point) => LatLng(
        ((point as List<dynamic>)[0] as num).toDouble(),
        (point[1] as num).toDouble(),
      ),
    )
    .toList();

List<List<double>> _pointsToJson(List<LatLng> points) => [
  for (final p in points) [p.latitude, p.longitude],
];

class Parcel {
  const Parcel({
    required this.id,
    required this.name,
    required this.cropType,
    required this.surfaceHectares,
    required this.boundary,
  });

  final String id;
  final String name;
  final String cropType;
  final double surfaceHectares;
  final List<LatLng> boundary;

  factory Parcel.fromJson(Map<String, dynamic> json) => Parcel(
    id: json['id'] as String,
    name: json['name'] as String,
    cropType: json['crop_type'] as String,
    surfaceHectares: (json['surface_ha'] as num).toDouble(),
    boundary: _pointsFromJson(json['boundary'] as List<dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'crop_type': cropType,
    'surface_ha': surfaceHectares,
    'boundary': _pointsToJson(boundary),
  };
}

class DroneMission {
  const DroneMission({
    required this.id,
    required this.parcelId,
    required this.label,
    required this.flownAt,
  });

  final String id;
  final String parcelId;
  final String label;
  final DateTime flownAt;

  factory DroneMission.fromJson(Map<String, dynamic> json) => DroneMission(
    id: json['id'] as String,
    parcelId: json['parcel_id'] as String,
    label: json['label'] as String,
    flownAt: DateTime.parse(json['flown_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'parcel_id': parcelId,
    'label': label,
    'flown_at': flownAt.toIso8601String(),
  };
}

class HealthZone {
  const HealthZone({required this.status, required this.points});

  final ZoneStatus status;
  final List<LatLng> points;

  factory HealthZone.fromJson(Map<String, dynamic> json) => HealthZone(
    status: ZoneStatus.fromApi(json['status'] as String),
    points: _pointsFromJson(json['points'] as List<dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'status': status.apiValue,
    'points': _pointsToJson(points),
  };
}

class Anomaly {
  const Anomaly({
    required this.id,
    required this.name,
    required this.type,
    required this.severity,
    required this.confidence,
    required this.position,
    required this.detectedAt,
    required this.description,
    required this.recommendation,
  });

  final String id;
  final String name;
  final AnomalyType type;
  final Severity severity;

  /// AI model confidence between 0 and 1.
  final double confidence;
  final LatLng position;
  final DateTime detectedAt;
  final String description;
  final String recommendation;

  factory Anomaly.fromJson(Map<String, dynamic> json) => Anomaly(
    id: json['id'] as String,
    name: json['name'] as String,
    type: AnomalyType.fromApi(json['type'] as String),
    severity: Severity.fromApi(json['severity'] as String),
    confidence: (json['confidence'] as num).toDouble(),
    position: LatLng(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    ),
    detectedAt: DateTime.parse(json['detected_at'] as String),
    description: json['description'] as String,
    recommendation: json['recommendation'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.apiValue,
    'severity': severity.apiValue,
    'confidence': confidence,
    'lat': position.latitude,
    'lng': position.longitude,
    'detected_at': detectedAt.toIso8601String(),
    'description': description,
    'recommendation': recommendation,
  };
}

/// AI analysis result of one drone mission over one parcel.
class MissionAnalysis {
  const MissionAnalysis({
    required this.missionId,
    required this.overallHealth,
    required this.healthyPercent,
    required this.warningPercent,
    required this.criticalPercent,
    required this.zones,
    required this.anomalies,
  });

  final String missionId;
  final int overallHealth;
  final int healthyPercent;
  final int warningPercent;
  final int criticalPercent;
  final List<HealthZone> zones;
  final List<Anomaly> anomalies;

  factory MissionAnalysis.fromJson(Map<String, dynamic> json) =>
      MissionAnalysis(
        missionId: json['mission_id'] as String,
        overallHealth: json['overall_health'] as int,
        healthyPercent: json['healthy_percent'] as int,
        warningPercent: json['warning_percent'] as int,
        criticalPercent: json['critical_percent'] as int,
        zones: (json['zones'] as List<dynamic>)
            .map((zone) => HealthZone.fromJson(zone as Map<String, dynamic>))
            .toList(),
        anomalies: (json['anomalies'] as List<dynamic>)
            .map((item) => Anomaly.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
