import 'dart:convert';
import 'dart:io';

import 'package:eurotechbilling/core/database/app_database.dart';
import 'package:eurotechbilling/features/invoices/data/invoice_repository.dart';
import 'package:eurotechbilling/features/invoices/domain/invoice_models.dart';
import 'package:eurotechbilling/features/printing/data/invoice_print_data_service.dart';
import 'package:eurotechbilling/features/printing/data/printing_settings_repository.dart';
import 'package:eurotechbilling/features/printing/domain/printing_models.dart';
import 'package:eurotechbilling/features/printing/services/invoice_pdf_service.dart';
import 'package:eurotechbilling/features/settings/data/company_settings_repository.dart';
import 'package:eurotechbilling/features/settings/domain/company_settings.dart';
import 'package:eurotechbilling/features/invoices/presentation/invoice_detail_view.dart';
import 'package:eurotechbilling/features/payments/data/payment_repository.dart';
import 'package:eurotechbilling/features/printing/services/invoice_printing_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final service = InvoicePdfService();

  testWidgets('invoice detail routes preview, print and export separately', (
    tester,
  ) async {
    const channel = MethodChannel('net.nfet.printing');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => <String, bool>{});
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      Get.reset();
    });

    final model = _model(paid: 35000, status: 'paid');
    final printing = _RecordingPrintingService(model);
    final database = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    Get.put(CompanySettingsRepository(database));
    Get.put(PaymentRepository(database));
    Get.put<InvoicePrintingService>(printing);

    await tester.pumpWidget(
      GetMaterialApp(home: InvoiceDetailDialog(detail: model.invoice)),
    );

    await tester.tap(find.byTooltip('Print Invoice'));
    await tester.pump();
    expect(printing.calls, ['print:321']);
    expect(find.byType(PdfPreview), findsNothing);

    await tester.tap(find.byTooltip('Export PDF'));
    await tester.pump();
    expect(printing.calls, ['print:321', 'export:321']);

    await tester.tap(find.byTooltip('Preview Invoice'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(printing.calls, ['print:321', 'export:321', 'preview:321']);
    expect(find.byType(PdfPreview), findsOneWidget);
    final preview = tester.widget<PdfPreview>(find.byType(PdfPreview));
    expect(preview.allowPrinting, isFalse);
    expect(preview.allowSharing, isFalse);
  });

  test('A5 output uses genuine 148 x 210 mm page dimensions', () async {
    final layout = service.layoutFor(const PrintingSettings());
    expect(layout.pageFormat.width / PdfPageFormat.mm, closeTo(148, .01));
    expect(layout.pageFormat.height / PdfPageFormat.mm, closeTo(210, .01));
    final bytes = await service.generate(_model());
    expect(_mediaBoxes(bytes).single.$1, closeTo(148 * PdfPageFormat.mm, .1));
    expect(_mediaBoxes(bytes).single.$2, closeTo(210 * PdfPageFormat.mm, .1));
  });

  test('A4 modes retain the exact A5 content area without stretching', () {
    final a5 = service.layoutFor(const PrintingSettings());
    final centered = service.layoutFor(
      const PrintingSettings(
        paper: InvoicePaper.a4,
        a4Placement: A4Placement.centered,
      ),
    );
    final topLeft = service.layoutFor(
      const PrintingSettings(
        paper: InvoicePaper.a4,
        a4Placement: A4Placement.topLeft,
      ),
    );
    expect(centered.pageFormat.width, PdfPageFormat.a4.width);
    expect(centered.contentWidth, closeTo(a5.contentWidth, .001));
    expect(centered.contentHeight, closeTo(a5.contentHeight, .001));
    expect(topLeft.contentWidth, closeTo(a5.contentWidth, .001));
    expect(topLeft.contentHeight, closeTo(a5.contentHeight, .001));
    expect(centered.left, greaterThan(topLeft.left));
  });

  test('print visibility preferences persist with safe defaults', () async {
    final database = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    await database.initialize();
    addTearDown(database.close);
    final settings = PrintingSettingsRepository(database);

    final defaults = await settings.load();
    expect(defaults.showLogo, isTrue);
    expect(defaults.showEmail, isTrue);

    await settings.save(
      const PrintingSettings(
        showLogo: false,
        showEmail: false,
        footerMessage: 'Paid invoices only',
      ),
    );
    final saved = await settings.load();
    expect(saved.showLogo, isFalse);
    expect(saved.showEmail, isFalse);
    expect(saved.footerMessage, 'Paid invoices only');
  });

  test('optional business email can be hidden from the PDF header', () async {
    final text = _extractText(
      await service.generate(
        _model(settings: const PrintingSettings(showEmail: false)),
      ),
    );
    expect(text, isNot(contains('hamzamirza11579@gmail.com')));
  });

  test('multipage A4 invoices use A4 media boxes in both placements', () async {
    final items = List.generate(
      50,
      (index) => InvoiceDetailItem(
        description: 'Test service ${index + 1}',
        quantity: 1,
        unit: 'piece',
        unitPriceMinor: 35000,
        lineTotalMinor: 35000,
      ),
    );
    for (final placement in A4Placement.values) {
      final bytes = await service.generate(
        _model(
          items: items,
          settings: PrintingSettings(
            paper: InvoicePaper.a4,
            a4Placement: placement,
          ),
        ),
      );
      final boxes = _mediaBoxes(bytes);
      expect(boxes.length, greaterThan(1));
      expect(boxes.length, _pageCount(bytes));
      for (final box in boxes) {
        expect(box.$1, closeTo(PdfPageFormat.a4.width, .1));
        expect(box.$2, closeTo(PdfPageFormat.a4.height, .1));
      }
    }
  });

  test(
    'renders company, customer, invoice, item, totals, and unpaid status',
    () async {
      final text = _extractText(await service.generate(_model()));
      for (final expected in [
        'EURO TECH',
        'EDGING AND CUTTING',
        'ET-000321',
        '01 Sep 2026',
        'Mirza Farhan Ali',
        'Mirza Farhan Ali: 03038549491',
        'Mirza Farhan Ali: 03493668931',
        'Ameer Hamza: 03488917817',
        'Alpha Furniture',
        '03001234567',
        'Historical Sheet Cutting',
        '350.00',
        'Subtotal',
        'GRAND TOTAL',
        'UNPAID',
        'Remaining Balance',
      ]) {
        expect(text, contains(expected));
      }
    },
  );

  test(
    'renders discounts, received amounts, and partial and paid statuses',
    () async {
      final partial = _extractText(
        await service.generate(
          _model(
            status: 'partially_paid',
            paid: 15000,
            balance: 20000,
            discount: 5000,
          ),
        ),
      );
      expect(partial, contains('PARTIALLY PAID'));
      expect(partial, contains('Discount'));
      expect(partial, contains('Total Received'));
      final paid = _extractText(
        await service.generate(_model(status: 'paid', paid: 35000, balance: 0)),
      );
      expect(paid, contains('PAID'));
    },
  );

  test('zero-value invoice remains visibly unpaid', () async {
    final text = _extractText(
      await service.generate(
        _model(status: 'unpaid', price: 0, paid: 0, balance: 0),
      ),
    );
    expect(text, contains('UNPAID'));
    expect(text, contains('0.00'));
  });

  test('long invoices paginate without missing item descriptions', () async {
    final items = List.generate(
      40,
      (index) => InvoiceDetailItem(
        description:
            'Long service description number ${index + 1} with edging and precision cutting details',
        quantity: index + 1,
        unit: 'piece',
        unitPriceMinor: 12345678,
        lineTotalMinor: (index + 1) * 12345678,
      ),
    );
    final bytes = await service.generate(
      _model(
        items: items,
        subtotal: items.fold<int>(0, (sum, item) => sum + item.lineTotalMinor),
        grandTotal: items.fold<int>(
          0,
          (sum, item) => sum + item.lineTotalMinor,
        ),
      ),
    );
    final text = _extractText(bytes);
    expect(_pageCount(bytes), greaterThan(1));
    for (var index = 1; index <= 40; index++) {
      expect(text, contains('Long service description number $index'));
    }
    expect(text, contains('Page 1 of'));
  });

  test('five and fifteen item invoices render every snapshot once', () async {
    for (final count in [5, 15]) {
      final items = List.generate(
        count,
        (index) => InvoiceDetailItem(
          description: 'Snapshot item ${index + 1} unique',
          quantity: index + 1,
          unit: 'piece',
          unitPriceMinor: 5000,
          lineTotalMinor: (index + 1) * 5000,
        ),
      );
      final bytes = await service.generate(_model(items: items));
      final text = _extractText(bytes);
      for (var index = 1; index <= count; index++) {
        expect(' $text ', contains(' Snapshot item $index unique '));
      }
    }
  });

  test('corrupt or missing logo falls back to text branding', () async {
    final bytes = await service.generate(
      _model(logo: Uint8List.fromList([1, 2, 3, 4, 5])),
    );
    expect(_extractText(bytes), contains('EURO TECH'));
  });

  test('empty invoice fails with an understandable error', () async {
    await expectLater(
      service.generate(_model(items: const [])),
      throwsA(isA<InvoicePdfException>()),
    );
  });

  test(
    'generation after database reopen does not mutate financial records',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('euro_tech_pdf_');
      final database = AppDatabase.forTesting(
        factory: databaseFactoryFfi,
        databasePath: p.join(directory.path, 'test.sqlite'),
      );
      await database.initialize();
      final db = database.database;
      final now = DateTime.now().toUtc().toIso8601String();
      final customerId = await db.insert('customers', {
        'name': 'PDF Customer',
        'phone': '03009999999',
        'address': 'Rawalpindi',
        'notes': '',
        'save_token': 'pdf-customer',
        'created_at': now,
        'updated_at': now,
      });
      final invoice = await InvoiceRepository(database).save(
        InvoiceSaveInput(
          customerId: customerId,
          issueDate: DateTime(2026, 9, 1),
          items: const [
            InvoiceLineInput(
              description: 'Persisted Snapshot Service',
              quantity: 5,
              unit: 'piece',
              unitPriceMinor: 8000,
            ),
          ],
          discountMinor: 5000,
          saveToken: 'pdf-invoice',
        ),
      );
      await database.close();
      await database.initialize();
      final before = await _financialSnapshot(database);
      final data = InvoicePrintDataService(
        InvoiceRepository(database),
        CompanySettingsRepository(database),
        PrintingSettingsRepository(database),
      );
      final bytes = await service.generate(await data.load(invoice.id));
      final after = await _financialSnapshot(database);
      expect(bytes, isNotEmpty);
      expect(after, before);
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}

