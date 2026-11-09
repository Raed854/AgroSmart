// Tests unitaires – Filtres enregistrés (fonctionnalité 3)

import 'package:flutter_test/flutter_test.dart';

import 'package:my_application/models/saved_filter.dart';
import 'package:my_application/models/stock_batch.dart';
import 'package:my_application/models/stock_product.dart';
import 'package:my_application/services/saved_filter_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

SavedFilter makeFilter({
  int? id,
  String name = 'Mon filtre',
  ProductCategory? category,
  bool filterLow = false,
  bool filterExpiring = false,
  bool filterArchived = false,
  String? searchText,
  bool isPreset = false,
}) =>
    SavedFilter(
      id: id,
      name: name,
      category: category,
      filterLow: filterLow,
      filterExpiring: filterExpiring,
      filterArchived: filterArchived,
      searchText: searchText,
      isPreset: isPreset,
      createdAt: DateTime.now(),
    );

StockProduct makeProduct({
  int id = 1,
  String name = 'Produit',
  ProductCategory category = ProductCategory.engrais,
  double totalQuantity = 100,
  double minThreshold = 10,
  bool archived = false,
}) {
  final now = DateTime.now();
  return StockProduct(
    id: id,
    name: name,
    category: category,
    unit: 'kg',
    totalQuantity: totalQuantity,
    minThreshold: minThreshold,
    archived: archived,
    createdAt: now,
    updatedAt: now,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Modèle ────────────────────────────────────────────────────────────────

  group('SavedFilter.hasAnyCriteria', () {
    test('false si aucun critère', () {
      final f = makeFilter();
      expect(f.hasAnyCriteria, isFalse);
    });
    test('true si filterLow', () {
      expect(makeFilter(filterLow: true).hasAnyCriteria, isTrue);
    });
    test('true si filterExpiring', () {
      expect(makeFilter(filterExpiring: true).hasAnyCriteria, isTrue);
    });
    test('true si catégorie', () {
      expect(
        makeFilter(category: ProductCategory.semences).hasAnyCriteria,
        isTrue,
      );
    });
    test('true si searchText non vide', () {
      expect(makeFilter(searchText: 'maïs').hasAnyCriteria, isTrue);
    });
  });

  group('SavedFilter — sérialisation', () {
    test('aller-retour toMap/fromMap sans perte', () {
      final f = makeFilter(
        id: 1,
        name: 'Test',
        category: ProductCategory.semences,
        filterLow: true,
        filterExpiring: false,
        filterArchived: false,
        searchText: 'maïs',
      );
      final map = f.toMap()..['id'] = 1;
      final f2 = SavedFilter.fromMap(map);
      expect(f2.name, equals('Test'));
      expect(f2.category, equals(ProductCategory.semences));
      expect(f2.filterLow, isTrue);
      expect(f2.searchText, equals('maïs'));
    });

    test('category null → pas de colonne category', () {
      final f = makeFilter(filterLow: true);
      final map = f.toMap();
      expect(map['category'], isNull);
    });
  });

  group('SavedFilter.criteriaLabel', () {
    test('retourne les critères actifs', () {
      final f = makeFilter(
        category: ProductCategory.engrais,
        filterLow: true,
        searchText: 'NPK',
      );
      expect(f.criteriaLabel, contains('Engrais'));
      expect(f.criteriaLabel, contains('Stock faible'));
      expect(f.criteriaLabel, contains('"NPK"'));
    });
    test('retourne "Aucun critère" si vide', () {
      expect(makeFilter().criteriaLabel, equals('Aucun critère'));
    });
  });

  // ── Validation nom ────────────────────────────────────────────────────────

  group('SavedFilterService.validateName', () {
    test('nom vide → SavedFilterException', () {
      expect(
        () => SavedFilterService.validateName(''),
        throwsA(isA<SavedFilterException>()),
      );
    });
    test('nom > 40 car. → exception', () {
      expect(
        () => SavedFilterService.validateName('A' * 41),
        throwsA(isA<SavedFilterException>()),
      );
    });
    test('nom valide → pas d\'exception', () {
      expect(() => SavedFilterService.validateName('Filtre OK'), returnsNormally);
    });
  });

  // ── Application des filtres ───────────────────────────────────────────────

  group('SavedFilterService.applyFilter', () {
    final products = [
      makeProduct(
        id: 1,
        name: 'Maïs hybride',
        category: ProductCategory.semences,
        totalQuantity: 5,
        minThreshold: 10,
      ), // isLow = true
      makeProduct(
        id: 2,
        name: 'Engrais NPK',
        category: ProductCategory.engrais,
        totalQuantity: 100,
        minThreshold: 20,
      ),
      makeProduct(
        id: 3,
        name: 'Fongicide',
        category: ProductCategory.traitement,
        totalQuantity: 15,
        minThreshold: 5,
        archived: true,
      ),
    ];

    test('filterLow → seulement produits en stock faible', () {
      final f = makeFilter(filterLow: true);
      final res = SavedFilterService.applyFilter(f, products);
      expect(res.length, equals(1));
      expect(res.first.id, equals(1));
    });

    test('filterArchived → seulement archivés', () {
      // Doit inclure les archivés
      final allIncludingArchived = [
        ...products,
      ];
      final f = makeFilter(filterArchived: true);
      final res = SavedFilterService.applyFilter(f, allIncludingArchived);
      expect(res.every((p) => p.archived), isTrue);
    });

    test('catégorie engrais → seulement Engrais', () {
      final f = makeFilter(category: ProductCategory.engrais);
      final res = SavedFilterService.applyFilter(f, products);
      expect(res.every((p) => p.category == ProductCategory.engrais), isTrue);
    });

    test('searchText "maïs" → produit contenant "maïs"', () {
      final f = makeFilter(searchText: 'maïs');
      final res = SavedFilterService.applyFilter(f, products);
      expect(res.length, equals(1));
      expect(res.first.name.toLowerCase(), contains('maïs'));
    });

    test('filterExpiring → utilise les lots pour détecter expiration', () {
      final expBatch = StockBatch(
        id: 1,
        productId: 2,
        batchNumber: 'LOT-01',
        quantity: 50,
        expiryDate: DateTime.now().add(const Duration(days: 5)),
      );
      final batchesMap = {2: [expBatch]};
      final f = makeFilter(filterExpiring: true);
      final res = SavedFilterService.applyFilter(
        f,
        products,
        batchesMap: batchesMap,
      );
      expect(res.length, equals(1));
      expect(res.first.id, equals(2));
    });

    test('aucun critère → retourne tout (non archivé)', () {
      final f = makeFilter();
      final res = SavedFilterService.applyFilter(f, products);
      // Les archivés sont exclus par défaut (filterArchived = false)
      expect(res.every((p) => !p.archived), isTrue);
    });
  });

  // ── countResults ─────────────────────────────────────────────────────────

  group('SavedFilterService.countResults', () {
    final products = [
      makeProduct(id: 1, totalQuantity: 5, minThreshold: 10), // isLow
      makeProduct(id: 2, totalQuantity: 100, minThreshold: 10),
    ];

    test('compte correctement', () {
      final f = makeFilter(filterLow: true);
      expect(SavedFilterService.countResults(f, products), equals(1));
    });
    test('sans critère → compte les non archivés', () {
      final f = makeFilter();
      expect(SavedFilterService.countResults(f, products), equals(2));
    });
  });

  // ── Limite 11e filtre ─────────────────────────────────────────────────────

  group('Limite maxUserFilters', () {
    test('maxUserFilters = 10', () {
      expect(SavedFilterService.maxUserFilters, equals(10));
    });
  });

  // ── Preset non supprimable (validation logique) ───────────────────────────

  group('Preset non supprimable', () {
    test('un filtre preset a isPreset = true', () {
      final f = makeFilter(isPreset: true);
      expect(f.isPreset, isTrue);
    });
  });
}
