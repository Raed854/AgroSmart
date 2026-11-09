/// Where the irrigation water comes from.
enum WaterSource {
  well('Puits', 'well'),
  borehole('Forage', 'borehole'),
  dam('Barrage', 'dam'),
  basin('Bassin', 'basin'),
  network('Réseau public', 'network'),
  river('Oued / rivière', 'river');

  const WaterSource(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static WaterSource fromDb(String value) =>
      values.firstWhere((source) => source.dbValue == value);
}

/// How the water is delivered to the parcel.
enum IrrigationMethod {
  drip('Goutte à goutte', 'drip'),
  sprinkler('Aspersion', 'sprinkler'),
  pivot('Pivot', 'pivot'),
  gravity('Gravitaire', 'gravity'),
  manual('Manuelle', 'manual');

  const IrrigationMethod(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static IrrigationMethod fromDb(String value) =>
      values.firstWhere((method) => method.dbValue == value);
}

/// One irrigation of a parcel.
class IrrigationRecord {
  const IrrigationRecord({
    required this.id,
    required this.parcelId,
    required this.date,
    required this.startMinutes,
    required this.waterSource,
    required this.durationMinutes,
    required this.method,
    this.humidityBefore,
    this.humidityAfter,
    this.electricityKwh,
    required this.cost,
    this.photoPath,
  });

  final String id;
  final String parcelId;

  /// Day of the irrigation (time part ignored).
  final DateTime date;

  /// Start time, in minutes since midnight.
  final int startMinutes;

  final WaterSource waterSource;
  final int durationMinutes;
  final IrrigationMethod method;

  /// Soil humidity in %, before and after the irrigation.
  final double? humidityBefore;
  final double? humidityAfter;

  /// Electricity consumed by the pump, in kWh.
  final double? electricityKwh;

  /// Cost in Tunisian dinars (DT).
  final double cost;

  /// Local path of the photo of the intervention.
  final String? photoPath;

  factory IrrigationRecord.fromJson(Map<String, dynamic> json) =>
      IrrigationRecord(
        id: json['id'] as String,
        parcelId: json['parcel_id'] as String,
        date: DateTime.parse(json['irrigation_date'] as String),
        startMinutes: json['start_minutes'] as int,
        waterSource: WaterSource.fromDb(json['water_source'] as String),
        durationMinutes: json['duration_minutes'] as int,
        method: IrrigationMethod.fromDb(json['method'] as String),
        humidityBefore: (json['humidity_before'] as num?)?.toDouble(),
        humidityAfter: (json['humidity_after'] as num?)?.toDouble(),
        electricityKwh: (json['electricity_kwh'] as num?)?.toDouble(),
        cost: (json['cost'] as num).toDouble(),
        photoPath: json['photo_path'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'parcel_id': parcelId,
    'irrigation_date': date.toIso8601String(),
    'start_minutes': startMinutes,
    'water_source': waterSource.dbValue,
    'duration_minutes': durationMinutes,
    'method': method.dbValue,
    'humidity_before': humidityBefore,
    'humidity_after': humidityAfter,
    'electricity_kwh': electricityKwh,
    'cost': cost,
    'photo_path': photoPath,
  };
}
