// Modèle produit du module 3.6 – Gestion des stocks

enum ProductCategory {
  semences,
  engrais,
  medicaments,
  traitement;

  String get label => switch (this) {
        ProductCategory.semences => 'Semences',
        ProductCategory.engrais => 'Engrais',
        ProductCategory.medicaments => 'Médicaments',
        ProductCategory.traitement => 'Produits de traitement',
      };
}

/// Unités de mesure proposées dans le formulaire.
const kStockUnits = ['kg', 'g', 'L', 'mL', 'sac', 'unité'];

class StockProduct {
  const StockProduct({
    this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.totalQuantity,
    required this.minThreshold,
    this.notes,
    this.archived = false,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final ProductCategory category;
  final String unit;
  final double totalQuantity;
  final double minThreshold;
  final String? notes;
  final bool archived;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLow => totalQuantity <= minThreshold;

  StockProduct copyWith({
    int? id,
    String? name,
    ProductCategory? category,
    String? unit,
    double? totalQuantity,
    double? minThreshold,
    String? notes,
    bool? archived,
    bool? favorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StockProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      minThreshold: minThreshold ?? this.minThreshold,
      notes: notes ?? this.notes,
      archived: archived ?? this.archived,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category.name,
      'unit': unit,
      'total_quantity': totalQuantity,
      'min_threshold': minThreshold,
      'notes': notes,
      'archived': archived ? 1 : 0,
      'favorite': favorite ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StockProduct.fromMap(Map<String, dynamic> map) {
    return StockProduct(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: ProductCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => ProductCategory.semences,
      ),
      unit: map['unit'] as String,
      totalQuantity: (map['total_quantity'] as num).toDouble(),
      minThreshold: (map['min_threshold'] as num).toDouble(),
      notes: map['notes'] as String?,
      archived: (map['archived'] as int) == 1,
      favorite: (map['favorite'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
