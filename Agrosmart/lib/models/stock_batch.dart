// Modèle lot (batch) du module 3.6 – Gestion des stocks

class StockBatch {
  const StockBatch({
    this.id,
    required this.productId,
    required this.batchNumber,
    required this.quantity,
    this.expiryDate,
  });

  final int? id;
  final int productId;
  final String batchNumber;
  final double quantity;
  final DateTime? expiryDate;

  /// Vrai si la date d'expiration est dépassée.
  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Vrai si le lot expire dans les [days] jours (défaut 30).
  bool isExpiringSoon({int days = 30}) {
    if (expiryDate == null) return false;
    final diff = expiryDate!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= days;
  }

  StockBatch copyWith({
    int? id,
    int? productId,
    String? batchNumber,
    double? quantity,
    DateTime? expiryDate,
    bool clearExpiry = false,
  }) {
    return StockBatch(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      batchNumber: batchNumber ?? this.batchNumber,
      quantity: quantity ?? this.quantity,
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'batch_number': batchNumber,
      'quantity': quantity,
      'expiry_date': expiryDate?.toIso8601String(),
    };
  }

  factory StockBatch.fromMap(Map<String, dynamic> map) {
    return StockBatch(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      batchNumber: map['batch_number'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      expiryDate: map['expiry_date'] != null
          ? DateTime.parse(map['expiry_date'] as String)
          : null,
    );
  }
}
