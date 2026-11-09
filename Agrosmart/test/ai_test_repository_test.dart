import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_application/data/agro_database.dart';
import 'package:my_application/models/ai_test.dart';
import 'package:my_application/models/drone.dart';
import 'package:my_application/services/ai_test_repository.dart';
import 'package:my_application/services/drone_ai_service.dart';
import 'package:my_application/services/drone_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'saves a test with its images and AI results, then deletes it',
    () async {
      final database = AgroDatabase(path: inMemoryDatabasePath);
      await SqfliteDroneRepository(database).saveDrone(
        const Drone(
          id: 'd1',
          name: 'Falcon',
          brand: 'DJI',
          model: 'Agras',
          type: DroneType.multispectral,
          status: DroneStatus.active,
        ),
      );
      final repository = SqfliteAiTestRepository(database);

      final diagnosis = DiseaseDiagnosis.fromJson({
        'culture': 'Pomme',
        'maladie': 'Apple scab',
        'nom_fr': 'Tavelure',
        'sain': false,
        'confiance': 0.93,
        'traitement': 'Fongicide',
        'fiable': true,
        'predictions': [
          {
            'culture': 'Pomme',
            'maladie': 'Apple scab',
            'nom_fr': 'Tavelure',
            'sain': false,
            'confiance': 0.93,
            'traitement': 'Fongicide',
          },
        ],
      });
      await repository.saveTest(
        AiTest(
          id: 't1',
          name: 'Verger nord',
          date: DateTime(2026, 11, 8),
          droneId: 'd1',
          droneName: 'Falcon',
          images: [
            AiTestImage(
              image: DroneImage(
                name: 'a.jpg',
                bytes: Uint8List.fromList([1, 2]),
              ),
              diagnosis: diagnosis,
            ),
            AiTestImage(
              image: DroneImage(name: 'b.jpg', bytes: Uint8List.fromList([3])),
            ),
          ],
        ),
      );

      final tests = await repository.fetchTests();
      expect(tests, hasLength(1));
      final test = tests.single;
      expect(test.name, 'Verger nord');
      expect(formatDate(test.date), '08/11/2026');
      expect(test.droneName, 'Falcon');
      expect(test.images.map((i) => i.image.name), ['a.jpg', 'b.jpg']);
      expect(test.images.first.image.bytes, [1, 2]);
      expect(test.images.first.diagnosis!.best.frenchName, 'Tavelure');
      expect(test.images.first.diagnosis!.best.confidence, .93);
      expect(test.images.last.diagnosis, isNull);
      expect(test.diseasedCount, 1);

      await repository.deleteTest('t1');
      expect(await repository.fetchTests(), isEmpty);
    },
  );
}
