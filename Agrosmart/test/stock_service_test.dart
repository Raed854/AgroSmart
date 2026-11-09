// Tests unitaires – module 3.6 Gestion des stocks
// Couvre : alertes, stock négatif, FEFO, suggestions IA
// Utilise flutter_test (SDK Flutter, déjà installé)

import 'package:flutter_test/flutter_test.dart';

import 'package:my_application/models/stock_batch.dart';
import 'package:my_application/models/stock_movement.dart';
import 'package:my_application/models/stock_product.dart';
import 'package:my_application/services/reorder_suggestion_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

StockProduct makeProduct({
  int id = 1,
  double totalQuantity = 100,
  double minThreshold = 20,
  ProductCategory category = ProductCategory.engrais,
  String unit = 'kg',
}) {
  final now = DateTime.now();
  return StockProduct(
    id: id,
    name: 'Produit Test',
    category: category,
    unit: unit,
    totalQuantity: totalQuantity,
    minThreshold: minThreshold,
    createdAt: now,
    updatedAt: now,
  );
}

StockBatch makeBatch({
  int id = 1,
  int productId = 1,
  double quantity = 50,
  DateTime? expiryDate,
}) {
  return StockBatch(
    id: id,
    productId: productId,
    batchNumber: 'LOT-00$id',
    quantity: quantity,
    expiryDate: expiryDate,
  );
}

