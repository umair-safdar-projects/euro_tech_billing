import 'dart:typed_data';

import '../../invoices/domain/invoice_models.dart';
import '../../settings/domain/company_settings.dart';

enum InvoicePaper { a5, a4 }

enum A4Placement { topLeft, centered }

class PrintingSettings {
  const PrintingSettings({
    this.paper = InvoicePaper.a5,
    this.a4Placement = A4Placement.centered,
    this.footerMessage = 'Thank you for your business!',
  });

  final InvoicePaper paper;
  final A4Placement a4Placement;
  final String footerMessage;
}

class InvoicePrintModel {
  const InvoicePrintModel({
    required this.company,
    required this.invoice,
    required this.settings,
    required this.balanceAsOf,
    this.logoBytes,
  });

  final CompanySettings company;
  final InvoiceDetail invoice;
  final PrintingSettings settings;
  final DateTime balanceAsOf;
  final Uint8List? logoBytes;

  InvoicePrintModel withoutLogo() => InvoicePrintModel(
    company: company,
    invoice: invoice,
    settings: settings,
    balanceAsOf: balanceAsOf,
  );
}
