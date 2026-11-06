import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Service de gestion de la base de données SQLite locale
class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'agrosmart.db';
  static const int _databaseVersion = 1;

  /// Retourne l'instance de la base de données (singleton)
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialise la base de données
  static Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Crée les tables lors de la première création de la base
  static Future<void> _onCreate(Database db, int version) async {
    // Table Parcelles
    await db.execute('''
      CREATE TABLE parcelles (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        surface REAL NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        type_sol TEXT NOT NULL,
        archivee INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Index pour améliorer les performances
    await db.execute('CREATE INDEX idx_parcelles_archivee ON parcelles(archivee)');
    
    // Tables futures à ajouter par les coéquipiers:
    // - cultures (avec foreign key vers parcelles)
    // - recoltes (avec foreign key vers cultures)
  }

  /// Gère les migrations de version de base de données
  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // Ajoutez ici les migrations futures si nécessaire
  }

  /// Ferme la connexion à la base de données
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Réinitialise complètement la base de données (utile pour les tests)
  static Future<void> reset() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);
    await close();
    await deleteDatabase(path);
    _database = await _initDatabase();
  }
}
