import 'package:sqflite/sqflite.dart';

import '../data/agro_database.dart';
import '../models/maintenance_record.dart';

abstract class MaintenanceRepository {
  /// Entries of one equipment, most recent first.
  Future<List<MaintenanceRecord>> fetchRecords(String materielId);

  /// Every entry of every equipment, oldest first (statistics page).
  Future<List<MaintenanceRecord>> fetchAllRecords();

  /// Number of entries of each type, per equipment id.
  Future<Map<String, Map<MaintenanceRecordType, int>>> countRecords();

  /// Inserts the entry, or updates it when its id already exists.
  Future<void> saveRecord(MaintenanceRecord record);

  Future<void> deleteRecord(MaintenanceRecord record);
}

class SqfliteMaintenanceRepository implements MaintenanceRepository {
  SqfliteMaintenanceRepository([AgroDatabase? database])
    : _database = database ?? AgroDatabase.instance;

  final AgroDatabase _database;

  Future<Database> get _db => _database.database;

  static const _table = 'maintenance_records';

  @override
  Future<List<MaintenanceRecord>> fetchRecords(String materielId) async {
    final rows = await (await _db).query(
      _table,
      where: 'materiel_id = ?',
      whereArgs: [materielId],
      orderBy: 'record_date DESC, rowid DESC',
    );
    return rows.map(MaintenanceRecord.fromJson).toList();
  }

  @override
  Future<List<MaintenanceRecord>> fetchAllRecords() async {
    final rows = await (await _db).query(
      _table,
      orderBy: 'record_date ASC, rowid ASC',
    );
    return rows.map(MaintenanceRecord.fromJson).toList();
  }

  @override
  Future<Map<String, Map<MaintenanceRecordType, int>>> countRecords() async {
    final rows = await (await _db).rawQuery(
      'SELECT materiel_id, type, COUNT(*) AS n FROM $_table '
      'GROUP BY materiel_id, type',
    );
    final counts = <String, Map<MaintenanceRecordType, int>>{};
    for (final row in rows) {
      counts.putIfAbsent(
        row['materiel_id'] as String,
        () => {},
      )[MaintenanceRecordType.fromDb(row['type'] as String)] = row['n'] as int;
    }
    return counts;
  }

  @override
  Future<void> saveRecord(MaintenanceRecord record) async {
    await (await _db).insert(
      _table,
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteRecord(MaintenanceRecord record) async {
    await (await _db).delete(_table, where: 'id = ?', whereArgs: [record.id]);
  }
}
