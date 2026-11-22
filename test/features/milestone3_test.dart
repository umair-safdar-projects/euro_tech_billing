import 'dart:io';

import 'package:eurotechbilling/core/database/app_database.dart';
import 'package:eurotechbilling/features/credit/data/credit_repository.dart';
import 'package:eurotechbilling/features/customers/data/customer_repository.dart';
import 'package:eurotechbilling/features/customers/domain/customer.dart';
import 'package:eurotechbilling/features/invoices/data/invoice_repository.dart';
import 'package:eurotechbilling/features/invoices/domain/invoice_models.dart';
import 'package:eurotechbilling/features/payments/data/payment_repository.dart';
import 'package:eurotechbilling/features/payments/domain/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late AppDatabase database;
  late CustomerRepository customers;
  late InvoiceRepository invoices;
  late PaymentRepository payments;
  late CreditRepository credit;
  late Customer customer;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('euro_tech_m3_');
    database = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: p.join(directory.path, 'test.sqlite'),
    );
    await database.initialize();
    customers = CustomerRepository(database);
    payments = PaymentRepository(database);
    invoices = InvoiceRepository(database, payments);
    credit = CreditRepository(database, invoices, payments);
    customer = await customers.create(
      const CustomerInput(name: 'Credit Customer', phone: '03001112222'),
      saveToken: 'customer-credit',
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('full payment transitions invoice from unpaid to paid', () async {
    final invoice = await _invoice(
      invoices,
      customer.id,
      'full-invoice',
      100000,
    );
    expect((await payments.invoiceBalance(invoice.id))?.status, 'unpaid');
    await payments.record(_payment(invoice.id, 'full-payment', 100000));
    final balance = await payments.invoiceBalance(invoice.id);
    expect(balance?.status, 'paid');
    expect(balance?.paidMinor, 100000);
    expect(balance?.balanceMinor, 0);
  });

  test(
    'multiple partial payments produce consistent status transitions',
    () async {
      final invoice = await _invoice(
        invoices,
        customer.id,
        'partial-invoice',
        100000,
      );
      await payments.record(_payment(invoice.id, 'partial-one', 25000));
      expect(
        (await payments.invoiceBalance(invoice.id))?.status,
        'partially_paid',
      );
      await payments.record(_payment(invoice.id, 'partial-two', 35000));
      final middle = await payments.invoiceBalance(invoice.id);
      expect(middle?.paidMinor, 60000);
      expect(middle?.balanceMinor, 40000);
      await payments.record(_payment(invoice.id, 'partial-three', 40000));
      expect((await payments.invoiceBalance(invoice.id))?.status, 'paid');
    },
  );

  test('zero, negative, and overpayment amounts are rejected', () async {
    final invoice = await _invoice(
      invoices,
      customer.id,
      'bounds-invoice',
      1000,
    );
    await expectLater(
      payments.record(_payment(invoice.id, 'zero', 0)),
      throwsFormatException,
    );
    await expectLater(
      payments.record(_payment(invoice.id, 'negative', -1)),
      throwsFormatException,
    );
    await expectLater(
      payments.record(_payment(invoice.id, 'over', 1001)),
      throwsFormatException,
    );
    expect(await payments.forInvoice(invoice.id), isEmpty);
  });

  test('duplicate payment submission returns the original record', () async {
    final invoice = await _invoice(
      invoices,
      customer.id,
      'duplicate-invoice',
      1000,
    );
    final first = await payments.record(
      _payment(invoice.id, 'same-token', 400),
    );
    final repeated = await payments.record(
      _payment(invoice.id, 'same-token', 400),
    );
    expect(repeated.id, first.id);
    expect(await payments.forInvoice(invoice.id), hasLength(1));
  });

  test('payments are audited and cannot be edited or deleted', () async {
    final invoice = await _invoice(
      invoices,
      customer.id,
      'immutable-invoice',
      1000,
    );
    final payment = await payments.record(
      _payment(invoice.id, 'immutable-payment', 400),
    );
    expect(
      await database.database.query(
        'audit_logs',
        where: 'entity_type = ?',
        whereArgs: ['payment'],
      ),
      hasLength(1),
    );
    await expectLater(
      database.database.update(
        'payments',
        {'amount_minor': 300},
        where: 'id = ?',
        whereArgs: [payment.id],
      ),
      throwsA(anything),
    );
    await expectLater(
      database.database.delete(
        'payments',
        where: 'id = ?',
        whereArgs: [payment.id],
      ),
      throwsA(anything),
    );
    expect((await payments.detail(payment.id))?.amountMinor, 400);
  });

  test('payment persists after reopening the database', () async {
    final invoice = await _invoice(
      invoices,
      customer.id,
      'persist-payment-invoice',
      1000,
    );
    final payment = await payments.record(
      _payment(invoice.id, 'persist-payment', 300),
    );
    await database.close();
    await database.initialize();
    payments = PaymentRepository(database);
    expect((await payments.detail(payment.id))?.amountMinor, 300);
    expect((await payments.invoiceBalance(invoice.id))?.balanceMinor, 700);
  });

  test('customer credit and ledger totals use invoices and payments', () async {
    final first = await _invoice(invoices, customer.id, 'ledger-one', 100000);
    await _invoice(invoices, customer.id, 'ledger-two', 50000);
    await payments.record(_payment(first.id, 'ledger-payment', 40000));
    final summary = await credit.summary();
    expect(summary.outstandingMinor, 110000);
    expect(summary.customerCount, 1);
    expect(summary.unpaidCount, 1);
    expect(summary.partialCount, 1);
    final ledger = await credit.ledger(customer.id);
    expect(ledger?.credit.totalInvoicedMinor, 150000);
    expect(ledger?.credit.totalReceivedMinor, 40000);
    expect(ledger?.credit.outstandingMinor, 110000);
    expect(ledger?.invoices, hasLength(2));
    expect(ledger?.payments, hasLength(1));
  });

  test(
    'payment received today against an older invoice counts as collection only',
    () async {
      final today = DateTime(2026, 6, 15, 10);
      final invoice = await _invoice(
        invoices,
        customer.id,
        'older-invoice',
        50000,
        date: DateTime(2026, 6, 10),
      );
      await payments.record(
        _payment(invoice.id, 'today-payment', 20000, date: today),
      );
      final dashboard = await credit.dashboard(businessDate: today);
      expect(dashboard.todaySalesMinor, 0);
      expect(dashboard.todayCollectionsMinor, 20000);
      expect(dashboard.todayInvoiceCount, 0);
    },
  );

  test(
    'dashboard keeps same-day invoiced sales separate from collections',
    () async {
      final today = DateTime(2026, 7, 1, 11);
      final invoice = await _invoice(
        invoices,
        customer.id,
        'today-invoice',
        80000,
        date: today,
      );
      await payments.record(
        _payment(invoice.id, 'today-collection', 30000, date: today),
      );
      final dashboard = await credit.dashboard(businessDate: today);
      expect(dashboard.todaySalesMinor, 80000);
      expect(dashboard.todayCollectionsMinor, 30000);
      expect(dashboard.outstandingMinor, 50000);
    },
  );

  test(
    'initial full payment commits atomically with invoice and supports walk-in',
    () async {
      final saved = await invoices.save(
        InvoiceSaveInput(
          customerId: null,
          issueDate: DateTime(2026, 8, 1),
          items: const [
            InvoiceLineInput(
              description: 'Walk-in service',
              quantity: 1,
              unit: 'piece',
              unitPriceMinor: 25000,
            ),
          ],
          discountMinor: 0,
          saveToken: 'walk-in-invoice',
          initialPayment: InitialPaymentInput(
            amountMinor: 25000,
            method: 'cash',
            paymentDate: DateTime(2026, 8, 1),
            saveToken: 'walk-in-payment',
          ),
        ),
      );
      expect(saved.paymentId, isNotNull);
      expect((await payments.invoiceBalance(saved.id))?.status, 'paid');
      expect(
        (await invoices.detail(saved.id))?.customerName,
        'Walk-in Customer',
      );
    },
  );

  test('initial partial payment commits with the invoice', () async {
    final saved = await invoices.save(
      InvoiceSaveInput(
        customerId: customer.id,
        issueDate: DateTime(2026, 8, 2),
        items: const [
          InvoiceLineInput(
            description: 'Credit service',
            quantity: 1,
            unit: 'piece',
            unitPriceMinor: 30000,
          ),
        ],
        discountMinor: 0,
        saveToken: 'initial-partial-invoice',
        initialPayment: InitialPaymentInput(
          amountMinor: 10000,
          method: 'bank_transfer',
          paymentDate: DateTime(2026, 8, 2),
          saveToken: 'initial-partial-payment',
        ),
      ),
    );
    final balance = await payments.invoiceBalance(saved.id);
    expect(balance?.status, 'partially_paid');
    expect(balance?.balanceMinor, 20000);
  });

  test(
    'invalid initial payment rolls back invoice, sequence, and audit',
    () async {
      await expectLater(
        invoices.save(
          InvoiceSaveInput(
            customerId: customer.id,
            issueDate: DateTime(2026, 8, 3),
            items: const [
              InvoiceLineInput(
                description: 'Rollback',
                quantity: 1,
                unit: 'piece',
                unitPriceMinor: 10000,
              ),
            ],
            discountMinor: 0,
            saveToken: 'rollback-invoice',
            initialPayment: InitialPaymentInput(
              amountMinor: 5000,
              method: 'invalid',
              paymentDate: DateTime(2026, 8, 3),
              saveToken: 'rollback-payment',
            ),
          ),
        ),
        throwsFormatException,
      );
      expect(await database.database.query('invoices'), isEmpty);
      expect(await database.database.query('payments'), isEmpty);
      expect(await database.database.query('audit_logs'), isEmpty);
      final next = await _invoice(
        invoices,
        customer.id,
        'after-rollback',
        10000,
      );
      expect(next.invoiceNumber, 'ET-000001');
    },
  );

  test('zero-value invoice remains unpaid and rejects payment', () async {
    final invoice = await _invoice(invoices, customer.id, 'zero-invoice', 0);
    expect((await payments.invoiceBalance(invoice.id))?.status, 'unpaid');
    await expectLater(
      payments.record(_payment(invoice.id, 'zero-invoice-payment', 1)),
      throwsFormatException,
    );
  });

  test('concurrent payment attempts cannot overpay an invoice', () async {
    final invoice = await _invoice(
      invoices,
      customer.id,
      'concurrent-invoice',
      1000,
    );
    final results = await Future.wait([
      payments
          .record(_payment(invoice.id, 'concurrent-one', 600))
          .then<Object>((value) => value)
          .catchError((Object error) => error),
      payments
          .record(_payment(invoice.id, 'concurrent-two', 600))
          .then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);
    expect(results.whereType<PaymentRecord>(), hasLength(1));
    final balance = await payments.invoiceBalance(invoice.id);
    expect(balance?.paidMinor, 600);
    expect(balance?.balanceMinor, 400);
  });
}

Future<SavedInvoice> _invoice(
  InvoiceRepository repository,
  int customerId,
  String token,
  int amount, {
  DateTime? date,
}) => repository.save(
  InvoiceSaveInput(
    customerId: customerId,
    issueDate: date ?? DateTime(2026, 1, 1),
    items: [
      InvoiceLineInput(
        description: 'Service',
        quantity: 1,
        unit: 'piece',
        unitPriceMinor: amount,
      ),
    ],
    discountMinor: 0,
    saveToken: token,
  ),
);

PaymentInput _payment(
  int invoiceId,
  String token,
  int amount, {
  DateTime? date,
}) => PaymentInput(
  invoiceId: invoiceId,
  amountMinor: amount,
  method: 'cash',
  paymentDate: date ?? DateTime(2026, 1, 2),
  saveToken: token,
);
