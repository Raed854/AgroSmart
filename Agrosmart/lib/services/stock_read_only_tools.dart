// Outils de lecture seule pour l'assistant du module 3.6.

import '../models/stock_movement.dart';
import '../models/stock_product.dart';
import '../models/stock_batch.dart';
import 'reorder_suggestion_service.dart';
import 'stock_service.dart';

const _defaultLimit = 20;

class ReadOnlyToolResult<T> {
  const ReadOnlyToolResult({required this.items, required this.truncated});

  final List<T> items;
  final bool truncated;
}

class InventoryItem {
  const InventoryItem({required this.product});

  final StockProduct product;
}

class AlertItem {
  const AlertItem({required this.product, required this.kind, this.batch});

  final StockProduct product;
  final AlertKind kind;
  final StockBatch? batch;
}

enum AlertKind { stockFaible, expiration }

class MovementItem {
  const MovementItem({required this.product, required this.movement});

  final StockProduct product;
  final StockMovement movement;
}

class MonthlyProductReport {
  const MonthlyProductReport({
    required this.product,
    required this.entries,
    required this.sorties,
    required this.movementCount,
  });

  final StockProduct product;
  final double entries;
  final double sorties;
  final int movementCount;
}

class MonthlyReport {
  const MonthlyReport({
    required this.year,
    required this.month,
    required this.entries,
    required this.sorties,
    required this.movementCount,
    required this.products,
  });

  final int year;
  final int month;
  final double entries;
  final double sorties;
  final int movementCount;
  final List<MonthlyProductReport> products;
}

/// Façade strictement en lecture seule pour les questions de stock.
class StockReadOnlyTools {
  StockReadOnlyTools({StockService? service})
    : _service = service ?? StockService.instance;

  final StockService _service;
  final _suggestionService = const ReorderSuggestionService();

  Future<ReadOnlyToolResult<StockProduct>> searchProducts({
    String query = '',
    ProductCategory? category,
    bool includeArchived = false,
    int limit = _defaultLimit,
  }) async {
    _validateLimit(limit);
    final normalizedQuery = query.trim().toLowerCase();
    final products = await _service.getProducts(
      includeArchived: includeArchived,
    );
    final matches = products.where((product) {
      if (category != null && product.category != category) return false;
      if (normalizedQuery.isEmpty) return true;
      return product.name.toLowerCase().contains(normalizedQuery) ||
          product.category.label.toLowerCase().contains(normalizedQuery);
    }).toList();
    return _limited(matches, limit);
  }

  Future<ReadOnlyToolResult<InventoryItem>> getInventorySummary({
    bool includeArchived = false,
    int limit = _defaultLimit,
  }) async {
    _validateLimit(limit);
    final products = await _service.getProducts(
      includeArchived: includeArchived,
    );
    return _limited(
      products.map((product) => InventoryItem(product: product)).toList(),
      limit,
    );
  }

  Future<ReadOnlyToolResult<AlertItem>> getAlerts({
    int expiryDays = 30,
    bool includeArchived = false,
    int limit = _defaultLimit,
  }) async {
    _validateLimit(limit);
    _validateDays(expiryDays);
    final lowStock = await _service.getLowStockProducts(
      includeArchived: includeArchived,
    );
    final expiring = await _service.getExpiringBatches(
      days: expiryDays,
      includeArchived: includeArchived,
    );
    final products = await _service.getProducts(
      includeArchived: includeArchived,
    );
    final byId = {for (final product in products) product.id!: product};
    final alerts = <AlertItem>[
      ...lowStock.map(
        (product) => AlertItem(product: product, kind: AlertKind.stockFaible),
      ),
      ...expiring
          .where((batch) => byId.containsKey(batch.productId))
          .map(
            (batch) => AlertItem(
              product: byId[batch.productId]!,
              kind: AlertKind.expiration,
              batch: batch,
            ),
          ),
    ];
    return _limited(alerts, limit);
  }

