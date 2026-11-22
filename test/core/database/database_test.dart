import 'dart:io';

import 'package:eurotechbilling/core/database/app_database.dart';
import 'package:eurotechbilling/core/database/database_seeder.dart';
import 'package:eurotechbilling/core/database/schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporaryDirectory;
  late AppDatabase appDatabase;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'euro_tech_db_test_',
    );
    appDatabase = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: p.join(temporaryDirectory.path, 'test.sqlite'),
    );
    await appDatabase.initialize();
  });

  tearDown(() async {
    await appDatabase.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('initializes all required tables and enables foreign keys', () async {
    final tables = await appDatabase.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']).toSet();
    expect(
      names,
      containsAll(<String>{
        'company_settings',
        'products',
        'customers',
        'invoices',
        'invoice_items',
        'payments',
        'audit_logs',
        'app_settings',
      }),
    );
    final foreignKeys = await appDatabase.database.rawQuery(
      'PRAGMA foreign_keys',
    );
    expect(foreignKeys.single.values.single, 1);
  });

  test('seed operation is idempotent and preserves operator prices', () async {
    final products = await appDatabase.database.query('products');
    expect(products, hasLength(7));
    final id = products.first['id']! as int;
    await appDatabase.database.update(
      'products',
      {'default_price_minor': 99900},
      where: 'id = ?',
      whereArgs: [id],
    );

    await DatabaseSeeder.seed(appDatabase.database);

    final afterSeed = await appDatabase.database.query('products');
    expect(afterSeed, hasLength(7));
    expect(
      afterSeed.singleWhere((row) => row['id'] == id)['default_price_minor'],
      99900,
    );
  });

  test('enforces financial and foreign-key constraints', () async {
    final now = DateTime.now().toUtc().toIso8601String();
    expect(
      () => appDatabase.database.insert('payments', {
        'invoice_id': 99999,
        'amount_minor': 100,
        'payment_method': 'cash',
        'payment_date': now,
        'created_at': now,
        'updated_at': now,
      }),
      throwsA(anything),
    );
    expect(
      () => appDatabase.database.insert('products', {
        'name': 'Invalid',
        'unit': 'piece',
        'default_price_minor': -1,
        'requires_custom_price': 0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      }),
      throwsA(anything),
    );
  });

  test('records and retains the current schema version', () async {
    expect(
      await appDatabase.database.getVersion(),
      DatabaseSchema.currentVersion,
    );
    await appDatabase.close();
    await appDatabase.initialize();
    expect(
      await appDatabase.database.getVersion(),
      DatabaseSchema.currentVersion,
    );
    expect(await appDatabase.database.query('products'), hasLength(7));
  });

  test(
    'migrates an existing version-zero database without resetting it',
    () async {
      final legacyPath = p.join(temporaryDirectory.path, 'legacy.sqlite');
      final legacy = await databaseFactoryFfi.openDatabase(legacyPath);
      await legacy.execute('CREATE TABLE legacy_marker (value TEXT NOT NULL)');
      await legacy.insert('legacy_marker', {'value': 'preserved'});
      await legacy.close();

      final migrated = AppDatabase.forTesting(
        factory: databaseFactoryFfi,
        databasePath: legacyPath,
      );
      await migrated.initialize();

      expect(
        await migrated.database.getVersion(),
        DatabaseSchema.currentVersion,
      );
      expect(await migrated.database.query('products'), hasLength(7));
      expect(
        (await migrated.database.query('legacy_marker')).single['value'],
        'preserved',
      );
      await migrated.close();
    },
  );

  test('migrates a Milestone 1 database and preserves rows', () async {
    final legacyPath = p.join(temporaryDirectory.path, 'milestone1.sqlite');
    final legacy = await databaseFactoryFfi.openDatabase(
      legacyPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          final batch = db.batch();
          for (final statement in DatabaseSchema.createStatements) {
            batch.execute(statement);
          }
          await batch.commit(noResult: true);
          await DatabaseSeeder.seed(db);
        },
      ),
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final customerId = await legacy.insert('customers', {
      'name': 'Preserved Customer',
      'phone': '',
      'address': '',
      'notes': '',
      'created_at': now,
      'updated_at': now,
    });
    await legacy.close();

    final migrated = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: legacyPath,
    );
    await migrated.initialize();

    expect(await migrated.database.getVersion(), DatabaseSchema.currentVersion);
    expect(
      (await migrated.database.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
      )).single['name'],
      'Preserved Customer',
    );
    expect(
      (await migrated.database.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['invoice_sequence'],
      )).single['value'],
      '0',
    );
    await migrated.close();
  });

  test('migrates a Milestone 2 database through the current schema', () async {
    final legacyPath = p.join(temporaryDirectory.path, 'milestone2.sqlite');
    final legacy = await databaseFactoryFfi.openDatabase(
      legacyPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          final batch = db.batch();
          for (final statement in DatabaseSchema.createStatements) {
            batch.execute(statement);
          }
          await batch.commit(noResult: true);
          for (final statement in DatabaseSchema.migration2Statements) {
            await db.execute(statement);
          }
          await DatabaseSeeder.seed(db);
          await db.insert('app_settings', {
            'key': 'invoice_sequence',
            'value': '42',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        },
      ),
    );
    await legacy.close();

    final migrated = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: legacyPath,
    );
    await migrated.initialize();

    expect(await migrated.database.getVersion(), DatabaseSchema.currentVersion);
    final columns = await migrated.database.rawQuery(
      'PRAGMA table_info(payments)',
    );
    expect(columns.map((row) => row['name']), contains('save_token'));
    final invoiceColumns = await migrated.database.rawQuery(
      'PRAGMA table_info(invoices)',
    );
    expect(
      invoiceColumns.map((row) => row['name']),
      contains('company_name_snapshot'),
    );
    expect(
      (await migrated.database.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['invoice_sequence'],
      )).single['value'],
      '42',
    );
    await migrated.close();
  });
}
