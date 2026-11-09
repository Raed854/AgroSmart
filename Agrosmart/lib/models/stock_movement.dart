// Modèle mouvement de stock du module 3.6

enum MovementType {
  entree,
  sortie;

  String get label => this == MovementType.entree ? 'Entrée' : 'Sortie';
}

class StockMovement {
  const StockMovement({
    this.id,
    required this.productId,
    this.batchId,
    required this.type,
    required this.quantity,
    required this.date,
    this.note,
  });

  final int? id;
  final int productId;
  final int? batchId;
  final MovementType type;
  final double quantity;
  final DateTime date;
  final String? note;

  StockMovement copyWith({
    int? id,
    int? productId,
    int? batchId,
    MovementType? type,
    double? quantity,
    DateTime? date,
    String? note,
  }) {
    return StockMovement(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      batchId: batchId ?? this.batchId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'batch_id': batchId,
      'type': type.name,
      'quantity': quantity,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      batchId: map['batch_id'] as int?,
      type: MovementType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MovementType.entree,
      ),
      quantity: (map['quantity'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
    );
  }
}
