enum MaterielCategory {
  soil('Préparation et travail du sol', 'soil'),
  planting('Semis, plantation et traitement', 'planting'),
  harvest('Récolte, transport et outillage', 'harvest');

  const MaterielCategory(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static MaterielCategory fromDb(String value) =>
      values.firstWhere((category) => category.dbValue == value);
}

/// Physical condition of the equipment.
enum MaterielCondition {
  newItem('Neuf', 'new'),
  good('Bon état', 'good'),
  worn('Usé', 'worn'),
  broken('En panne', 'broken');

  const MaterielCondition(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static MaterielCondition fromDb(String value) =>
      values.firstWhere((condition) => condition.dbValue == value);
}

/// Availability of the equipment.
enum MaterielStatus {
  available('Disponible', 'available'),
  inUse('En utilisation', 'in_use'),
  maintenance('En maintenance', 'maintenance'),
  outOfService('Hors service', 'out_of_service');

  const MaterielStatus(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static MaterielStatus fromDb(String value) =>
      values.firstWhere((status) => status.dbValue == value);
}

class Materiel {
  const Materiel({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.model,
    required this.serialNumber,
    required this.purchaseDate,
    required this.purchasePrice,
    required this.condition,
    required this.status,
    this.imagePath,
  });

  final String id;
  final String name;
  final MaterielCategory category;
  final String brand;
  final String model;
  final String serialNumber;
  final DateTime purchaseDate;

  /// Purchase price in Tunisian dinars (DT).
  final double purchasePrice;
  final MaterielCondition condition;
  final MaterielStatus status;

  /// Local file of the equipment photo, `null` when none was chosen.
  final String? imagePath;

  factory Materiel.fromJson(Map<String, dynamic> json) => Materiel(
    id: json['id'] as String,
    name: json['name'] as String,
    category: MaterielCategory.fromDb(json['category'] as String),
    brand: json['brand'] as String,
    model: json['model'] as String,
    serialNumber: json['serial_number'] as String,
    purchaseDate: DateTime.parse(json['purchase_date'] as String),
    purchasePrice: (json['purchase_price'] as num).toDouble(),
    condition: MaterielCondition.fromDb(json['condition'] as String),
    status: MaterielStatus.fromDb(json['status'] as String),
    imagePath: json['image_path'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.dbValue,
    'brand': brand,
    'model': model,
    'serial_number': serialNumber,
    'purchase_date': purchaseDate.toIso8601String(),
    'purchase_price': purchasePrice,
    'condition': condition.dbValue,
    'status': status.dbValue,
    'image_path': imagePath,
  };
}
