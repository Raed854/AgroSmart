import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_application/data/agro_database.dart';
import 'package:my_application/models/maintenance_record.dart';
import 'package:my_application/models/materiel.dart';
import 'package:my_application/screens/maintenance_screen.dart';
import 'package:my_application/services/maintenance_repository.dart';
import 'package:my_application/services/materiel_repository.dart';

final _tractor = Materiel(
  id: 'm1',
  name: 'Tracteur principal',
  category: MaterielCategory.soil,
  brand: 'John Deere',
  model: '5075E',
  serialNumber: 'JD-001',
  purchaseDate: DateTime(2023, 4, 12),
  purchasePrice: 85000,
  condition: MaterielCondition.good,
  status: MaterielStatus.available,
);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('stores entries per equipment and drops them with it', () async {
    final db = AgroDatabase(path: inMemoryDatabasePath);
    final materiels = SqfliteMaterielRepository(db);
    final records = SqfliteMaintenanceRepository(db);
    await materiels.saveMateriel(_tractor);

    await records.saveRecord(
      MaintenanceRecord(
        id: 'r1',
        materielId: 'm1',
        type: MaintenanceRecordType.fuel,
        date: DateTime(2026, 3, 1),
        cost: 120,
        description: 'Gasoil',
        quantity: 60,
      ),
    );
    await records.saveRecord(
      MaintenanceRecord(
        id: 'r2',
        materielId: 'm1',
        type: MaintenanceRecordType.labor,
        date: DateTime(2026, 3, 5),
        cost: 80,
        description: 'Labour',
        quantity: 8,
        workerName: 'Ali',
      ),
    );

    final saved = await records.fetchRecords('m1');
    expect(saved.map((r) => r.id), ['r2', 'r1']); // most recent first
    expect(saved.last.quantity, 60);
    expect(saved.first.workerName, 'Ali');
    expect((await records.countRecords())['m1'], {
      MaintenanceRecordType.fuel: 1,
      MaintenanceRecordType.labor: 1,
    });

    await materiels.deleteMateriel(_tractor);
    expect(await records.fetchRecords('m1'), isEmpty);
  });

  testWidgets('adds a fuel entry from the maintenance page', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final records = _MemoryMaintenanceRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceScreen(
          materielRepository: _MemoryMaterielRepository(),
          maintenanceRepository: records,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tracteur principal'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucune entrée « Carburant »'), findsOneWidget);

    await tester.tap(find.text('Ajouter carburant'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Type de carburant'),
      'Gasoil',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantité (litres)'),
      '50',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Coût (DT)'),
      '100',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Gasoil'), findsOneWidget);
    expect(find.text('50 L'), findsWidgets);
    expect(records.items.single.type, MaintenanceRecordType.fuel);
    expect(records.items.single.cost, 100);

    // The labour tab has its own, still empty, list.
    await tester.tap(find.widgetWithText(Tab, "Main d'œuvre"));
    await tester.pumpAndSettle();
    expect(find.text("Ajouter main d'œuvre"), findsOneWidget);
    expect(
      find.textContaining("Aucune entrée « Main d'œuvre »"),
      findsOneWidget,
    );
  });
}

class _MemoryMaterielRepository implements MaterielRepository {
  @override
  Future<List<Materiel>> fetchMateriels() async => [_tractor];

  @override
  Future<void> saveMateriel(Materiel materiel) async {}

  @override
  Future<void> deleteMateriel(Materiel materiel) async {}
}

class _MemoryMaintenanceRepository implements MaintenanceRepository {
  final items = <MaintenanceRecord>[];

  @override
  Future<List<MaintenanceRecord>> fetchRecords(String materielId) async =>
      items.where((r) => r.materielId == materielId).toList();

  @override
  Future<List<MaintenanceRecord>> fetchAllRecords() async =>
      [...items]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<Map<String, Map<MaintenanceRecordType, int>>> countRecords() async {
    final counts = <String, Map<MaintenanceRecordType, int>>{};
    for (final r in items) {
      final m = counts.putIfAbsent(r.materielId, () => {});
      m[r.type] = (m[r.type] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<void> saveRecord(MaintenanceRecord record) async {
    items.removeWhere((r) => r.id == record.id);
    items.add(record);
  }

  @override
  Future<void> deleteRecord(MaintenanceRecord record) async =>
      items.removeWhere((r) => r.id == record.id);
}
