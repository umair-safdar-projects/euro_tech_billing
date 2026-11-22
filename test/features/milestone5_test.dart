import 'dart:io';

import 'package:eurotechbilling/core/database/app_database.dart';
import 'package:eurotechbilling/core/database/database_seeder.dart';
import 'package:eurotechbilling/core/database/schema.dart';
import 'package:eurotechbilling/features/backups/data/backup_service.dart';
import 'package:eurotechbilling/features/backups/domain/backup_models.dart';
import 'package:eurotechbilling/features/customers/data/customer_repository.dart';
import 'package:eurotechbilling/features/customers/domain/customer.dart';
import 'package:eurotechbilling/features/invoices/data/invoice_repository.dart';
import 'package:eurotechbilling/features/invoices/domain/invoice_models.dart';
import 'package:eurotechbilling/features/payments/data/payment_repository.dart';
import 'package:eurotechbilling/features/payments/domain/payment_models.dart';
import 'package:eurotechbilling/features/printing/data/invoice_print_data_service.dart';
import 'package:eurotechbilling/features/printing/data/printing_settings_repository.dart';
import 'package:eurotechbilling/features/reports/data/report_repository.dart';
import 'package:eurotechbilling/features/reports/domain/report_models.dart';
import 'package:eurotechbilling/features/reports/services/report_export_service.dart';
import 'package:eurotechbilling/features/settings/data/company_settings_repository.dart';
import 'package:eurotechbilling/features/settings/domain/company_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporaryDirectory;
  late AppDatabase appDatabase;
  late BackupService backups;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('euro_tech_m5_');
    appDatabase = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: p.join(temporaryDirectory.path, 'billing.sqlite'),
    );
    await appDatabase.initialize();
    backups = BackupService(
      appDatabase,
      defaultDirectory: p.join(temporaryDirectory.path, 'Backups اردو'),
    );
  });

  tearDown(() async {
    await appDatabase.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'creates a consistent verified backup without overwriting files',
    () async {
      await _createInvoice(appDatabase, token: 'backup-one');
      final first = await backups.createBackup();
      final second = await backups.createBackup();
      expect(first.path, isNot(second.path));
      expect(first.invoiceCount, 1);
      expect(first.schemaVersion, DatabaseSchema.currentVersion);
      expect(await File(first.path).exists(), isTrue);
      final status = await backups.loadStatus();
      expect(status.lastSuccessfulAt, isNotNull);
      expect(status.history, hasLength(2));
    },
  );

  test('automatic backup runs once per daily interval', () async {
    final first = await backups.runAutomaticBackupIfDue();
    final second = await backups.runAutomaticBackupIfDue();
    expect(first, isNotNull);
    expect(second, isNull);
    expect((await backups.loadStatus()).isHealthy, isTrue);
  });

  test(
    'restores a backup and preserves its invoice and payment data',
    () async {
      final original = await _createInvoice(appDatabase, token: 'restore-one');
      await PaymentRepository(appDatabase).record(
        PaymentInput(
          invoiceId: original.id,
          amountMinor: 5000,
          method: 'cash',
          paymentDate: DateTime(2026, 4, 3),
          saveToken: 'restore-payment',
        ),
      );
      final backup = await backups.createBackup();
      await _createInvoice(appDatabase, token: 'later-invoice');

      await backups.restore(backup.path);

      expect(
        await appDatabase.database.getVersion(),
        DatabaseSchema.currentVersion,
      );
      expect(
        (await appDatabase.database.rawQuery(
          'SELECT COUNT(*) AS value FROM invoices',
        )).single['value'],
        1,
      );
      expect(
        (await appDatabase.database.rawQuery(
          'SELECT COUNT(*) AS value FROM payments',
        )).single['value'],
        1,
      );
    },
  );

  test('rejects invalid and newer-schema backup files', () async {
    final text = File(p.join(temporaryDirectory.path, 'invalid.sqlite'));
    await text.writeAsString('not a database');
    await expectLater(
      backups.verify(text.path),
      throwsA(isA<BackupException>()),
    );

    final newerPath = p.join(temporaryDirectory.path, 'newer.sqlite');
    final newer = await databaseFactoryFfi.openDatabase(newerPath);
    await newer.execute('CREATE TABLE invoices(id INTEGER)');
    await newer.execute('CREATE TABLE customers(id INTEGER)');
    await newer.execute('CREATE TABLE payments(id INTEGER)');
    await newer.setVersion(DatabaseSchema.currentVersion + 1);
    await newer.close();
    await expectLater(
      backups.verify(newerPath),
      throwsA(isA<BackupException>()),
    );
  });

  test('failed restore recovers the original active database', () async {
    final original = await _createInvoice(
      appDatabase,
      token: 'recovery-original',
    );
    final brokenPath = p.join(
      temporaryDirectory.path,
      'structurally-incomplete.sqlite',
    );
    final broken = await databaseFactoryFfi.openDatabase(brokenPath);
    await broken.execute('CREATE TABLE invoices(id INTEGER)');
    await broken.execute('CREATE TABLE customers(id INTEGER)');
    await broken.execute('CREATE TABLE payments(id INTEGER)');
    await broken.setVersion(DatabaseSchema.currentVersion);
    await broken.close();
    expect(
      (await backups.verify(brokenPath)).schemaVersion,
      DatabaseSchema.currentVersion,
    );

    await expectLater(
      backups.restore(brokenPath),
      throwsA(isA<BackupException>()),
    );

    final restored = await InvoiceRepository(appDatabase).detail(original.id);
    expect(restored?.invoiceNumber, original.invoiceNumber);
  });

  test('restores and migrates a genuine schema v3 backup', () async {
    final legacyPath = p.join(temporaryDirectory.path, 'legacy-v3.sqlite');
    final legacy = await databaseFactoryFfi.openDatabase(
      legacyPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (database, _) async {
          final batch = database.batch();
          for (final statement in DatabaseSchema.createStatements) {
            batch.execute(statement);
          }
          await batch.commit(noResult: true);
          for (final statement in DatabaseSchema.migration2Statements) {
            await database.execute(statement);
          }
          for (final statement in DatabaseSchema.migration3Statements) {
            await database.execute(statement);
          }
          await DatabaseSeeder.seed(database);
        },
      ),
    );
    await legacy.close();

    expect((await backups.verify(legacyPath)).schemaVersion, 3);
    await backups.restore(legacyPath);

    expect(
      await appDatabase.database.getVersion(),
      DatabaseSchema.currentVersion,
    );
    final columns = await appDatabase.database.rawQuery(
      'PRAGMA table_info(invoices)',
    );
    expect(
      columns.map((row) => row['name']),
      contains('customer_name_snapshot'),
    );
  });

  test('new invoices retain company and customer identity snapshots', () async {
    final customers = CustomerRepository(appDatabase);
    final customer = await customers.create(
      const CustomerInput(
        name: 'Original Customer',
        phone: '03001234567',
        address: 'Old Address',
      ),
      saveToken: 'identity-customer',
    );
    final saved = await _createInvoice(
      appDatabase,
      token: 'identity-invoice',
      customerId: customer.id,
    );
    await customers.update(
      customer.id,
      const CustomerInput(
        name: 'Renamed Customer',
        phone: '03110000000',
        address: 'New Address',
      ),
    );
    final companyRepository = CompanySettingsRepository(appDatabase);
    final company = await companyRepository.load();
    await companyRepository.save(
      CompanySettings(
        companyName: 'Changed Company',
        ownerName: company.ownerName,
        primaryPhone: company.primaryPhone,
        secondaryPhone: company.secondaryPhone,
        additionalContactName: company.additionalContactName,
        additionalContactPhone: company.additionalContactPhone,
        email: company.email,
        address: 'Changed Address',
      ),
    );

    final detail = (await InvoiceRepository(appDatabase).detail(saved.id))!;
    expect(detail.customerName, 'Original Customer');
    expect(detail.customerPhone, '03001234567');
    expect(detail.customerAddress, 'Old Address');
    expect(detail.companyIdentity?.companyName, isNot('Changed Company'));
    expect(detail.usesLegacyIdentityFallback, isFalse);
    final printModel = await InvoicePrintDataService(
      InvoiceRepository(appDatabase),
      companyRepository,
      PrintingSettingsRepository(appDatabase),
    ).load(saved.id);
    expect(printModel.company.companyName, detail.companyIdentity?.companyName);
    expect(printModel.company.address, detail.companyIdentity?.address);
  });

  test('legacy invoices explicitly fall back to current identity', () async {
    final customer = await CustomerRepository(appDatabase).create(
      const CustomerInput(name: 'Current Legacy Name', phone: '03009999999'),
      saveToken: 'legacy-customer',
    );
    final saved = await _createInvoice(
      appDatabase,
      token: 'legacy-invoice',
      customerId: customer.id,
    );
    await appDatabase.database.update(
      'invoices',
      {
        'company_name_snapshot': null,
        'company_address_snapshot': null,
        'customer_name_snapshot': null,
        'customer_phone_snapshot': null,
        'customer_address_snapshot': null,
      },
      where: 'id = ?',
      whereArgs: [saved.id],
    );

    final detail = (await InvoiceRepository(appDatabase).detail(saved.id))!;
    expect(detail.customerName, 'Current Legacy Name');
    expect(detail.companyIdentity, isNull);
    expect(detail.usesLegacyIdentityFallback, isTrue);
  });

  test(
    'reports separate invoice dates from later payment collection dates',
    () async {
      final saved = await _createInvoice(
        appDatabase,
        token: 'report-invoice',
        issueDate: DateTime(2026, 1, 2),
        priceMinor: 10000,
      );
      await PaymentRepository(appDatabase).record(
        PaymentInput(
          invoiceId: saved.id,
          amountMinor: 4000,
          method: 'cash',
          paymentDate: DateTime(2026, 1, 8),
          saveToken: 'report-payment',
        ),
      );
      final reports = ReportRepository(appDatabase);
      final saleDay = await reports.load(
        ReportRange(DateTime(2026, 1, 2), DateTime(2026, 1, 2)),
      );
      final paymentDay = await reports.load(
        ReportRange(DateTime(2026, 1, 8), DateTime(2026, 1, 8)),
      );

      expect(saleDay.invoicedMinor, 10000);
      expect(saleDay.collectedMinor, 0);
      expect(paymentDay.invoicedMinor, 0);
      expect(paymentDay.collectedMinor, 4000);
      expect(paymentDay.outstandingMinor, 6000);
    },
  );

  test('date-range reports and CSV include real grouped totals', () async {
    await _createInvoice(
      appDatabase,
      token: 'range-in',
      issueDate: DateTime(2026, 2, 10),
      priceMinor: 12345,
    );
    await _createInvoice(
      appDatabase,
      token: 'range-out',
      issueDate: DateTime(2026, 3, 1),
      priceMinor: 50000,
    );
    final report = await ReportRepository(
      appDatabase,
    ).load(ReportRange(DateTime(2026, 2, 1), DateTime(2026, 2, 28)));
    expect(report.invoiceCount, 1);
    expect(report.invoicedMinor, 12345);
    expect(report.productSales.single.amountMinor, 12345);
    final csv = ReportExportService().buildCsv(report);
    expect(csv, contains('Invoiced Sales (PKR)'));
    expect(csv, contains('123.45'));
    expect(csv, contains('Test Service'));
    final pdf = await ReportExportService().buildPdf(report);
    expect(pdf.sublist(0, 4), [37, 80, 68, 70]);
  });
}

Future<SavedInvoice> _createInvoice(
  AppDatabase database, {
  required String token,
  int? customerId,
  DateTime? issueDate,
  int priceMinor = 10000,
}) async {
  final resolvedCustomerId =
      customerId ??
      (await CustomerRepository(database).create(
        CustomerInput(name: 'Customer $token', phone: '03001234567'),
        saveToken: '$token-customer',
      )).id;
  return InvoiceRepository(database).save(
    InvoiceSaveInput(
      customerId: resolvedCustomerId,
      issueDate: issueDate ?? DateTime(2026, 1, 1),
      items: [
        InvoiceLineInput(
          description: 'Test Service',
          quantity: 1,
          unit: 'piece',
          unitPriceMinor: priceMinor,
        ),
      ],
      discountMinor: 0,
      saveToken: token,
    ),
  );
}
