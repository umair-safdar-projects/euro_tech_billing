import 'dart:io';

import 'package:eurotechbilling/core/database/app_database.dart';
import 'package:eurotechbilling/core/utils/currency.dart';
import 'package:eurotechbilling/features/customers/data/customer_repository.dart';
import 'package:eurotechbilling/features/customers/domain/customer.dart';
import 'package:eurotechbilling/features/invoices/data/invoice_repository.dart';
import 'package:eurotechbilling/features/invoices/domain/invoice_calculator.dart';
import 'package:eurotechbilling/features/invoices/domain/invoice_models.dart';
import 'package:eurotechbilling/features/products/data/product_repository.dart';
import 'package:eurotechbilling/features/payments/data/payment_repository.dart';
import 'package:eurotechbilling/features/payments/domain/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporaryDirectory;
  late AppDatabase appDatabase;
  late CustomerRepository customers;
  late ProductRepository products;
  late InvoiceRepository invoices;
  late Customer customer;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('euro_tech_m2_');
    appDatabase = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: p.join(temporaryDirectory.path, 'test.sqlite'),
    );
    await appDatabase.initialize();
    customers = CustomerRepository(appDatabase);
    products = ProductRepository(appDatabase);
    invoices = InvoiceRepository(appDatabase);
    customer = await customers.create(
      const CustomerInput(name: 'Alpha Furniture', phone: '03001234567'),
      saveToken: 'customer-alpha',
    );
  });

  tearDown(() async {
    await appDatabase.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('customer creation is idempotent, searchable, and editable', () async {
    final repeated = await customers.create(
      const CustomerInput(name: 'Ignored Repeat'),
      saveToken: 'customer-alpha',
    );
    expect(repeated.id, customer.id);
    expect(await customers.search('0300123'), hasLength(1));
    expect(await customers.search('alpha'), hasLength(1));
    await customers.update(
      customer.id,
      const CustomerInput(
        name: 'Alpha Updated',
        phone: '03001234567',
        address: 'Rawalpindi',
        notes: 'Priority',
      ),
    );
    final updated = await customers.find(customer.id);
    expect(updated?.name, 'Alpha Updated');
    expect(updated?.notes, 'Priority');
  });

  test('phone validation rejects invalid optional numbers', () {
    expect(
      () => const CustomerInput(name: 'Invalid', phone: '12x').validate(),
      throwsFormatException,
    );
    expect(
      () => const CustomerInput(name: 'No phone').validate(),
      returnsNormally,
    );
  });

  test(
    'active product selection preserves seeded prices and custom rates',
    () async {
      final active = await products.getActive(search: 'Sheet Cutting');
      expect(active, hasLength(2));
      expect(
        active
            .singleWhere((product) => !product.requiresCustomPrice)
            .defaultPriceMinor,
        35000,
      );
      expect(
        active
            .singleWhere((product) => product.requiresCustomPrice)
            .defaultPriceMinor,
        isNull,
      );
    },
  );

  test('currency parsing and invoice calculations use exact minor units', () {
    expect(Currency.parseRupees('1,234.56'), 123456);
    final totals = InvoiceCalculator.calculate([
      const InvoiceLineInput(
        description: 'Cutting',
        quantity: 3,
        unit: 'piece',
        unitPriceMinor: 35000,
      ),
      const InvoiceLineInput(
        description: 'Edging',
        quantity: 2,
        unit: 'piece',
        unitPriceMinor: 3000,
      ),
    ], 1000);
    expect(totals.lineTotals, [105000, 6000]);
    expect(totals.subtotalMinor, 111000);
    expect(totals.grandTotalMinor, 110000);
  });

  test('custom rate, discount, and overflow boundaries are enforced', () {
    expect(Currency.parseRupees(''), isNull);
    expect(
      () => InvoiceCalculator.calculate([
        const InvoiceLineInput(
          description: 'Custom',
          quantity: 1,
          unit: 'piece',
          unitPriceMinor: 100,
        ),
      ], 101),
      throwsFormatException,
    );
    expect(
      () => InvoiceCalculator.calculate([
        const InvoiceLineInput(
          description: 'Huge',
          quantity: 2,
          unit: 'piece',
          unitPriceMinor: InvoiceCalculator.maxInt64,
        ),
      ], 0),
      throwsFormatException,
    );
  });

  test(
    'invoice save is atomic, sequential, idempotent, and snapshots items',
    () async {
      final product = (await products.getActive()).firstWhere(
        (item) => !item.requiresCustomPrice,
      );
      final first = await invoices.save(
        _input(
          customer.id,
          'invoice-one',
          productId: product.id,
          description: product.name,
          price: product.defaultPriceMinor!,
        ),
      );
      final repeated = await invoices.save(
        _input(
          customer.id,
          'invoice-one',
          productId: product.id,
          description: 'Changed',
          price: 1,
        ),
      );
      final second = await invoices.save(
        _input(
          customer.id,
          'invoice-two',
          description: 'Custom saved line',
          price: 12345,
        ),
      );
      expect(first.invoiceNumber, 'ET-000001');
      expect(repeated.id, first.id);
      expect(second.invoiceNumber, 'ET-000002');
      final detail = await invoices.detail(first.id);
      expect(detail?.items.single.description, product.name);
      expect(detail?.items.single.unitPriceMinor, product.defaultPriceMinor);
      expect(detail?.paymentStatus, 'unpaid');
      expect(await appDatabase.database.query('audit_logs'), hasLength(2));
    },
  );

  test(
    'unpaid invoices can be corrected and deleted without reusing numbers',
    () async {
      final saved = await invoices.save(
        _input(
          customer.id,
          'editable',
          description: 'Wrong service',
          price: 100,
        ),
      );
      await invoices.updateUnpaid(
        InvoiceUpdateInput(
          id: saved.id,
          customerId: customer.id,
          issueDate: DateTime(2026, 1, 2),
          items: const [
            InvoiceLineInput(
              description: 'Correct service',
              quantity: 1,
              unit: 'piece',
              unitPriceMinor: 250,
            ),
          ],
          discountMinor: 0,
        ),
      );
      final updated = await invoices.detail(saved.id);
      expect(updated?.items.single.description, 'Correct service');
      expect(updated?.grandTotalMinor, 250);
      expect(updated?.issueDate, DateTime(2026, 1, 2));

      await invoices.deleteUnpaid(saved.id);
      expect(await invoices.detail(saved.id), isNull);
      final next = await invoices.save(
        _input(customer.id, 'after-delete', description: 'Next', price: 100),
      );
      expect(next.invoiceNumber, 'ET-000002');
      final actions = await appDatabase.database.query(
        'audit_logs',
        columns: ['action'],
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: ['invoice', saved.id],
        orderBy: 'id',
      );
      expect(actions.map((row) => row['action']), [
        'created',
        'updated',
        'deleted',
      ]);
    },
  );

  test('invoices with payments cannot be corrected or deleted', () async {
    final saved = await invoices.save(
      _input(customer.id, 'paid', description: 'Paid service', price: 100),
    );
    final payments = PaymentRepository(appDatabase);
    await payments.record(
      PaymentInput(
        invoiceId: saved.id,
        amountMinor: 200,
        method: 'cash',
        paymentDate: DateTime(2026, 1, 2),
        saveToken: 'payment-paid',
      ),
    );
    final update = InvoiceUpdateInput(
      id: saved.id,
      customerId: customer.id,
      issueDate: DateTime(2026, 1, 2),
      items: const [
        InvoiceLineInput(
          description: 'Changed paid service',
          quantity: 1,
          unit: 'piece',
          unitPriceMinor: 200,
        ),
      ],
      discountMinor: 0,
    );
    await expectLater(invoices.updateUnpaid(update), throwsStateError);
    await expectLater(invoices.deleteUnpaid(saved.id), throwsStateError);
    expect(await invoices.detail(saved.id), isNotNull);
  });

  test(
    'failed item insert rolls back invoice, number allocation, and audit',
    () async {
      await expectLater(
        invoices.save(
          _input(
            customer.id,
            'broken',
            productId: 999999,
            description: 'Broken',
            price: 100,
          ),
        ),
        throwsA(anything),
      );
      expect(await appDatabase.database.query('invoices'), isEmpty);
      expect(await appDatabase.database.query('audit_logs'), isEmpty);
      final saved = await invoices.save(
        _input(customer.id, 'valid', description: 'Valid', price: 100),
      );
      expect(saved.invoiceNumber, 'ET-000001');
    },
  );

  test(
    'invoice history filters by number, customer, date, and customer id',
    () async {
      final first = await invoices.save(
        _input(
          customer.id,
          'history-one',
          description: 'First',
          price: 100,
          date: DateTime(2026, 1, 10),
        ),
      );
      final other = await customers.create(
        const CustomerInput(name: 'Beta Kitchens'),
        saveToken: 'customer-beta',
      );
      await invoices.save(
        _input(
          other.id,
          'history-two',
          description: 'Second',
          price: 200,
          date: DateTime(2026, 2, 10),
        ),
      );
      expect((await invoices.list(search: first.invoiceNumber)).total, 1);
      expect((await invoices.list(search: 'Beta')).total, 1);
      expect(
        (await invoices.list(
          from: DateTime(2026, 2, 1),
          to: DateTime(2026, 2, 28),
        )).total,
        1,
      );
      expect((await invoices.list(customerId: customer.id)).total, 1);
    },
  );

  test('invoice and numbering persist after database reopening', () async {
    final saved = await invoices.save(
      _input(customer.id, 'persist-one', description: 'Persistent', price: 500),
    );
    await appDatabase.close();
    await appDatabase.initialize();
    invoices = InvoiceRepository(appDatabase);
    final detail = await invoices.detail(saved.id);
    expect(detail?.items.single.description, 'Persistent');
    final next = await invoices.save(
      _input(customer.id, 'persist-two', description: 'Next', price: 600),
    );
    expect(next.invoiceNumber, 'ET-000002');
  });
}

InvoiceSaveInput _input(
  int customerId,
  String token, {
  int? productId,
  required String description,
  required int price,
  DateTime? date,
}) => InvoiceSaveInput(
  customerId: customerId,
  issueDate: date ?? DateTime(2026, 1, 1),
  items: [
    InvoiceLineInput(
      productId: productId,
      description: description,
      quantity: 2,
      unit: 'piece',
      unitPriceMinor: price,
    ),
  ],
  discountMinor: 0,
  saveToken: token,
);