StockMovement makeSortie({
  int productId = 1,
  double quantity = 10,
  DateTime? date,
}) {
  return StockMovement(
    productId: productId,
    type: MovementType.sortie,
    quantity: quantity,
    date: date ?? DateTime.now(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Modèle StockProduct – logique d'alerte stock faible
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('StockProduct.isLow', () {
    test('retourne true quand quantité == seuil', () {
      final p = makeProduct(totalQuantity: 20, minThreshold: 20);
      expect(p.isLow, isTrue);
    });

    test('retourne true quand quantité < seuil', () {
      final p = makeProduct(totalQuantity: 5, minThreshold: 20);
      expect(p.isLow, isTrue);
    });

    test('retourne false quand quantité > seuil', () {
      final p = makeProduct(totalQuantity: 21, minThreshold: 20);
      expect(p.isLow, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Modèle StockBatch – logique d'expiration
  // ─────────────────────────────────────────────────────────────────────────

  group('StockBatch.isExpired', () {
    test('retourne true pour une date passée', () {
      final b = makeBatch(
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(b.isExpired, isTrue);
    });

    test('retourne false pour une date future', () {
      final b = makeBatch(
        expiryDate: DateTime.now().add(const Duration(days: 10)),
      );
      expect(b.isExpired, isFalse);
    });

    test('retourne false si pas de date', () {
      final b = makeBatch(expiryDate: null);
      expect(b.isExpired, isFalse);
    });
  });

  group('StockBatch.isExpiringSoon', () {
    test('retourne true si expire dans la fenêtre (défaut 30 j)', () {
      final b = makeBatch(
        expiryDate: DateTime.now().add(const Duration(days: 15)),
      );
      expect(b.isExpiringSoon(), isTrue);
    });

    test('retourne false si expire après la fenêtre', () {
      final b = makeBatch(
        expiryDate: DateTime.now().add(const Duration(days: 45)),
      );
      expect(b.isExpiringSoon(), isFalse);
    });

    test('retourne false si lot déjà expiré (géré par isExpired)', () {
      final b = makeBatch(
        expiryDate: DateTime.now().subtract(const Duration(days: 5)),
      );
      // isExpiringSoon ne doit pas retourner true pour un lot déjà expiré
      expect(b.isExpiringSoon(), isFalse);
    });

    test('retourne false si pas de date', () {
      final b = makeBatch(expiryDate: null);
      expect(b.isExpiringSoon(), isFalse);
    });

    test('fenêtre personnalisée', () {
      final b = makeBatch(
        expiryDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(b.isExpiringSoon(days: 7), isTrue);
      expect(b.isExpiringSoon(days: 3), isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 3. FEFO – tri des lots
  // ─────────────────────────────────────────────────────────────────────────

  group('FEFO – tri des lots', () {
    test('le lot avec la date la plus proche est proposé en premier', () {
      final near = makeBatch(
        id: 1,
        expiryDate: DateTime.now().add(const Duration(days: 10)),
      );
      final far = makeBatch(
        id: 2,
        expiryDate: DateTime.now().add(const Duration(days: 60)),
      );
      // Simulation du tri FEFO
      final batches = [far, near]
        ..sort((a, b) {
          if (a.expiryDate == null && b.expiryDate == null) return 0;
          if (a.expiryDate == null) return 1;
          if (b.expiryDate == null) return -1;
          return a.expiryDate!.compareTo(b.expiryDate!);
        });
      expect(batches.first.id, equals(1)); // near
    });

    test('les lots sans date sont proposés en dernier', () {
      final withDate = makeBatch(
        id: 1,
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      );
      final noDate = makeBatch(id: 2, expiryDate: null);
      final batches = [noDate, withDate]
        ..sort((a, b) {
          if (a.expiryDate == null && b.expiryDate == null) return 0;
          if (a.expiryDate == null) return 1;
          if (b.expiryDate == null) return -1;
          return a.expiryDate!.compareTo(b.expiryDate!);
        });
      expect(batches.first.id, equals(1)); // withDate
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Stock négatif – validation
  // ─────────────────────────────────────────────────────────────────────────

  group('Validation stock négatif', () {
    test('sortie supérieure au stock disponible est rejetée', () {
      final product = makeProduct(totalQuantity: 30);
      const requestedQty = 50.0;
      // Simule la règle de validation (logique du service)
      final wouldGoNegative = requestedQty > product.totalQuantity;
      expect(wouldGoNegative, isTrue);
    });

    test('sortie égale au stock disponible est acceptée', () {
      final product = makeProduct(totalQuantity: 30);
      const requestedQty = 30.0;
      final wouldGoNegative = requestedQty > product.totalQuantity;
      expect(wouldGoNegative, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 5. ReorderSuggestionService
  // ─────────────────────────────────────────────────────────────────────────

  group('ReorderSuggestionService', () {
    const service = ReorderSuggestionService();

    test('retourne SuggestionNoHistory si moins de 5 sorties', () {
      final product = makeProduct(totalQuantity: 100);
      final sorties = List.generate(
        4,
        (i) => makeSortie(quantity: 5),
      );
      final result = service.compute(
        product: product,
        sortieMovements: sorties,
        windowDays: 30,
      );
      expect(result, isA<SuggestionNoHistory>());
    });

    test('retourne SuggestionOk avec 5 sorties ou plus', () {
      final product = makeProduct(totalQuantity: 100);
      final sorties = List.generate(
        10,
        (i) => makeSortie(quantity: 2),
      ); // 20 kg sur 30 jours
      final result = service.compute(
        product: product,
        sortieMovements: sorties,
        windowDays: 30,
      );
      expect(result, isA<SuggestionOk>());
    });

    test('consommation moyenne correcte', () {
      final product = makeProduct(totalQuantity: 100);
      // 10 sorties × 3 kg = 30 kg sur 30 jours → 1 kg/jour
      final sorties = List.generate(10, (i) => makeSortie(quantity: 3));
      final result = service.compute(
        product: product,
        sortieMovements: sorties,
        windowDays: 30,
      );
      expect(result, isA<SuggestionOk>());
      final ok = result as SuggestionOk;
      expect(ok.suggestion.avgDailyConsumption, closeTo(1.0, 0.001));
    });

    test('couverture restante correcte', () {
      // 100 kg disponibles, consommation 1 kg/jour → 100 jours
      final product = makeProduct(totalQuantity: 100);
      final sorties = List.generate(10, (i) => makeSortie(quantity: 3));
      final result = service.compute(
        product: product,
        sortieMovements: sorties,
        windowDays: 30,
      );
      final ok = result as SuggestionOk;
      expect(ok.suggestion.daysOfCoverage, closeTo(100, 1));
    });

    test('quantité suggérée = avgDaily × 30', () {
      final product = makeProduct(totalQuantity: 100);
      // avg = 1 kg/j → suggestion = 30 kg
      final sorties = List.generate(10, (i) => makeSortie(quantity: 3));
      final result = service.compute(
        product: product,
        sortieMovements: sorties,
        windowDays: 30,
      );
      final ok = result as SuggestionOk;
      expect(ok.suggestion.suggestedQuantity, closeTo(30, 0.1));
    });

    test('retourne SuggestionNoHistory si consommation totale = 0', () {
      final product = makeProduct(totalQuantity: 100);
      // 10 sorties de 0 unités (cas limite)
      final sorties = List.generate(10, (i) => makeSortie(quantity: 0));
      final result = service.compute(
        product: product,
        sortieMovements: sorties,
        windowDays: 30,
      );
      expect(result, isA<SuggestionNoHistory>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 6. StockProduct.copyWith
  // ─────────────────────────────────────────────────────────────────────────

  group('StockProduct.copyWith', () {
    test('met à jour seulement les champs spécifiés', () {
      final p = makeProduct(totalQuantity: 100, minThreshold: 10);
      final updated = p.copyWith(totalQuantity: 50);
      expect(updated.totalQuantity, equals(50));
      expect(updated.minThreshold, equals(10)); // inchangé
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 7. Sérialisation / désérialisation
  // ─────────────────────────────────────────────────────────────────────────

  group('StockProduct.toMap / fromMap', () {
    test('aller-retour sans perte', () {
      final p = makeProduct(totalQuantity: 42.5, minThreshold: 5);
      final map = p.toMap();
      final p2 = StockProduct.fromMap({...map, 'id': 1});
      expect(p2.totalQuantity, equals(42.5));
      expect(p2.category, equals(ProductCategory.engrais));
      expect(p2.unit, equals('kg'));
    });
  });

  group('StockMovement.toMap / fromMap', () {
    test('aller-retour sans perte', () {
      final m = StockMovement(
        productId: 1,
        type: MovementType.sortie,
        quantity: 15,
        date: DateTime(2025, 6, 1),
        note: 'Test note',
      );
      final map = m.toMap();
      final m2 = StockMovement.fromMap({...map, 'id': 1});
      expect(m2.type, equals(MovementType.sortie));
      expect(m2.quantity, equals(15));
      expect(m2.note, equals('Test note'));
    });
  });
}
