import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_seeder.dart';
import 'schema.dart';

class AppDatabase {
  AppDatabase._({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactoryFfi,
      _configuredPath = databasePath;

  static final AppDatabase instance = AppDatabase._();

  factory AppDatabase.forTesting({
    required DatabaseFactory factory,
    required String databasePath,
  }) => AppDatabase._(factory: factory, databasePath: databasePath);

  final DatabaseFactory _factory;
  final String? _configuredPath;
  Database? _database;
  String? _activePath;

  Database get database {
    final value = _database;
    if (value == null) throw StateError('Database is not initialized.');
    return value;
  }

  String get databasePath {
    final value = _activePath;
    if (value == null) throw StateError('Database is not initialized.');
    return value;
  }

  DatabaseFactory get factory => _factory;

  Future<void> initialize() async {
    if (_database != null) return;
    final path = _configuredPath ?? await _productionDatabasePath();
    _activePath = path;
    _database = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.currentVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
    await DatabaseSeeder.seed(database);
  }

  Future<String> _productionDatabasePath() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final databaseDirectory = Directory(
      p.join(supportDirectory.path, 'EuroTechBilling'),
    );
    await databaseDirectory.create(recursive: true);
    return p.join(databaseDirectory.path, 'euro_tech_billing.sqlite');
  }

  Future<void> _migrate(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1 && newVersion >= 1) {
      final batch = db.batch();
      for (final statement in DatabaseSchema.createStatements) {
        batch.execute(statement);
      }
      await batch.commit(noResult: true);
      await DatabaseSeeder.seed(db);
    }
    if (oldVersion < 2 && newVersion >= 2) {
      final batch = db.batch();
      for (final statement in DatabaseSchema.migration2Statements) {
        batch.execute(statement);
      }
      await batch.commit(noResult: true);
      final rows = await db.rawQuery(
        "SELECT COALESCE(MAX(CAST(SUBSTR(invoice_number, 4) AS INTEGER)), 0) AS value "
        "FROM invoices WHERE invoice_number GLOB 'ET-[0-9]*'",
      );
      final value = rows.single['value'] as int? ?? 0;
      await db.insert('app_settings', {
        'key': 'invoice_sequence',
        'value': value.toString(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (oldVersion < 3 && newVersion >= 3) {
      final batch = db.batch();
      for (final statement in DatabaseSchema.migration3Statements) {
        batch.execute(statement);
      }
      await batch.commit(noResult: true);
    }
    if (oldVersion < 4 && newVersion >= 4) {
      final batch = db.batch();
      for (final statement in DatabaseSchema.migration4Statements) {
        batch.execute(statement);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<T> financialTransaction<T>(
    Future<T> Function(Transaction transaction) action,
  ) => database.transaction(action);

  Future<void> close() async {
    final value = _database;
    _database = null;
    await value?.close();
  }

  Future<void> reopen() async {
    await close();
    await initialize();
  }
}
