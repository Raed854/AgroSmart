import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite database (sqflite). It starts empty: every parcel, mission
/// and drone is created by the user.
class AgroDatabase {
  AgroDatabase({this.path});

  static final instance = AgroDatabase();

  static const _fileName = 'agrosmart.db';

  /// 2: adds the `drones` table.
  /// 3: removes the demo parcels that older versions seeded.
  /// 4: adds `parcel_drones`, the drones responsible for each parcel.
  /// 5: adds `ai_tests` and `ai_test_images`, the saved Drone AI tests.
  /// 6: adds `materiels`, the farm equipment.
  /// 7: adds `maintenance_records`, fuel, maintenance and labour per equipment.
  /// 8: adds `irrigation_records`, the irrigations of each parcel.
  /// 9: adds `irrigation_plans`, the last AI irrigation planning per parcel.
  static const _version = 9;

  /// Ids of the demo parcels seeded by versions 1 and 2.
  static const _demoParcelIds = ['parcel-a', 'parcel-b'];

  /// Overrides the database file, e.g. `inMemoryDatabasePath` in tests.
  final String? path;
  Database? _database;

  Future<Database> get database async => _database ??= await openDatabase(
    path ?? join(await getDatabasesPath(), _fileName),
    version: _version,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, _) async {
      await _createTables(db);
      await _createDroneTable(db);
      await _createParcelDronesTable(db);
      await _createAiTestTables(db);
      await _createMaterielTable(db);
      await _createMaintenanceTable(db);
      await _createIrrigationTable(db);
      await _createIrrigationPlanTable(db);
    },
    onUpgrade: (db, oldVersion, _) async {
      if (oldVersion < 2) await _createDroneTable(db);
      if (oldVersion < 3) {
        // Missions, analyses, zones and anomalies follow via ON DELETE CASCADE.
        await db.delete(
          'parcels',
          where:
              'id IN (${List.filled(_demoParcelIds.length, '?').join(', ')})',
          whereArgs: _demoParcelIds,
        );
      }
      if (oldVersion < 4) await _createParcelDronesTable(db);
      if (oldVersion < 5) await _createAiTestTables(db);
      if (oldVersion < 6) await _createMaterielTable(db);
      if (oldVersion < 7) await _createMaintenanceTable(db);
      if (oldVersion < 8) await _createIrrigationTable(db);
      if (oldVersion < 9) await _createIrrigationPlanTable(db);
    },
  );

  /// Last AI irrigation planning of each parcel, stored as JSON.
  Future<void> _createIrrigationPlanTable(Database db) => db.execute('''
      CREATE TABLE irrigation_plans (
        parcel_id TEXT PRIMARY KEY REFERENCES parcels(id) ON DELETE CASCADE,
        plan TEXT NOT NULL,
        generated_at TEXT NOT NULL
      )''');

  /// Irrigations of each parcel.
  Future<void> _createIrrigationTable(Database db) async {
    await db.execute('''
      CREATE TABLE irrigation_records (
        id TEXT PRIMARY KEY,
        parcel_id TEXT NOT NULL REFERENCES parcels(id) ON DELETE CASCADE,
        irrigation_date TEXT NOT NULL,
        start_minutes INTEGER NOT NULL,
        water_source TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        method TEXT NOT NULL,
        humidity_before REAL,
        humidity_after REAL,
        electricity_kwh REAL,
        cost REAL NOT NULL,
        photo_path TEXT
      )''');
    await db.execute(
      'CREATE INDEX irrigation_records_parcel '
      'ON irrigation_records(parcel_id, irrigation_date)',
    );
  }

  /// Dated fuel, maintenance and labour entries of an equipment.
  Future<void> _createMaintenanceTable(Database db) async {
    await db.execute('''
      CREATE TABLE maintenance_records (
        id TEXT PRIMARY KEY,
        materiel_id TEXT NOT NULL REFERENCES materiels(id) ON DELETE CASCADE,
        type TEXT NOT NULL,
        record_date TEXT NOT NULL,
        cost REAL NOT NULL,
        description TEXT NOT NULL,
        quantity REAL,
        worker_name TEXT
      )''');
    await db.execute(
      'CREATE INDEX maintenance_records_materiel '
      'ON maintenance_records(materiel_id, type, record_date)',
    );
  }

  /// Farm equipment (matériel agricole).
  Future<void> _createMaterielTable(Database db) => db.execute('''
      CREATE TABLE materiels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        serial_number TEXT NOT NULL,
        purchase_date TEXT NOT NULL,
        purchase_price REAL NOT NULL,
        condition TEXT NOT NULL,
        status TEXT NOT NULL,
        image_path TEXT,
        created_at TEXT NOT NULL
      )''');

  /// A Drone AI test: its name, date, drone and the analysed images.
  Future<void> _createAiTestTables(Database db) async {
    await db.execute('''
      CREATE TABLE ai_tests (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        test_date TEXT NOT NULL,
        drone_id TEXT REFERENCES drones(id) ON DELETE SET NULL,
        drone_name TEXT,
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE ai_test_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        test_id TEXT NOT NULL REFERENCES ai_tests(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        image_name TEXT NOT NULL,
        image BLOB NOT NULL,
        result TEXT
      )''');
  }

  /// Many-to-many link: a parcel has one or more responsible drones.
  Future<void> _createParcelDronesTable(Database db) => db.execute('''
      CREATE TABLE parcel_drones (
        parcel_id TEXT NOT NULL REFERENCES parcels(id) ON DELETE CASCADE,
        drone_id TEXT NOT NULL REFERENCES drones(id) ON DELETE CASCADE,
        PRIMARY KEY (parcel_id, drone_id)
      )''');

  Future<void> _createDroneTable(Database db) => db.execute('''
      CREATE TABLE drones (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        image_path TEXT,
        created_at TEXT NOT NULL
      )''');

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE parcels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        crop_type TEXT NOT NULL,
        surface_ha REAL NOT NULL,
        boundary TEXT NOT NULL,
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE missions (
        id TEXT PRIMARY KEY,
        parcel_id TEXT NOT NULL REFERENCES parcels(id) ON DELETE CASCADE,
        label TEXT NOT NULL,
        flown_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE analyses (
        mission_id TEXT PRIMARY KEY
          REFERENCES missions(id) ON DELETE CASCADE,
        overall_health INTEGER NOT NULL,
        healthy_percent INTEGER NOT NULL,
        warning_percent INTEGER NOT NULL,
        critical_percent INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE zones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mission_id TEXT NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
        status TEXT NOT NULL,
        points TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE anomalies (
        id TEXT PRIMARY KEY,
        mission_id TEXT NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        severity TEXT NOT NULL,
        confidence REAL NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        detected_at TEXT NOT NULL,
        description TEXT NOT NULL,
        recommendation TEXT NOT NULL
      )''');
  }
}
