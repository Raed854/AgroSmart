import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/agro_database.dart';
import '../models/drone.dart';
import '../models/parcel_health.dart';
import 'parcel_health_repository.dart';

class SqfliteParcelHealthRepository implements ParcelHealthRepository {
  SqfliteParcelHealthRepository([AgroDatabase? database])
    : _database = database ?? AgroDatabase.instance;

  final AgroDatabase _database;

  Future<Database> get _db => _database.database;

  @override
  Future<List<Parcel>> fetchParcels() async {
    final rows = await (await _db).query('parcels', orderBy: 'created_at');
    return rows
        .map(
          (row) => Parcel.fromJson({
            ...row,
            'boundary': jsonDecode(row['boundary'] as String),
          }),
        )
        .toList();
  }

  @override
  Future<List<DroneMission>> fetchMissions(String parcelId) async {
    final rows = await (await _db).query(
      'missions',
      where: 'parcel_id = ?',
      whereArgs: [parcelId],
      orderBy: 'flown_at DESC',
    );
    return rows.map(DroneMission.fromJson).toList();
  }

  @override
  Future<MissionAnalysis> fetchMissionAnalysis(String missionId) async {
    final db = await _db;
    final summary = await db.query(
      'analyses',
      where: 'mission_id = ?',
      whereArgs: [missionId],
    );
    if (summary.isEmpty) {
      throw StateError('No AI analysis stored for mission $missionId');
    }
    final zones = await db.query(
      'zones',
      where: 'mission_id = ?',
      whereArgs: [missionId],
      orderBy: 'id',
    );
    final anomalies = await db.query(
      'anomalies',
      where: 'mission_id = ?',
      whereArgs: [missionId],
      orderBy: 'id',
    );

    return MissionAnalysis.fromJson({
      ...summary.single,
      'zones': [
        for (final zone in zones)
          {...zone, 'points': jsonDecode(zone['points'] as String)},
      ],
      'anomalies': anomalies,
    });
  }

  @override
  Future<void> saveParcel(Parcel parcel) async {
    final db = await _db;
    final values = {
      ...parcel.toJson(),
      'boundary': jsonEncode(parcel.toJson()['boundary']),
    };
    // Update first so an edited parcel keeps its created_at and its missions
    // (REPLACE would delete the row and cascade to the missions).
    final updated = await db.update(
      'parcels',
      values,
      where: 'id = ?',
      whereArgs: [parcel.id],
    );
    if (updated == 0) {
      await db.insert('parcels', {
        ...values,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<void> deleteParcel(String parcelId) async {
    await (await _db).delete('parcels', where: 'id = ?', whereArgs: [parcelId]);
  }

  @override
  Future<void> saveMissionAnalysis(
    DroneMission mission,
    MissionAnalysis analysis,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('missions', mission.toJson());
      await txn.insert('analyses', {
        'mission_id': mission.id,
        'overall_health': analysis.overallHealth,
        'healthy_percent': analysis.healthyPercent,
        'warning_percent': analysis.warningPercent,
        'critical_percent': analysis.criticalPercent,
      });
      for (final zone in analysis.zones) {
        await txn.insert('zones', {
          'mission_id': mission.id,
          'status': zone.status.apiValue,
          'points': jsonEncode(zone.toJson()['points']),
        });
      }
      for (final anomaly in analysis.anomalies) {
        await txn.insert('anomalies', {
          ...anomaly.toJson(),
          'mission_id': mission.id,
        });
      }
    });
  }

  @override
  Future<List<Drone>> fetchDrones() async {
    final rows = await (await _db).query(
      'drones',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Drone.fromJson).toList();
  }

  @override
  Future<Set<String>> fetchParcelDroneIds(String parcelId) async {
    final rows = await (await _db).query(
      'parcel_drones',
      columns: ['drone_id'],
      where: 'parcel_id = ?',
      whereArgs: [parcelId],
    );
    return {for (final row in rows) row['drone_id'] as String};
  }

  @override
  Future<void> setParcelDrones(String parcelId, Set<String> droneIds) async {
    await (await _db).transaction((txn) async {
      await txn.delete(
        'parcel_drones',
        where: 'parcel_id = ?',
        whereArgs: [parcelId],
      );
      for (final droneId in droneIds) {
        await txn.insert('parcel_drones', {
          'parcel_id': parcelId,
          'drone_id': droneId,
        });
      }
    });
  }
}
