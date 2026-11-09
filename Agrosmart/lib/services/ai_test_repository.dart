import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../data/agro_database.dart';
import '../models/ai_test.dart';
import 'drone_ai_service.dart';

abstract class AiTestRepository {
  /// Newest test first.
  Future<List<AiTest>> fetchTests();

  Future<void> saveTest(AiTest test);

  Future<void> deleteTest(String id);
}

class SqfliteAiTestRepository implements AiTestRepository {
  SqfliteAiTestRepository([AgroDatabase? database])
    : _database = database ?? AgroDatabase.instance;

  final AgroDatabase _database;

  Future<Database> get _db => _database.database;

  @override
  Future<List<AiTest>> fetchTests() async {
    final db = await _db;
    final tests = await db.query(
      'ai_tests',
      orderBy: 'test_date DESC, created_at DESC',
    );
    final images = await db.query('ai_test_images', orderBy: 'position');
    final byTest = <String, List<AiTestImage>>{};
    for (final row in images) {
      final result = row['result'] as String?;
      byTest
          .putIfAbsent(row['test_id'] as String, () => [])
          .add(
            AiTestImage(
              image: DroneImage(
                name: row['image_name'] as String,
                bytes: row['image'] as Uint8List,
              ),
              diagnosis: result == null
                  ? null
                  : DiseaseDiagnosis.fromJson(
                      jsonDecode(result) as Map<String, dynamic>,
                    ),
            ),
          );
    }
    return [
      for (final row in tests)
        AiTest(
          id: row['id'] as String,
          name: row['name'] as String,
          date: DateTime.parse(row['test_date'] as String),
          droneId: row['drone_id'] as String?,
          droneName: row['drone_name'] as String?,
          images: byTest[row['id']] ?? const [],
        ),
    ];
  }

  @override
  Future<void> saveTest(AiTest test) async {
    await (await _db).transaction((txn) async {
      await txn.insert('ai_tests', {
        'id': test.id,
        'name': test.name,
        'test_date': test.date.toIso8601String(),
        'drone_id': test.droneId,
        'drone_name': test.droneName,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'ai_test_images',
        where: 'test_id = ?',
        whereArgs: [test.id],
      );
      for (var i = 0; i < test.images.length; i++) {
        final item = test.images[i];
        await txn.insert('ai_test_images', {
          'test_id': test.id,
          'position': i,
          'image_name': item.image.name,
          'image': item.image.bytes,
          'result': item.diagnosis == null
              ? null
              : jsonEncode(item.diagnosis!.toJson()),
        });
      }
    });
  }

  @override
  Future<void> deleteTest(String id) async {
    await (await _db).delete('ai_tests', where: 'id = ?', whereArgs: [id]);
  }
}
