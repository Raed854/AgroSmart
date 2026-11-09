import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_application/data/agro_database.dart';

import 'support/mock_parcel_health_data.dart';

import 'package:my_application/models/drone.dart';
import 'package:my_application/models/parcel_health.dart';
import 'package:my_application/services/drone_repository.dart';
import 'package:my_application/services/sqflite_parcel_health_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'starts empty, then reads, saves and deletes parcels in SQLite',
    () async {
      final repository = SqfliteParcelHealthRepository(
        AgroDatabase(path: inMemoryDatabasePath),
      );

      // No static data: a new database is empty.
      expect(await repository.fetchParcels(), isEmpty);

      for (final parcel in mockParcels) {
        await repository.saveParcel(parcel);
      }
      for (final mission in mockMissions) {
        await repository.saveMissionAnalysis(
          mission,
          mockAnalyses[mission.id]!,
        );
      }

      final parcels = await repository.fetchParcels();
      expect(parcels.map((p) => p.name), ['Tomato Field A', 'Pepper Field B']);
      expect(parcels.first.boundary, tomatoFieldA.boundary);

      final missions = await repository.fetchMissions('parcel-a');
      expect(missions.first.id, 'mission-a1');

      final analysis = await repository.fetchMissionAnalysis('mission-a1');
      expect(analysis.overallHealth, 78);
      expect(analysis.anomalies, hasLength(8));
      expect(analysis.zones, hasLength(4));
      expect(analysis.anomalies.first.type, AnomalyType.disease);

      // Editing keeps the parcel's missions.
      await repository.saveParcel(
        Parcel(
          id: 'parcel-a',
          name: 'Tomato Field A (edited)',
          cropType: 'Tomatoes',
          surfaceHectares: 2.6,
          boundary: tomatoFieldA.boundary,
        ),
      );
      expect(
        (await repository.fetchParcels()).first.name,
        'Tomato Field A (edited)',
      );
      expect(await repository.fetchMissions('parcel-a'), hasLength(3));

      // Deleting cascades to missions.
      await repository.deleteParcel('parcel-a');
      expect(await repository.fetchParcels(), hasLength(1));
      expect(await repository.fetchMissions('parcel-a'), isEmpty);
    },
  );

  test('assigns one or more drones to a parcel', () async {
    final database = AgroDatabase(path: inMemoryDatabasePath);
    final parcels = SqfliteParcelHealthRepository(database);
    final drones = SqfliteDroneRepository(database);

    await parcels.saveParcel(tomatoFieldA);
    for (final (id, name) in [('d1', 'Faucon'), ('d2', 'Aigle')]) {
      await drones.saveDrone(
        Drone(
          id: id,
          name: name,
          brand: 'DJI',
          model: 'Agras',
          type: DroneType.spraying,
          status: DroneStatus.active,
        ),
      );
    }

    expect((await parcels.fetchDrones()).map((d) => d.name), [
      'Aigle',
      'Faucon',
    ]);
    expect(await parcels.fetchParcelDroneIds(tomatoFieldA.id), isEmpty);

    await parcels.setParcelDrones(tomatoFieldA.id, {'d1', 'd2'});
    expect(await parcels.fetchParcelDroneIds(tomatoFieldA.id), {'d1', 'd2'});

    await parcels.setParcelDrones(tomatoFieldA.id, {'d2'});
    expect(await parcels.fetchParcelDroneIds(tomatoFieldA.id), {'d2'});

    // Deleting a drone removes its assignment.
    final aigle = (await drones.fetchDrones()).firstWhere((d) => d.id == 'd2');
    await drones.deleteDrone(aigle);
    expect(await parcels.fetchParcelDroneIds(tomatoFieldA.id), isEmpty);
  });
}
