import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/agro_database.dart';
import '../models/materiel.dart';

abstract class MaterielRepository {
  Future<List<Materiel>> fetchMateriels();

  /// Inserts the equipment, or updates it when its id already exists.
  Future<void> saveMateriel(Materiel materiel);

  Future<void> deleteMateriel(Materiel materiel);
}

class SqfliteMaterielRepository implements MaterielRepository {
  SqfliteMaterielRepository([AgroDatabase? database])
    : _database = database ?? AgroDatabase.instance;

  final AgroDatabase _database;

  Future<Database> get _db => _database.database;

  @override
  Future<List<Materiel>> fetchMateriels() async {
    final rows = await (await _db).query('materiels', orderBy: 'created_at');
    return rows.map(Materiel.fromJson).toList();
  }

  @override
  Future<void> saveMateriel(Materiel materiel) async {
    final db = await _db;
    final updated = await db.update(
      'materiels',
      materiel.toJson(),
      where: 'id = ?',
      whereArgs: [materiel.id],
    );
    if (updated == 0) {
      await db.insert('materiels', {
        ...materiel.toJson(),
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<void> deleteMateriel(Materiel materiel) async {
    await (await _db).delete(
      'materiels',
      where: 'id = ?',
      whereArgs: [materiel.id],
    );
    await deleteMaterielImage(materiel.imagePath);
  }
}

/// Copies a picked photo into the app's folder so it survives the gallery
/// or camera cache being cleared. Returns the new path.
Future<String> storeMaterielImage(String sourcePath, String materielId) async {
  final folder = Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'materiels'),
  );
  await folder.create(recursive: true);
  final target = p.join(
    folder.path,
    '$materielId-${DateTime.now().millisecondsSinceEpoch}'
    '${p.extension(sourcePath)}',
  );
  return (await File(sourcePath).copy(target)).path;
}

Future<void> deleteMaterielImage(String? path) async {
  if (path == null) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}
