// Tests unitaires – Favoris (fonctionnalité 2)

import 'package:flutter_test/flutter_test.dart';

import 'package:my_application/models/stock_product.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

StockProduct makeProduct({
  int id = 1,
  bool archived = false,
  bool favorite = false,
}) {
  final now = DateTime.now();
  return StockProduct(
    id: id,
    name: 'Produit $id',
    category: ProductCategory.engrais,
    unit: 'kg',
    totalQuantity: 100,
    minThreshold: 10,
    archived: archived,
    favorite: favorite,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  // ── Modèle ────────────────────────────────────────────────────────────────

  group('StockProduct.favorite — modèle', () {
    test('valeur par défaut = false', () {
      final p = makeProduct();
      expect(p.favorite, isFalse);
    });

    test('copyWith bascule le favori', () {
      final p = makeProduct(favorite: false);
      final fav = p.copyWith(favorite: true);
      expect(fav.favorite, isTrue);
      expect(p.favorite, isFalse); // immutabilité
    });

    test('copyWith sans favorite conserve la valeur existante', () {
      final p = makeProduct(favorite: true);
      final copy = p.copyWith(name: 'Nouveau nom');
      expect(copy.favorite, isTrue);
    });
  });

  // ── Sérialisation ────────────────────────────────────────────────────────

  group('StockProduct — sérialisation favorite', () {
    test('toMap inclut favorite = 1 quand true', () {
      final p = makeProduct(favorite: true);
      final map = p.toMap();
      expect(map['favorite'], equals(1));
    });

    test('toMap inclut favorite = 0 quand false', () {
      final p = makeProduct(favorite: false);
      final map = p.toMap();
      expect(map['favorite'], equals(0));
    });

    test('fromMap lit favorite correctement', () {
      final now = DateTime.now().toIso8601String();
      final map = {
        'id': 1,
        'name': 'Test',
        'category': 'engrais',
        'unit': 'kg',
        'total_quantity': 50.0,
        'min_threshold': 10.0,
        'notes': null,
        'archived': 0,
        'favorite': 1,
        'created_at': now,
        'updated_at': now,
      };
      final p = StockProduct.fromMap(map);
      expect(p.favorite, isTrue);
    });

    test('fromMap avec favorite absent (migration) → false par défaut', () {
      final now = DateTime.now().toIso8601String();
      final map = {
        'id': 1,
        'name': 'Test',
        'category': 'engrais',
        'unit': 'kg',
        'total_quantity': 50.0,
        'min_threshold': 10.0,
        'notes': null,
        'archived': 0,
        // 'favorite' absent — simule une ancienne ligne SQL
        'created_at': now,
        'updated_at': now,
      };
      final p = StockProduct.fromMap(map);
      expect(p.favorite, isFalse);
    });
  });

  // ── Règle métier : archivage ──────────────────────────────────────────────

  group('Favoris — règle archivage', () {
    test(
      'un produit archivé favori ne devrait pas apparaître dans les épinglés',
      () {
        final products = [
          makeProduct(id: 1, archived: false, favorite: true),
          makeProduct(id: 2, archived: true, favorite: true),
          makeProduct(id: 3, archived: false, favorite: false),
        ];
        // Simule le filtre de l'écran inventaire
        final pinned =
            products.where((p) => p.favorite && !p.archived).toList();
        expect(pinned.length, equals(1));
        expect(pinned.first.id, equals(1));
      },
    );

    test('restauration : un produit désarchivé retrouve son favori', () {
      // Le champ favorite reste en base à true même quand archivé
      // C'est la restauration (unarchive) qui le fait réapparaître
      final archived = makeProduct(id: 1, archived: true, favorite: true);
      final restored = archived.copyWith(archived: false);
      expect(restored.favorite, isTrue);
    });
  });

  // ── Tri ───────────────────────────────────────────────────────────────────

  group('Tri — favoris en premier', () {
    test('les favoris non archivés remontent avant les autres', () {
      final products = [
        makeProduct(id: 1, favorite: false),
        makeProduct(id: 2, favorite: true),
        makeProduct(id: 3, favorite: false),
      ];
      // Simule le tri SQL : favorite DESC, name ASC
      products.sort((a, b) {
        final favCmp = (b.favorite ? 1 : 0) - (a.favorite ? 1 : 0);
        if (favCmp != 0) return favCmp;
        return a.name.compareTo(b.name);
      });
      expect(products.first.id, equals(2));
    });
  });
}
