import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/agro_database.dart';
import '../models/irrigation_record.dart';

abstract class IrrigationRepository {
  /// Irrigations of one parcel, most recent first.
  Future<List<IrrigationRecord>> fetchRecords(String parcelId);

  /// Number of irrigations per parcel id.
  Future<Map<String, int>> countRecords();

  /// Inserts the irrigation, or updates it when its id already exists.
  Future<void> saveRecord(IrrigationRecord record);

  Future<void> deleteRecord(IrrigationRecord record);
}

class SqfliteIrrigationRepository implements IrrigationRepository {
  SqfliteIrrigationRepository([AgroDatabase? database])
    : _database = database ?? AgroDatabase.instance;

  final AgroDatabase _database;

  Future<Database> get _db => _database.database;

  static const _table = 'irrigation_records';

  @override
  Future<List<IrrigationRecord>> fetchRecords(String parcelId) async {
    final rows = await (await _db).query(
      _table,
      where: 'parcel_id = ?',
      whereArgs: [parcelId],
      orderBy: 'irrigation_date DESC, start_minutes DESC',
    );
    return rows.map(IrrigationRecord.fromJson).toList();
  }

  @override
  Future<Map<String, int>> countRecords() async {
    final rows = await (await _db).rawQuery(
      'SELECT parcel_id, COUNT(*) AS n FROM $_table GROUP BY parcel_id',
    );
    return {
      for (final row in rows) row['parcel_id'] as String: row['n'] as int,
    };
  }

  @override
  Future<void> saveRecord(IrrigationRecord record) async {
    await (await _db).insert(
      _table,
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteRecord(IrrigationRecord record) async {
    await (await _db).delete(_table, where: 'id = ?', whereArgs: [record.id]);
    await deleteIrrigationPhoto(record.photoPath);
  }
}

/// Copies a picked photo into the app documents folder and returns its path.
Future<String> storeIrrigationPhoto(String sourcePath, String recordId) async {
  final folder = Directory(
    p.join((await getApplicationDocumentsDirectory()).path, 'irrigations'),
  );
  await folder.create(recursive: true);
  final target = p.join(
    folder.path,
    '$recordId-${DateTime.now().millisecondsSinceEpoch}'
    '${p.extension(sourcePath)}',
  );
  return (await File(sourcePath).copy(target)).path;
}

Future<void> deleteIrrigationPhoto(String? path) async {
  if (path == null) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}