class _RecordingPrintingService implements InvoicePrintingService {
  _RecordingPrintingService(this.model);

  final InvoicePrintModel model;
  final calls = <String>[];

  @override
  Future<(InvoicePrintModel, Uint8List)> generate(int invoiceId) async {
    calls.add('preview:$invoiceId');
    return (model, Uint8List(0));
  }

  @override
  Future<bool> printInvoice(int invoiceId) async {
    calls.add('print:$invoiceId');
    return true;
  }

  @override
  Future<String?> exportPdf(int invoiceId) async {
    calls.add('export:$invoiceId');
    return null;
  }
}

InvoicePrintModel _model({
  String status = 'unpaid',
  int price = 35000,
  int paid = 0,
  int? balance,
  int discount = 0,
  int? subtotal,
  int? grandTotal,
  List<InvoiceDetailItem>? items,
  Uint8List? logo,
  PrintingSettings settings = const PrintingSettings(),
}) {
  final lines =
      items ??
      [
        InvoiceDetailItem(
          description: 'Historical Sheet Cutting',
          quantity: 1,
          unit: 'piece',
          unitPriceMinor: price,
          lineTotalMinor: price,
        ),
      ];
  final int calculatedSubtotal =
      subtotal ?? lines.fold<int>(0, (sum, item) => sum + item.lineTotalMinor);
  final int total = grandTotal ?? calculatedSubtotal - discount;
  return InvoicePrintModel(
    company: const CompanySettings(
      companyName: 'Euro Tech Edging and Cutting',
      ownerName: 'Mirza Farhan Ali',
      primaryPhone: '03038549491',
      secondaryPhone: '03493668931',
      additionalContactName: 'Ameer Hamza',
      additionalContactPhone: '03488917817',
      email: 'hamzamirza11579@gmail.com',
      address:
          'Pakistan Market, Gudam # A320, City Saddar, Jinnah Road, Rawalpindi, Pakistan.',
    ),
    invoice: InvoiceDetail(
      id: 321,
      invoiceNumber: 'ET-000321',
      issueDate: DateTime(2026, 9, 1),
      customerName: 'Alpha Furniture',
      customerPhone: '03001234567',
      customerAddress: 'Rawalpindi',
      items: lines,
      subtotalMinor: calculatedSubtotal,
      discountMinor: discount,
      grandTotalMinor: total,
      paymentStatus: status,
      paidMinor: paid,
      balanceMinor: balance ?? total - paid,
    ),
    settings: settings,
    balanceAsOf: DateTime(2026, 9, 2, 10, 30),
    logoBytes: logo,
  );
}

List<(double, double)> _mediaBoxes(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final matches = RegExp(
    r'/MediaBox\s*\[\s*0\s+0\s+([0-9.]+)\s+([0-9.]+)\s*\]',
  ).allMatches(text);
  return matches
      .map(
        (match) =>
            (double.parse(match.group(1)!), double.parse(match.group(2)!)),
      )
      .toList();
}

int _pageCount(Uint8List bytes) => RegExp(
  r'/Type\s*/Page\b',
).allMatches(latin1.decode(bytes, allowInvalid: true)).length;

String _extractText(Uint8List bytes) {
  final source = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r'\(([^()]*)\)')
      .allMatches(source)
      .map(
        (match) =>
            match.group(1)!.replaceAll(r'\(', '(').replaceAll(r'\)', ')'),
      )
      .join(' ');
}

Future<String> _financialSnapshot(AppDatabase database) async {
  final result = <String, Object?>{};
  for (final table in ['invoices', 'invoice_items', 'payments', 'audit_logs']) {
    result[table] = await database.database.query(table, orderBy: 'id');
  }
  return jsonEncode(result);
}
