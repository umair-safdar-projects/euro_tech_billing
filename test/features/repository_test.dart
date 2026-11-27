import 'dart:io';

import 'package:eurotechbilling/core/database/app_database.dart';
import 'package:eurotechbilling/features/products/data/product_repository.dart';
import 'package:eurotechbilling/features/products/presentation/products_controller.dart';
import 'package:eurotechbilling/features/invoices/data/invoice_repository.dart';
import 'package:eurotechbilling/features/invoices/domain/invoice_models.dart';
import 'package:eurotechbilling/features/invoices/presentation/invoice_history_controller.dart';
import 'package:eurotechbilling/features/settings/data/company_settings_repository.dart';
import 'package:eurotechbilling/features/settings/domain/company_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporaryDirectory;
  late AppDatabase appDatabase;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'euro_tech_repo_test_',
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

  test('company settings persist after database reopen', () async {
    var repository = CompanySettingsRepository(appDatabase);
    const expected = CompanySettings(
      companyName: 'Euro Tech Updated',
      ownerName: 'Owner',
      primaryPhone: '03000000000',
      secondaryPhone: '',
      additionalContactName: 'Contact',
      additionalContactPhone: '03111111111',
      email: 'billing@example.com',
      address: 'Rawalpindi',
    );
    await repository.save(expected);
    await appDatabase.close();
    await appDatabase.initialize();
    repository = CompanySettingsRepository(appDatabase);

    final actual = await repository.load();
    expect(actual.companyName, expected.companyName);
    expect(actual.email, expected.email);
    expect(actual.address, expected.address);
  });

  test('each seeded switch persists by ID and preserves row order', () async {
    final repository = ProductRepository(appDatabase);
    final seeded = await repository.getAll();
    final ids = seeded.map((product) => product.id).toList();
    expect(ids, hasLength(7));

    for (final target in seeded) {
      await repository.setActive(target.id, false);
      await repository.setActive(target.id, false);

      final all = await repository.getAll();
      expect(all.map((product) => product.id), ids);
      expect(
        all.where((product) => !product.isActive).map((product) => product.id),
        [target.id],
      );
      final matching = await repository.getActive(search: target.name);
      expect(
        matching.map((product) => product.id),
        unorderedEquals(
          seeded
              .where(
                (product) =>
                    product.id != target.id &&
                    product.name.toLowerCase().contains(
                      target.name.toLowerCase(),
                    ),
              )
              .map((product) => product.id),
        ),
      );

      await appDatabase.close();
      await appDatabase.initialize();
      final reopened = await repository.getAll();
      expect(reopened.map((product) => product.id), ids);
      expect(
        reopened
            .where((product) => !product.isActive)
            .map((product) => product.id),
        [target.id],
      );

      await repository.setActive(target.id, true);
      expect(
        (await repository.getAll()).every((item) => item.isActive),
        isTrue,
      );
    }
  });

  test('rapid switch clicks allow only the pending status write', () async {
    final repository = ProductRepository(appDatabase);
    final controller = ProductsController(repository);
    await controller.load();
    final first = controller.products[0];
    final second = controller.products[1];

    final pending = controller.setActive(first.id, false);
    expect(controller.isUpdatingStatus.value, isTrue);
    await controller.setActive(first.id, true);
    await controller.setActive(second.id, false);
    await pending;

    expect(controller.isUpdatingStatus.value, isFalse);
    expect(
      controller.products
          .where((item) => !item.isActive)
          .map((item) => item.id),
      [first.id],
    );
    await controller.setActive(first.id, true);
    expect(controller.products.every((item) => item.isActive), isTrue);
  });

  test('product price update persists in minor units', () async {
    final repository = ProductRepository(appDatabase);
    final product = (await repository.getAll()).first;
    await repository.updatePrice(product.id, 42550);

    final updated = (await repository.getAll()).singleWhere(
      (candidate) => candidate.id == product.id,
    );
    expect(updated.defaultPriceMinor, 42550);
    expect(updated.requiresCustomPrice, isFalse);
  });

  test('invoice history selection exposes one clear invoice action target', () {
    final controller = InvoiceHistoryController(InvoiceRepository(appDatabase));
    controller.invoices.value = [
      InvoiceListItem(
        id: 11,
        invoiceNumber: 'ET-000011',
        issueDate: DateTime(2026, 1, 1),
        customerId: null,
        customerName: 'Walk-in Customer',
        grandTotalMinor: 3000,
        paymentStatus: 'unpaid',
      ),
      InvoiceListItem(
        id: 12,
        invoiceNumber: 'ET-000012',
        issueDate: DateTime(2026, 1, 2),
        customerId: null,
        customerName: 'Walk-in Customer',
        grandTotalMinor: 4000,
        paymentStatus: 'paid',
      ),
    ];

    controller.selectInvoice(11, true);
    expect(controller.selectedInvoice?.invoiceNumber, 'ET-000011');
    controller.selectInvoice(12, true);
    expect(controller.selectedInvoice?.invoiceNumber, 'ET-000012');
    controller.clearSelection();
    expect(controller.selectedInvoice, isNull);
  });
}
