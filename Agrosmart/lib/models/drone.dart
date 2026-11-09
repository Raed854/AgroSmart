enum DroneType {
  multispectral('Multispectral', 'multispectral'),
  thermal('Drone thermique', 'thermal'),
  spraying('Drone de pulvérisation', 'spraying'),
  mapping('Cartographie', 'mapping');

  const DroneType(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static DroneType fromDb(String value) =>
      values.firstWhere((type) => type.dbValue == value);
}

enum DroneStatus {
  active('Actif', 'active'),
  maintenance('Maintenance', 'maintenance'),
  outOfService('Hors service', 'out_of_service');

  const DroneStatus(this.label, this.dbValue);

  final String label;
  final String dbValue;

  static DroneStatus fromDb(String value) =>
      values.firstWhere((status) => status.dbValue == value);
}

class Drone {
  const Drone({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.type,
    required this.status,
    this.imagePath,
  });

  final String id;
  final String name;
  final String brand;
  final String model;
  final DroneType type;
  final DroneStatus status;

  /// Local file of the drone photo, `null` when none was chosen.
  final String? imagePath;

  factory Drone.fromJson(Map<String, dynamic> json) => Drone(
    id: json['id'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String,
    model: json['model'] as String,
    type: DroneType.fromDb(json['type'] as String),
    status: DroneStatus.fromDb(json['status'] as String),
    imagePath: json['image_path'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'model': model,
    'type': type.dbValue,
    'status': status.dbValue,
    'image_path': imagePath,
  };
}
