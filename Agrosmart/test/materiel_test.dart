import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:my_application/data/agro_database.dart';
import 'package:my_application/models/materiel.dart';
import 'package:my_application/screens/materiels_screen.dart';
import 'package:my_application/services/materiel_repository.dart';

class _MemoryMaterielRepository implements MaterielRepository {
  final materiels = <Materiel>[];

  @override
  Future<List<Materiel>> fetchMateriels() async => List.of(materiels);

  @override
  Future<void> saveMateriel(Materiel materiel) async {
    final index = materiels.indexWhere((m) => m.id == materiel.id);
    index == -1 ? materiels.add(materiel) : materiels[index] = materiel;
  }

  @override
  Future<void> deleteMateriel(Materiel materiel) async =>
      materiels.removeWhere((m) => m.id == materiel.id);
}

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

  test('saves, updates and deletes equipment in SQLite', () async {
    final repository = SqfliteMaterielRepository(
      AgroDatabase(path: inMemoryDatabasePath),
    );
    expect(await repository.fetchMateriels(), isEmpty);

    await repository.saveMateriel(_tractor);
    await repository.saveMateriel(
      Materiel.fromJson({
        ..._tractor.toJson(),
        'status': MaterielStatus.maintenance.dbValue,
      }),
    );

    final saved = (await repository.fetchMateriels()).single;
    expect(saved.name, 'Tracteur principal');
    expect(saved.category, MaterielCategory.soil);
    expect(saved.purchaseDate, DateTime(2023, 4, 12));
    expect(saved.purchasePrice, 85000);
    expect(saved.status, MaterielStatus.maintenance);

    await repository.deleteMateriel(saved);
    expect(await repository.fetchMateriels(), isEmpty);
  });

  Future<void> pumpScreen(WidgetTester tester, MaterielRepository repo) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MaterielsScreen(
          repository: repo,
          storeImage: (path, _) async => path,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the empty form shows the required-field errors', (tester) async {
    await pumpScreen(tester, _MemoryMaterielRepository());

    expect(find.text('Aucun matériel enregistré pour le moment'), findsOne);
    await tester.tap(find.text('Enregistrer le matériel'));
    await tester.pumpAndSettle();

    expect(find.text('Champ obligatoire'), findsWidgets);
    expect(find.text('Choisissez une catégorie'), findsOneWidget);
    expect(find.text("Choisissez la date d'achat"), findsOneWidget);
  });

  testWidgets('tapping a saved name opens it to modify then delete it', (
    tester,
  ) async {
    final repo = _MemoryMaterielRepository()..materiels.add(_tractor);
    await pumpScreen(tester, repo);

    await tester.tap(find.text('Tracteur principal'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    expect(find.text('12/04/2023'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tracteur principal'),
      'Tracteur 2',
    );
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(repo.materiels.single.name, 'Tracteur 2');
    expect(find.text('Tracteur 2'), findsOneWidget);

    await tester.tap(find.text('Tracteur 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(repo.materiels, isEmpty);
    expect(find.text('Aucun matériel enregistré pour le moment'), findsOne);
  });
}
