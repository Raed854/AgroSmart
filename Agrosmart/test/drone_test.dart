import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_application/data/agro_database.dart';
import 'package:my_application/models/drone.dart';
import 'package:my_application/screens/drones_screen.dart';
import 'package:my_application/services/drone_repository.dart';

class _MemoryDroneRepository implements DroneRepository {
  final drones = <Drone>[];

  @override
  Future<List<Drone>> fetchDrones() async => List.of(drones);

  @override
  Future<void> saveDrone(Drone drone) async {
    final index = drones.indexWhere((d) => d.id == drone.id);
    index == -1 ? drones.add(drone) : drones[index] = drone;
  }

  @override
  Future<void> deleteDrone(Drone drone) async =>
      drones.removeWhere((d) => d.id == drone.id);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('saves, updates and deletes drones in SQLite', () async {
    final repository = SqfliteDroneRepository(
      AgroDatabase(path: inMemoryDatabasePath),
    );
    expect(await repository.fetchDrones(), isEmpty);

    const drone = Drone(
      id: 'd1',
      name: 'AgroDrone X2',
      brand: 'DJI',
      model: 'Mavic 3M',
      type: DroneType.multispectral,
      status: DroneStatus.active,
    );
    await repository.saveDrone(drone);
    await repository.saveDrone(
      const Drone(
        id: 'd1',
        name: 'AgroDrone X2',
        brand: 'DJI',
        model: 'Mavic 3M',
        type: DroneType.multispectral,
        status: DroneStatus.maintenance,
      ),
    );

    final saved = await repository.fetchDrones();
    expect(saved.single.status, DroneStatus.maintenance);
    expect(saved.single.imagePath, isNull);

    await repository.deleteDrone(drone);
    expect(await repository.fetchDrones(), isEmpty);
  });

  testWidgets('creates a drone profile from the form', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final repository = _MemoryDroneRepository();
    await tester.pumpWidget(
      MaterialApp(home: DronesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aucun drone'), findsOneWidget);

    await tester.tap(find.text('Nouveau drone').first);
    await tester.pumpAndSettle();

    // Required fields and type are validated.
    await tester.tap(find.text('Créer le drone'));
    await tester.pump();
    expect(find.text('Champ obligatoire'), findsNWidgets(3));
    expect(find.text('Choisissez un type de drone'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Sprayer 1');
    await tester.enterText(fields.at(1), 'DJI');
    await tester.enterText(fields.at(2), 'Agras T40');
    await tester.tap(find.text('Drone de pulvérisation'));
    await tester.tap(find.text('Hors service'));
    await tester.pump();
    await tester.tap(find.text('Créer le drone'));
    await tester.pumpAndSettle();

    final drone = repository.drones.single;
    expect(drone.name, 'Sprayer 1');
    expect(drone.type, DroneType.spraying);
    expect(drone.status, DroneStatus.outOfService);
    expect(find.text('Sprayer 1'), findsOneWidget);
    expect(find.text('DJI · Agras T40'), findsOneWidget);
  });
}
