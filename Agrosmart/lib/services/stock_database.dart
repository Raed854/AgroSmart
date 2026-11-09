// Initialisation et migrations de la base de données SQLite – module 3.6

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class StockDatabase {
  StockDatabase._();
  static final StockDatabase instance = StockDatabase._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'agrosmart_stocks.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Fonctionnalité 2 : favoris
      await db.execute(
        'ALTER TABLE products ADD COLUMN favorite INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      // Fonctionnalité 3 : filtres enregistrés
      await db.execute('''
        CREATE TABLE IF NOT EXISTS saved_filters (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          name         TEXT    NOT NULL UNIQUE,
          category     TEXT,
          filter_low   INTEGER NOT NULL DEFAULT 0,
          filter_expiring INTEGER NOT NULL DEFAULT 0,
          filter_archived INTEGER NOT NULL DEFAULT 0,
          search_text  TEXT,
          is_preset    INTEGER NOT NULL DEFAULT 0,
          created_at   TEXT    NOT NULL
        )
      ''');
      // Insère les 3 filtres prédéfinis
      final now = DateTime.now().toIso8601String();
      await db.insert('saved_filters', {
        'name': 'Stock faible',
        'filter_low': 1,
        'filter_expiring': 0,
        'filter_archived': 0,
        'is_preset': 1,
        'created_at': now,
      });
      await db.insert('saved_filters', {
        'name': 'Expire bientôt',
        'filter_low': 0,
        'filter_expiring': 1,
        'filter_archived': 0,
        'is_preset': 1,
        'created_at': now,
      });
      await db.insert('saved_filters', {
        'name': 'Archivés',
        'filter_low': 0,
        'filter_expiring': 0,
        'filter_archived': 1,
        'is_preset': 1,
        'created_at': now,
      });
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        name         TEXT    NOT NULL,
        category     TEXT    NOT NULL,
        unit         TEXT    NOT NULL,
        total_quantity REAL  NOT NULL DEFAULT 0,
        min_threshold  REAL  NOT NULL DEFAULT 0,
        notes        TEXT,
        archived     INTEGER NOT NULL DEFAULT 0,
        favorite     INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT    NOT NULL,
        updated_at   TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE batches (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id   INTEGER NOT NULL REFERENCES products(id),
        batch_number TEXT    NOT NULL,
        quantity     REAL    NOT NULL DEFAULT 0,
        expiry_date  TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_movements (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id),
        batch_id   INTEGER REFERENCES batches(id),
        type       TEXT    NOT NULL,
        quantity   REAL    NOT NULL,
        date       TEXT    NOT NULL,
        note       TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE saved_filters (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        name             TEXT    NOT NULL UNIQUE,
        category         TEXT,
        filter_low       INTEGER NOT NULL DEFAULT 0,
        filter_expiring  INTEGER NOT NULL DEFAULT 0,
        filter_archived  INTEGER NOT NULL DEFAULT 0,
        search_text      TEXT,
        is_preset        INTEGER NOT NULL DEFAULT 0,
        created_at       TEXT    NOT NULL
      )
    ''');
    // Filtres prédéfinis
    final now = DateTime.now().toIso8601String();
    await db.insert('saved_filters', {
      'name': 'Stock faible',
      'filter_low': 1,
      'filter_expiring': 0,
      'filter_archived': 0,
      'is_preset': 1,
      'created_at': now,
    });
    await db.insert('saved_filters', {
      'name': 'Expire bientôt',
      'filter_low': 0,
      'filter_expiring': 1,
      'filter_archived': 0,
      'is_preset': 1,
      'created_at': now,
    });
    await db.insert('saved_filters', {
      'name': 'Archivés',
      'filter_low': 0,
      'filter_expiring': 0,
      'filter_archived': 1,
      'is_preset': 1,
      'created_at': now,
    });
  }

  /// Ferme la connexion (utile pour les tests).
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
