// Service métier du module 3.6 – Gestion des stocks

import 'package:sqflite/sqflite.dart';

import '../models/stock_batch.dart';
import '../models/stock_movement.dart';
import '../models/stock_product.dart';
import 'stock_database.dart';

class StockServiceException implements Exception {
  const StockServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StockService {
  StockService._();
  static final StockService instance = StockService._();

  Future<Database> get _db => StockDatabase.instance.database;

  // ─────────────────────────────────────────────────────────
  // PRODUITS
  // ─────────────────────────────────────────────────────────

  Future<List<StockProduct>> getProducts({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.query(
      'products',
      where: includeArchived ? null : 'archived = 0',
      // Favoris non archivés en tête, puis tri alphabétique
      orderBy: 'favorite DESC, name ASC',
    );
    return rows.map(StockProduct.fromMap).toList();
  }

  Future<StockProduct?> getProduct(int id) async {
    final db = await _db;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return StockProduct.fromMap(rows.first);
  }

  Future<StockProduct> addProduct(StockProduct product) async {
    final db = await _db;
    final now = DateTime.now();
    final toInsert = product.copyWith(createdAt: now, updatedAt: now);
    final id = await db.insert('products', toInsert.toMap());
    return toInsert.copyWith(id: id);
  }

  Future<void> updateProduct(StockProduct product) async {
    final db = await _db;
    final updated = product.copyWith(updatedAt: DateTime.now());
    await db.update(
      'products',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  /// Suppression logique : archived = true, historique conservé.
  Future<void> archiveProduct(int productId) async {
    final db = await _db;
    await db.update(
      'products',
      {'archived': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<void> unarchiveProduct(int productId) async {
    final db = await _db;
    await db.update(
      'products',
      {'archived': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  /// Bascule le statut favori du produit.
  /// Un produit archivé ne peut pas être mis en favori.
  Future<void> toggleFavorite(int productId) async {
    final db = await _db;
    final product = await getProduct(productId);
    if (product == null || product.archived) return;
    final newValue = product.favorite ? 0 : 1;
    await db.update(
      'products',
      {'favorite': newValue, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // ─────────────────────────────────────────────────────────
  // LOTS
  // ─────────────────────────────────────────────────────────

  Future<List<StockBatch>> getBatchesForProduct(int productId) async {
    final db = await _db;
    final rows = await db.query(
      'batches',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'expiry_date ASC',
    );
    return rows.map(StockBatch.fromMap).toList();
  }

  Future<StockBatch> addBatch(StockBatch batch) async {
    final db = await _db;
    final id = await db.insert('batches', batch.toMap());
    // Met à jour la quantité totale du produit
    await _recalcProductQuantity(batch.productId, db);
    return batch.copyWith(id: id);
  }

  Future<void> _updateBatchQuantity(
    int batchId,
    double newQuantity,
    Database db,
  ) async {
    await db.update(
      'batches',
      {'quantity': newQuantity},
      where: 'id = ?',
      whereArgs: [batchId],
    );
  }

  /// Recalcule et persiste la quantité totale du produit depuis ses lots.
  Future<void> _recalcProductQuantity(int productId, Database db) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(quantity),0) AS total FROM batches WHERE product_id = ?',
      [productId],
    );
    final total = (rows.first['total'] as num).toDouble();
    await db.update(
      'products',
      {'total_quantity': total, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  /// Retourne le lot qui expire en premier (FEFO) pour un produit.
  /// Les lots sans date d'expiration sont proposés en dernier.
  Future<StockBatch?> getFefoSuggestedBatch(int productId) async {
    final batches = await getBatchesForProduct(productId);
    final available = batches.where((b) => b.quantity > 0).toList();
    if (available.isEmpty) return null;

    // Lots avec date en premier, triés par date ASC ; sans date en dernier
    available.sort((a, b) {
      if (a.expiryDate == null && b.expiryDate == null) return 0;
      if (a.expiryDate == null) return 1;
      if (b.expiryDate == null) return -1;
      return a.expiryDate!.compareTo(b.expiryDate!);
    });
    return available.first;
  }

  // ─────────────────────────────────────────────────────────
  // MOUVEMENTS
  // ─────────────────────────────────────────────────────────

  Future<List<StockMovement>> getMovements({
    int? productId,
    MovementType? type,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db;
    final wheres = <String>[];
    final args = <dynamic>[];

    if (productId != null) {
      wheres.add('product_id = ?');
      args.add(productId);
    }
    if (type != null) {
      wheres.add('type = ?');
      args.add(type.name);
    }
    if (from != null) {
      wheres.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      wheres.add('date <= ?');
      args.add(to.toIso8601String());
    }

    final rows = await db.query(
      'stock_movements',
      where: wheres.isEmpty ? null : wheres.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC',
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  /// Enregistre un mouvement et met à jour les quantités.
  /// Lève [StockServiceException] si le stock deviendrait négatif.
  Future<StockMovement> recordMovement(StockMovement movement) async {
    final db = await _db;

    // Récupère le produit
    final product = await getProduct(movement.productId);
    if (product == null) {
      throw const StockServiceException('Produit introuvable.');
    }

    if (movement.type == MovementType.sortie) {
      // Vérifie que le stock ne deviendra pas négatif
      if (movement.quantity > product.totalQuantity) {
        throw StockServiceException(
          'Stock insuffisant. Disponible : ${product.totalQuantity} ${product.unit}.',
        );
      }
      // Vérifie aussi le lot si précisé
      if (movement.batchId != null) {
        final rows = await db.query(
          'batches',
          where: 'id = ?',
          whereArgs: [movement.batchId],
        );
        if (rows.isNotEmpty) {
          final batch = StockBatch.fromMap(rows.first);
          if (movement.quantity > batch.quantity) {
            throw StockServiceException(
              'Quantité du lot insuffisante. Disponible : ${batch.quantity} ${product.unit}.',
            );
          }
          await _updateBatchQuantity(
            batch.id!,
            batch.quantity - movement.quantity,
            db,
          );
        }
      } else {
        // Sortie sans lot : décrémente le premier lot FEFO
        await _deductFromBatchesFefo(movement.productId, movement.quantity, db);
      }
    } else {
      // Entrée : ajoute au lot si précisé
      if (movement.batchId != null) {
        final rows = await db.query(
          'batches',
          where: 'id = ?',
          whereArgs: [movement.batchId],
        );
        if (rows.isNotEmpty) {
          final batch = StockBatch.fromMap(rows.first);
          await _updateBatchQuantity(
            batch.id!,
            batch.quantity + movement.quantity,
            db,
          );
        }
      }
    }

    final id = await db.insert('stock_movements', movement.toMap());
    await _recalcProductQuantity(movement.productId, db);
    return movement.copyWith(id: id);
  }

  /// Décrémente FEFO sur les lots sans qu'un lot ait été précisé.
  Future<void> _deductFromBatchesFefo(
    int productId,
    double qty,
    Database db,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT * FROM batches
      WHERE product_id = ? AND quantity > 0
      ORDER BY
        CASE WHEN expiry_date IS NULL THEN 1 ELSE 0 END,
        expiry_date ASC
      ''',
      [productId],
    );
    var remaining = qty;
    for (final row in rows) {
      if (remaining <= 0) break;
      final batch = StockBatch.fromMap(row);
      final take = remaining < batch.quantity ? remaining : batch.quantity;
      await _updateBatchQuantity(batch.id!, batch.quantity - take, db);
      remaining -= take;
    }
  }

  // ─────────────────────────────────────────────────────────
  // ALERTES
  // ─────────────────────────────────────────────────────────

  /// Retourne les produits en stock faible (non archivés).
  Future<List<StockProduct>> getLowStockProducts({
    bool includeArchived = false,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT * FROM products WHERE '
      '${includeArchived ? '1 = 1' : 'archived = 0'} '
      'AND total_quantity <= min_threshold',
    );
    return rows.map(StockProduct.fromMap).toList();
  }

  /// Retourne les lots bientôt expirés ou expirés (produits non archivés).
  Future<List<StockBatch>> getExpiringBatches({
    int days = 30,
    bool includeArchived = false,
  }) async {
    final db = await _db;
    final limit = DateTime.now().add(Duration(days: days)).toIso8601String();
    final rows = await db.rawQuery(
      '''
      SELECT b.* FROM batches b
      JOIN products p ON p.id = b.product_id
      WHERE ${includeArchived ? '1 = 1' : 'p.archived = 0'}
        AND b.quantity > 0
        AND b.expiry_date IS NOT NULL
        AND b.expiry_date <= ?
      ORDER BY b.expiry_date ASC
      ''',
      [limit],
    );
    return rows.map(StockBatch.fromMap).toList();
  }

  /// Nombre total d'alertes actives.
  Future<int> getAlertCount({int expiryDays = 30}) async {
    final low = await getLowStockProducts();
    final expiring = await getExpiringBatches(days: expiryDays);
    // Déduplique : un produit peut avoir stock faible ET lot expirant
    final productIds = <int>{...low.map((p) => p.id!)};
    final expiringProductIds = <int>{...expiring.map((b) => b.productId)};
    return (productIds..addAll(expiringProductIds)).length;
  }
}
