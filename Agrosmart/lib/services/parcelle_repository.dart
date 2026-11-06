import 'package:sqflite/sqflite.dart';

import '../models/parcelle_model.dart';
import 'database_service.dart';

/// Repository pour gérer les opérations CRUD sur les parcelles
class ParcelleRepository {
  static const String _tableName = 'parcelles';

  /// Récupère toutes les parcelles (non archivées par défaut)
  Future<List<ParcelleModel>> getAll({bool includeArchived = false}) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: includeArchived ? null : 'archivee = ?',
      whereArgs: includeArchived ? null : [0],
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => ParcelleModel.fromJson(map)).toList();
  }

  /// Récupère une parcelle par son ID
  Future<ParcelleModel?> getById(String id) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return ParcelleModel.fromJson(maps.first);
  }

  /// Insère une nouvelle parcelle
  Future<void> insert(ParcelleModel parcelle) async {
    final db = await DatabaseService.database;
    await db.insert(
      _tableName,
      parcelle.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Met à jour une parcelle existante
  Future<void> update(ParcelleModel parcelle) async {
    final db = await DatabaseService.database;
    await db.update(
      _tableName,
      parcelle.toJson(),
      where: 'id = ?',
      whereArgs: [parcelle.id],
    );
  }

  /// Archive une parcelle (soft delete)
  Future<void> archive(String id) async {
    final db = await DatabaseService.database;
    await db.update(
      _tableName,
      {'archivee': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Supprime définitivement une parcelle
  Future<void> delete(String id) async {
    final db = await DatabaseService.database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Compte le nombre de parcelles non archivées
  Future<int> count({bool includeArchived = false}) async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName ${includeArchived ? '' : 'WHERE archivee = 0'}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Recherche des parcelles par nom
  Future<List<ParcelleModel>> search(String query,
      {bool includeArchived = false}) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: includeArchived
          ? 'nom LIKE ?'
          : 'nom LIKE ? AND archivee = 0',
      whereArgs: ['%$query%'],
      orderBy: 'nom ASC',
    );

    return maps.map((map) => ParcelleModel.fromJson(map)).toList();
  }
}
