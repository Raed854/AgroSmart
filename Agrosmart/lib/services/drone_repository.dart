import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/agro_database.dart';
import '../models/drone.dart';

abstract class DroneRepository {
  Future<List<Drone>> fetchDrones();

  /// Inserts the drone, or updates it when its id already exists.
  Future<void> saveDrone(Drone drone);

  Future<void> deleteDrone(Drone drone);
}

class SqfliteDroneRepository implements DroneRepository {
  SqfliteDroneRepository([AgroDatabase? database])
    : _database = database ?? AgroDatabase.instance;

  final AgroDatabase _database;

  Future<Database> get _db => _database.database;

  @override
  Future<List<Drone>> fetchDrones() async {
    final rows = await (await _db).query('drones', orderBy: 'created_at');
    return rows.map(Drone.fromJson).toList();
  }

  @override
  Future<void> saveDrone(Drone drone) async {
    final db = await _db;
    final updated = await db.update(
      'drones',
      drone.toJson(),
      where: 'id = ?',
      whereArgs: [drone.id],
    );
    if (updated == 0) {
      await db.insert('drones', {
        ...drone.toJson(),
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<void> deleteDrone(Drone drone) async {
    await (await _db).delete('drones', where: 'id = ?', whereArgs: [drone.id]);
    await deleteDroneImage(drone.imagePath);
  }
}

/// Copies a picked photo into the app's folder so it survives the gallery
/// or camera cache being cleared. Returns the new path.
Future<String> storeDroneImage(String sourcePath, String droneId) async {
  final folder = Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'drones'),
  );
  await folder.create(recursive: true);
  final target = p.join(
    folder.path,
    '$droneId-${DateTime.now().millisecondsSinceEpoch}'
    '${p.extension(sourcePath)}',
  );
  return (await File(sourcePath).copy(target)).path;
}

Future<void> deleteDroneImage(String? path) async {
  if (path == null) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}
