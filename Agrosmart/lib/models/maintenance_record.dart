/// The three kinds of entry tracked for each equipment.
enum MaintenanceRecordType {
  fuel('Carburant', 'fuel'),
  maintenance('Maintenance', 'maintenance'),
  labor("Main d'œuvre", 'labor');

  const MaintenanceRecordType(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static MaintenanceRecordType fromDb(String value) =>
      values.firstWhere((type) => type.dbValue == value);
}

/// One dated entry of an equipment: a fuel fill, a maintenance operation or
/// labour (main d'œuvre). An equipment has many entries of each type.
class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.materielId,
    required this.type,
    required this.date,
    required this.cost,
    this.description = '',
    this.quantity,
    this.workerName,
  });

  final String id;
  final String materielId;
  final MaintenanceRecordType type;
  final DateTime date;

  /// Cost in Tunisian dinars (DT).
  final double cost;

  /// Fuel kind, operation done, or work done.
  final String description;

  /// Litres for fuel, hours for labour, `null` for maintenance.
  final double? quantity;

  /// Worker or provider name (labour and maintenance).
  final String? workerName;

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) =>
      MaintenanceRecord(
        id: json['id'] as String,
        materielId: json['materiel_id'] as String,
        type: MaintenanceRecordType.fromDb(json['type'] as String),
        date: DateTime.parse(json['record_date'] as String),
        cost: (json['cost'] as num).toDouble(),
        description: json['description'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble(),
        workerName: json['worker_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'materiel_id': materielId,
    'type': type.dbValue,
    'record_date': date.toIso8601String(),
    'cost': cost,
    'description': description,
    'quantity': quantity,
    'worker_name': workerName,
  };
}
