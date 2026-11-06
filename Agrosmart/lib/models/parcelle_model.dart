class ParcelleModel {
  const ParcelleModel({
    required this.id,
    required this.nom,
    required this.surface,
    required this.latitude,
    required this.longitude,
    required this.typeSol,
    this.archivee = false,
    required this.createdAt,
  });

  final String id;
  final String nom;
  final double surface; // Hectares
  final double latitude;
  final double longitude;
  final String typeSol;
  final bool archivee;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'surface': surface,
        'latitude': latitude,
        'longitude': longitude,
        'type_sol': typeSol,
        'archivee': archivee ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory ParcelleModel.fromJson(Map<String, dynamic> json) => ParcelleModel(
        id: json['id'] as String,
        nom: json['nom'] as String,
        surface: (json['surface'] as num).toDouble(),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        typeSol: json['type_sol'] as String,
        archivee: (json['archivee'] as int) == 1,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  ParcelleModel copyWith({
    String? id,
    String? nom,
    double? surface,
    double? latitude,
    double? longitude,
    String? typeSol,
    bool? archivee,
    DateTime? createdAt,
  }) =>
      ParcelleModel(
        id: id ?? this.id,
        nom: nom ?? this.nom,
        surface: surface ?? this.surface,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        typeSol: typeSol ?? this.typeSol,
        archivee: archivee ?? this.archivee,
        createdAt: createdAt ?? this.createdAt,
      );
}
