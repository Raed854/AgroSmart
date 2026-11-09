// Service filtres enregistrés – module 3.6, fonctionnalité 3

import 'package:sqflite/sqflite.dart';

import '../models/saved_filter.dart';
import '../models/stock_batch.dart';
import '../models/stock_product.dart';
import 'stock_database.dart';

class SavedFilterException implements Exception {
  const SavedFilterException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SavedFilterService {
  SavedFilterService._();
  static final SavedFilterService instance = SavedFilterService._();

  /// Maximum de filtres créés par l'utilisateur (hors presets).
  static const int maxUserFilters = 10;
  static const int maxNameLength = 40;

  Future<Database> get _db => StockDatabase.instance.database;

  // ── Lecture ──────────────────────────────────────────────────────────────

  /// Retourne les filtres : presets en premier, puis par date de création.
  Future<List<SavedFilter>> getFilters() async {
    final db = await _db;
    final rows = await db.query(
      'saved_filters',
      orderBy: 'is_preset DESC, created_at ASC',
    );
    return rows.map(SavedFilter.fromMap).toList();
  }

  Future<SavedFilter?> getFilter(int id) async {
    final db = await _db;
    final rows = await db.query(
      'saved_filters',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return SavedFilter.fromMap(rows.first);
  }

  // ── Création ─────────────────────────────────────────────────────────────

  /// Enregistre un nouveau filtre utilisateur.
  /// - Nom obligatoire, unique, ≤ [maxNameLength] caractères.
  /// - Maximum [maxUserFilters] filtres utilisateur.
  /// - Au moins un critère requis.
  Future<SavedFilter> saveFilter(SavedFilter filter) async {
    validateName(filter.name);

    if (!filter.hasAnyCriteria) {
      throw const SavedFilterException(
        'Au moins un critère doit être actif pour enregistrer un filtre.',
      );
    }

    final db = await _db;

    // Vérifie le nom unique
    final existing = await db.query(
      'saved_filters',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [filter.name.trim()],
    );
    if (existing.isNotEmpty) {
      throw SavedFilterException(
        'Un filtre nommé "${filter.name.trim()}" existe déjà.',
      );
    }

    // Vérifie la limite utilisateur
    final userCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM saved_filters WHERE is_preset = 0',
          ),
        ) ??
        0;
    if (userCount >= maxUserFilters) {
      throw SavedFilterException(
        'Limite de $maxUserFilters filtres enregistrés atteinte. '
        'Supprimez-en un pour en créer un nouveau.',
      );
    }

    final toInsert = filter.copyWith(
      isPreset: false,
      createdAt: DateTime.now(),
    );
    final id = await db.insert('saved_filters', toInsert.toMap());
    return toInsert.copyWith(id: id);
  }

  // ── Renommage ────────────────────────────────────────────────────────────

  Future<void> renameFilter(int id, String newName) async {
    validateName(newName);

    final db = await _db;
    final filter = await getFilter(id);
    if (filter == null) {
      throw const SavedFilterException('Filtre introuvable.');
    }
    if (filter.isPreset) {
      throw const SavedFilterException(
        'Les filtres prédéfinis ne peuvent pas être renommés.',
      );
    }

    // Vérifie l'unicité (en excluant le filtre courant)
    final conflict = await db.query(
      'saved_filters',
      where: 'LOWER(name) = LOWER(?) AND id != ?',
      whereArgs: [newName.trim(), id],
    );
    if (conflict.isNotEmpty) {
      throw SavedFilterException(
        'Un filtre nommé "${newName.trim()}" existe déjà.',
      );
    }

    await db.update(
      'saved_filters',
      {'name': newName.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Suppression ──────────────────────────────────────────────────────────

  Future<void> deleteFilter(int id) async {
    final db = await _db;
    final filter = await getFilter(id);
    if (filter == null) return;
    if (filter.isPreset) {
      throw const SavedFilterException(
        'Les filtres prédéfinis ne peuvent pas être supprimés.',
      );
    }
    await db.delete('saved_filters', where: 'id = ?', whereArgs: [id]);
  }

  // ── Application côté client ───────────────────────────────────────────────

  /// Filtre une liste de produits selon les critères du [filter].
  /// La logique d'expiration utilise les lots → on lui passe [batchesMap].
  ///
  /// [batchesMap] : productId → liste de lots (peut être vide si pas chargé).
  static List<StockProduct> applyFilter(
    SavedFilter filter,
    List<StockProduct> products, {
    Map<int, List<StockBatch>> batchesMap = const {},
  }) {
    return products.where((p) {
      // Archivé
      if (filter.filterArchived && !p.archived) return false;
      if (!filter.filterArchived && p.archived) return false;

      // Stock faible
      if (filter.filterLow && !p.isLow) return false;

      // Expire bientôt : au moins un lot du produit expire dans 30 j
      if (filter.filterExpiring) {
        final batches = batchesMap[p.id] ?? [];
        final hasExpiring = batches.any((b) => b.isExpiringSoon() || b.isExpired);
        if (!hasExpiring) return false;
      }

      // Catégorie
      if (filter.category != null && p.category != filter.category) {
        return false;
      }

      // Texte
      if (filter.searchText != null && filter.searchText!.isNotEmpty) {
        final q = filter.searchText!.toLowerCase();
        if (!p.name.toLowerCase().contains(q) &&
            !p.category.label.toLowerCase().contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Compte le nombre de résultats pour un filtre (sans persister).
  static int countResults(
    SavedFilter filter,
    List<StockProduct> products, {
    Map<int, List<StockBatch>> batchesMap = const {},
  }) =>
      applyFilter(filter, products, batchesMap: batchesMap).length;

  // ── Validation ────────────────────────────────────────────────────────────

  static void validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const SavedFilterException('Le nom du filtre ne peut pas être vide.');
    }
    if (trimmed.length > maxNameLength) {
      throw SavedFilterException(
        'Le nom ne peut pas dépasser $maxNameLength caractères '
        '(actuel : ${trimmed.length}).',
      );
    }
  }
}
