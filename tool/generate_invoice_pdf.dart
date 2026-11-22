import 'dart:io';

import 'package:eurotechbilling/features/invoices/domain/invoice_models.dart';
import 'package:eurotechbilling/features/printing/domain/printing_models.dart';
import 'package:eurotechbilling/features/printing/services/invoice_pdf_service.dart';
import 'package:eurotechbilling/features/settings/domain/company_settings.dart';

Future<void> main(List<String> arguments) async {
  final itemCount = arguments.isEmpty ? 15 : int.parse(arguments.first);
  final outputPath = arguments.length < 2
      ? 'output/pdf/euro_tech_invoice_sample.pdf'
      : arguments[1];
  final items = List.generate(
    itemCount,
    (index) => InvoiceDetailItem(
      description: index == 7
          ? 'Custom edging, precision cutting, taping, finishing, and detailed workshop handling for customer-supplied sheet material'
          : 'Edging and cutting service - batch ${index + 1}',
      quantity: index + 1,
      unit: 'piece',
      unitPriceMinor: 3000 + index * 500,
      lineTotalMinor: (index + 1) * (3000 + index * 500),
    ),
  );
  final subtotal = items.fold<int>(0, (sum, item) => sum + item.lineTotalMinor);
  final model = InvoicePrintModel(
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
      id: 42,
      invoiceNumber: 'ET-000042',
      issueDate: DateTime(2026, 11, 22),
      customerName: 'Sample Furniture Works',
      customerPhone: '03001234567',
      customerAddress: 'Rawalpindi, Pakistan',
      items: items,
      subtotalMinor: subtotal,
      discountMinor: 5000,
      grandTotalMinor: subtotal - 5000,
      paymentStatus: 'partially_paid',
      paidMinor: 150000,
      balanceMinor: subtotal - 155000,
    ),
    settings: const PrintingSettings(
      footerMessage: 'Thank you for your business!',
    ),
    balanceAsOf: DateTime(2026, 11, 22, 15, 30),
  );
  final output = File(outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsBytes(
    await InvoicePdfService().generate(model),
    flush: true,
  );
  stdout.writeln(output.absolute.path);
}
