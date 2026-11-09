/// AI irrigation planning of a parcel: the weather forecast it was based on
/// and the recommendation for each day.
library;

const _frenchDays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

String frenchDayName(DateTime date) => _frenchDays[date.weekday - 1];

String _isoDay(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "2 500 L", or "—" when there is no quantity.
String formatLiters(double? liters) {
  if (liters == null) return '—';
  final digits = liters.round().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return '$out L';
}

enum PlanAction {
  irrigate('Irriguer', 'irriguer'),
  skip('Ne pas irriguer', 'ne_pas_irriguer'),
  check('Vérifier humidité', 'verifier');

  const PlanAction(this.label, this.apiValue);

  final String label;
  final String apiValue;

  /// Tolerant parsing: the AI may write "Irriguer", "ne pas irriguer"…
  static PlanAction fromApi(String value) {
    final v = value.toLowerCase();
    if (v.contains('verif') || v.contains('vérif')) return check;
    if (v.contains('pas') || v.contains('skip') || v.contains('aucun')) {
      return skip;
    }
    return irrigate;
  }
}

/// Forecast of one day at the parcel (Open-Meteo).
class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.rainMm,
    required this.et0Mm,
    this.rainProbability,
  });

  final DateTime date;
  final double tempMax;
  final double tempMin;
  final double rainMm;

  /// Reference evapotranspiration (FAO-56), in mm.
  final double et0Mm;

  /// 0–100.
  final int? rainProbability;

  factory WeatherDay.fromJson(Map<String, dynamic> json) => WeatherDay(
    date: DateTime.parse(json['date'] as String),
    tempMax: (json['t_max'] as num).toDouble(),
    tempMin: (json['t_min'] as num).toDouble(),
    rainMm: (json['pluie_mm'] as num).toDouble(),
    et0Mm: (json['et0_mm'] as num).toDouble(),
    rainProbability: (json['proba_pluie_pct'] as num?)?.round(),
  );

  Map<String, dynamic> toJson() => {
    'date': _isoDay(date),
    't_max': tempMax,
    't_min': tempMin,
    'pluie_mm': rainMm,
    'et0_mm': et0Mm,
    'proba_pluie_pct': rainProbability,
  };
}

/// Fingerprint of the forecast: rounded so tiny API fluctuations do not
/// trigger a new AI call, but a real change (rain, heat) does.
String weatherSignature(List<WeatherDay>? weather) {
  if (weather == null || weather.isEmpty) return 'none';
  return weather
      .map(
        (d) =>
            '${_isoDay(d.date)}:${d.rainMm.round()}:'
            '${(d.et0Mm * 2).round()}:${(d.tempMax / 2).round()}',
      )
      .join('|');
}

/// Fingerprint of the moisture inputs: the farmer's measurement (to 2 %)
/// and the latest recorded irrigation.
String humiditySignature(double? soilHumidity, String? lastRecordId) =>
    '${soilHumidity == null ? '-' : (soilHumidity / 2).round()}'
    '|${lastRecordId ?? '-'}';

class IrrigationPlanDay {
  const IrrigationPlanDay({
    required this.date,
    required this.action,
    required this.liters,
    required this.reason,
    this.expectedHumidity,
  });

  final DateTime date;
  final PlanAction action;

  /// `null` for a check day ("—"), 0 when not irrigating.
  final double? liters;

  /// Soil moisture the AI expects at the end of the day, in %.
  final double? expectedHumidity;
  final String reason;

  String get dayName => frenchDayName(date);

  factory IrrigationPlanDay.fromJson(Map<String, dynamic> json) {
    final action = PlanAction.fromApi(json['action']?.toString() ?? '');
    final liters = (json['quantite_litres'] as num?)?.toDouble();
    return IrrigationPlanDay(
      date: _dayOnly(DateTime.parse(json['date'] as String)),
      action: action,
      liters: switch (action) {
        PlanAction.skip => 0,
        PlanAction.check => liters != null && liters > 0 ? liters : null,
        PlanAction.irrigate => liters ?? 0,
      },
      expectedHumidity: (json['humidite_prevue'] as num?)?.toDouble(),
      reason: json['raison']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'date': _isoDay(date),
    'action': action.apiValue,
    'quantite_litres': liters,
    'humidite_prevue': expectedHumidity,
    'raison': reason,
  };
}

class IrrigationPlan {
  const IrrigationPlan({
    required this.parcelId,
    required this.generatedAt,
    required this.summary,
    required this.days,
    required this.advice,
    required this.weather,
    required this.soilHumidity,
    required this.weatherSignature,
    required this.humiditySignature,
  });

  final String parcelId;
  final DateTime generatedAt;
  final String summary;
  final List<IrrigationPlanDay> days;
  final List<String> advice;

  /// Inputs the plan was computed from.
  final List<WeatherDay> weather;
  final double? soilHumidity;
  final String weatherSignature;
  final String humiditySignature;

  double get totalLiters => days.fold(0, (sum, day) => sum + (day.liters ?? 0));

  int get irrigationDays =>
      days.where((d) => d.action == PlanAction.irrigate).length;

  /// The plan starts before today: it must be recomputed.
  bool isOutdated(DateTime now) =>
      days.isEmpty || days.first.date.isBefore(_dayOnly(now));

  /// Parses the AI answer `{resume, planning, conseils}`.
  factory IrrigationPlan.fromAi(
    Map<String, dynamic> json, {
    required String parcelId,
    required DateTime generatedAt,
    required List<WeatherDay> weather,
    required double? soilHumidity,
    required String weatherSignature,
    required String humiditySignature,
  }) {
    final days = [
      for (final item in json['planning'] as List<dynamic>? ?? const [])
        if (item is Map<String, dynamic> && item['date'] != null)
          IrrigationPlanDay.fromJson(item),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return IrrigationPlan(
      parcelId: parcelId,
      generatedAt: generatedAt,
      summary: json['resume']?.toString() ?? '',
      days: days,
      advice: [
        for (final item in json['conseils'] as List<dynamic>? ?? const [])
          item.toString(),
      ],
      weather: weather,
      soilHumidity: soilHumidity,
      weatherSignature: weatherSignature,
      humiditySignature: humiditySignature,
    );
  }

  factory IrrigationPlan.fromJson(Map<String, dynamic> json) => IrrigationPlan(
    parcelId: json['parcel_id'] as String,
    generatedAt: DateTime.parse(json['generated_at'] as String),
    summary: json['resume'] as String? ?? '',
    days: [
      for (final item in json['planning'] as List<dynamic>)
        IrrigationPlanDay.fromJson(item as Map<String, dynamic>),
    ],
    advice: [
      for (final item in json['conseils'] as List<dynamic>? ?? const [])
        item.toString(),
    ],
    weather: [
      for (final item in json['meteo'] as List<dynamic>? ?? const [])
        WeatherDay.fromJson(item as Map<String, dynamic>),
    ],
    soilHumidity: (json['humidite_sol'] as num?)?.toDouble(),
    weatherSignature: json['weather_signature'] as String? ?? '',
    humiditySignature: json['humidity_signature'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'parcel_id': parcelId,
    'generated_at': generatedAt.toIso8601String(),
    'resume': summary,
    'planning': [for (final d in days) d.toJson()],
    'conseils': advice,
    'meteo': [for (final w in weather) w.toJson()],
    'humidite_sol': soilHumidity,
    'weather_signature': weatherSignature,
    'humidity_signature': humiditySignature,
  };
}
