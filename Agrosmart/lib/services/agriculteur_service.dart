import 'package:sqflite/sqflite.dart';

import '../models/agriculteur_model.dart';
import '../models/exploitation_model.dart';
import 'database_helper.dart';

/// SQLite-backed farmer directory (table `agriculteurs`). Every method goes
/// through the same on-disk database, so changes persist across app
/// restarts and are visible from any screen.
class AgriculteurService {
  Future<List<Agriculteur>> getAll({bool includeArchived = false}) async {
    final db = await DatabaseHelper.instance.database;
    await _seedIfEmpty(db);
    final rows = await db.query(
      'agriculteurs',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'last_name, first_name',
    );
    return rows.map(_fromRow).toList();
  }

  Future<Agriculteur?> getById(String id) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'agriculteurs',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<void> ajouter(Agriculteur agriculteur) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'agriculteurs',
      _toRow(agriculteur),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> modifier(Agriculteur agriculteur) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'agriculteurs',
      _toRow(agriculteur),
      where: 'id = ?',
      whereArgs: [agriculteur.id],
    );
  }

  Future<void> basculerArchivage(String id) async {
    final agriculteur = await getById(id);
    if (agriculteur == null) return;
    await modifier(agriculteur.copyWith(archived: !agriculteur.archived));
  }

  Future<void> supprimer(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('agriculteurs', where: 'id = ?', whereArgs: [id]);
  }

  String nouvelId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Rule-based placeholder standing in for the AI synthesis described in
  /// the module spec: it points out whatever in the linked exploitation
  /// needs attention (low stock, upcoming maintenance, production swings).
  /// Used as a fallback when the real Gemini call (see [AiService]) fails.
  String genererSynthese(Agriculteur agriculteur) {
    final exploitation = agriculteur.exploitation;
    if (exploitation == null) {
      return 'No exploitation linked yet — associate one to unlock the AI '
          'summary.';
    }

    final points = <String>[];

    if (exploitation.lowStock) {
      points.add('${exploitation.mainCrop} stock is running low');
    }

    final maintenance = exploitation.nextMaintenance;
    if (maintenance != null) {
      final days = maintenance.difference(DateTime.now()).inDays;
      if (days >= 0) {
        points.add('maintenance is scheduled in $days day(s)');
      }
    }

    final change = exploitation.productionChangePercent;
    if (change.abs() >= 5) {
      final direction = change > 0 ? 'up' : 'down';
      points.add(
        'production is $direction ${change.abs().toStringAsFixed(0)}% '
        'versus the previous period',
      );
    }

    if (points.isEmpty) {
      return '${exploitation.name} looks steady — no attention points '
          'detected right now.';
    }


    return '${exploitation.name}: ${points.join('; ')}.';
  }

  Future<void> _seedIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM agriculteurs'),
        ) ??
        0;
    if (count > 0) return;

    await ajouter(
      Agriculteur(
        id: 'f1',
        firstName: 'Omar',
        lastName: 'Belkacem',
        phone: '+216 20 123 456',
        email: 'omar.belkacem@example.com',
        address: 'Béja, Tunisia',
        exploitation: Exploitation(
          name: 'Green Valley Farm',
          location: 'Béja',
          sizeHectares: 18.5,
          mainCrop: 'Wheat',
          lowStock: true,
          nextMaintenance: DateTime.now().add(const Duration(days: 4)),
          productionChangePercent: -8,
        ),
      ),
    );
    await ajouter(
      Agriculteur(
        id: 'f2',
        firstName: 'Sarra',
        lastName: 'Mansour',
        phone: '+216 55 987 321',
        email: 'sarra.mansour@example.com',
        address: 'Nabeul, Tunisia',
        exploitation: Exploitation(
          name: 'River Plot',
          location: 'Nabeul',
          sizeHectares: 8.2,
          mainCrop: 'Corn',
          nextMaintenance: DateTime.now().add(const Duration(days: 21)),
          productionChangePercent: 12,
        ),
      ),
    );
  }

  Map<String, Object?> _toRow(Agriculteur agriculteur) {
    final exploitation = agriculteur.exploitation;
    return {
      'id': agriculteur.id,
      'first_name': agriculteur.firstName,
      'last_name': agriculteur.lastName,
      'phone': agriculteur.phone,
      'email': agriculteur.email,
      'address': agriculteur.address,
      'archived': agriculteur.archived ? 1 : 0,
      'exploitation_name': exploitation?.name,
      'exploitation_location': exploitation?.location,
      'exploitation_size_hectares': exploitation?.sizeHectares,
      'exploitation_main_crop': exploitation?.mainCrop,
      'exploitation_low_stock':
          exploitation == null ? null : (exploitation.lowStock ? 1 : 0),
      'exploitation_next_maintenance':
          exploitation?.nextMaintenance?.toIso8601String(),
      'exploitation_production_change': exploitation?.productionChangePercent,
    };
  }

  Agriculteur _fromRow(Map<String, Object?> row) {
    final exploitationName = row['exploitation_name'] as String?;
    final exploitation = exploitationName == null
        ? null
        : Exploitation(
            name: exploitationName,
            location: row['exploitation_location'] as String? ?? '',
            sizeHectares:
                (row['exploitation_size_hectares'] as num?)?.toDouble() ?? 0,
            mainCrop: row['exploitation_main_crop'] as String? ?? '',
            lowStock: (row['exploitation_low_stock'] as int? ?? 0) == 1,
            nextMaintenance: row['exploitation_next_maintenance'] == null
                ? null
                : DateTime.parse(
                    row['exploitation_next_maintenance'] as String,
                  ),
            productionChangePercent:
                (row['exploitation_production_change'] as num?)
                    ?.toDouble() ??
                0,
          );

    return Agriculteur(
      id: row['id'] as String,
      firstName: row['first_name'] as String,
      lastName: row['last_name'] as String,
      phone: row['phone'] as String,
      email: row['email'] as String,
      address: row['address'] as String,
      exploitation: exploitation,
      archived: (row['archived'] as int) == 1,
    );
  }
}
