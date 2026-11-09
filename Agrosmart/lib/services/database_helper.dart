import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens (and lazily creates) the app's local SQLite database.
class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    final path = p.join(directory, 'agrosmart.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE agriculteurs (
            id TEXT PRIMARY KEY,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT NOT NULL,
            address TEXT NOT NULL,
            archived INTEGER NOT NULL,
            exploitation_name TEXT,
            exploitation_location TEXT,
            exploitation_size_hectares REAL,
            exploitation_main_crop TEXT,
            exploitation_low_stock INTEGER,
            exploitation_next_maintenance TEXT,
            exploitation_production_change REAL
          )
        ''');
        await _createUsersTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createUsersTable(db);
        }
      },
    );
  }

  Future<void> _createUsersTable(Database db) => db.execute('''
    CREATE TABLE users (
      email TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      password_salt TEXT NOT NULL
    )
  ''');
}
