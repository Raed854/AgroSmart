import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/agro_database.dart';
import '../models/irrigation_plan.dart';

/// Last AI planning of each parcel, so it shows instantly and is only
/// recomputed when its inputs change.
abstract class IrrigationPlanRepository {
  Future<IrrigationPlan?> fetchPlan(String parcelId);

  Future<void> savePlan(IrrigationPlan plan);
}

class SqfliteIrrigationPlanRepository implements IrrigationPlanRepository {
  SqfliteIrrigationPlanRepository([AgroDatabase? database])
    : _database = database ?? AgroDatabase.instance;

  final AgroDatabase _database;

  static const _table = 'irrigation_plans';

  @override
  Future<IrrigationPlan?> fetchPlan(String parcelId) async {
    final rows = await (await _database.database).query(
      _table,
      where: 'parcel_id = ?',
      whereArgs: [parcelId],
    );
    if (rows.isEmpty) return null;
    try {
      return IrrigationPlan.fromJson(
        jsonDecode(rows.first['plan'] as String) as Map<String, dynamic>,
      );
    } catch (_) {
      return null; // Unreadable old format: it will simply be regenerated.
    }
  }

  @override
  Future<void> savePlan(IrrigationPlan plan) async {
    await (await _database.database).insert(_table, {
      'parcel_id': plan.parcelId,
      'plan': jsonEncode(plan.toJson()),
      'generated_at': plan.generatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

class InMemoryIrrigationPlanRepository implements IrrigationPlanRepository {
  final _plans = <String, IrrigationPlan>{};

  @override
  Future<IrrigationPlan?> fetchPlan(String parcelId) async => _plans[parcelId];

  @override
  Future<void> savePlan(IrrigationPlan plan) async =>
      _plans[plan.parcelId] = plan;
}