  Future<ReadOnlyToolResult<SuggestionResult>> getReorderSuggestions({
    int windowDays = 30,
    bool includeArchived = false,
    int limit = _defaultLimit,
  }) async {
    _validateLimit(limit);
    _validateDays(windowDays);
    final products = await _service.getProducts(
      includeArchived: includeArchived,
    );
    final results = <SuggestionResult>[];
    final from = DateTime.now().subtract(Duration(days: windowDays));
    for (final product in products) {
      final movements = await _service.getMovements(
        productId: product.id,
        type: MovementType.sortie,
        from: from,
      );
      results.add(
        _suggestionService.compute(
          product: product,
          sortieMovements: movements,
          windowDays: windowDays,
        ),
      );
    }
    return _limited(results, limit);
  }

  Future<ReadOnlyToolResult<MovementItem>> getMovements({
    int? productId,
    MovementType? type,
    DateTime? from,
    DateTime? to,
    bool includeArchived = false,
    int limit = _defaultLimit,
  }) async {
    _validateLimit(limit);
    if (productId != null && productId <= 0) {
      throw ArgumentError.value(productId, 'productId', 'Doit être positif.');
    }
    if (from != null && to != null && from.isAfter(to)) {
      throw ArgumentError('La date de début doit précéder la date de fin.');
    }
    final products = await _service.getProducts(
      includeArchived: includeArchived,
    );
    final byId = {for (final product in products) product.id!: product};
    if (productId != null && !byId.containsKey(productId)) {
      return const ReadOnlyToolResult(items: [], truncated: false);
    }
    final movements = await _service.getMovements(
      productId: productId,
      type: type,
      from: from,
      to: to,
    );
    final items = movements
        .where((movement) => byId.containsKey(movement.productId))
        .map(
          (movement) => MovementItem(
            product: byId[movement.productId]!,
            movement: movement,
          ),
        )
        .toList();
    return _limited(items, limit);
  }

  Future<MonthlyReport> getMonthlyReport({
    required int year,
    required int month,
    int limit = _defaultLimit,
  }) async {
    _validateLimit(limit);
    if (year < 2000 || year > 2100) {
      throw ArgumentError.value(year, 'year', 'Année invalide.');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Mois invalide.');
    }
    final from = DateTime(year, month);
    final to = DateTime(year, month + 1);
    final products = await _service.getProducts();
    final byId = {for (final product in products) product.id!: product};
    final movements = await _service.getMovements(from: from, to: to);
    final grouped = <int, List<StockMovement>>{};
    for (final movement in movements) {
      if (byId.containsKey(movement.productId)) {
        grouped.putIfAbsent(movement.productId, () => []).add(movement);
      }
    }

    var entries = 0.0;
    var sorties = 0.0;
    final reports = <MonthlyProductReport>[];
    for (final entry in grouped.entries) {
      var productEntries = 0.0;
      var productSorties = 0.0;
      for (final movement in entry.value) {
        if (movement.type == MovementType.entree) {
          entries += movement.quantity;
          productEntries += movement.quantity;
        } else {
          sorties += movement.quantity;
          productSorties += movement.quantity;
        }
      }
      reports.add(
        MonthlyProductReport(
          product: byId[entry.key]!,
          entries: productEntries,
          sorties: productSorties,
          movementCount: entry.value.length,
        ),
      );
    }
    reports.sort((a, b) => a.product.name.compareTo(b.product.name));
    return MonthlyReport(
      year: year,
      month: month,
      entries: entries,
      sorties: sorties,
      movementCount: movements.length,
      products: reports.take(limit).toList(),
    );
  }

  ReadOnlyToolResult<T> _limited<T>(List<T> items, int limit) {
    return ReadOnlyToolResult(
      items: items.take(limit).toList(),
      truncated: items.length > limit,
    );
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 20) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Doit être compris entre 1 et 20.',
      );
    }
  }

  void _validateDays(int days) {
    if (days < 0 || days > 3650) {
      throw ArgumentError.value(
        days,
        'days',
        'Doit être compris entre 0 et 3650.',
      );
    }
  }
}
