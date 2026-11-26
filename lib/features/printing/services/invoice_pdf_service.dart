import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/printing_models.dart';

class InvoicePdfException implements Exception {
  const InvoicePdfException(this.message, [this.cause]);
  final String message;
  final Object? cause;
  @override
  String toString() => message;
}

class InvoicePageLayout {
  const InvoicePageLayout({
    required this.pageFormat,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
  final PdfPageFormat pageFormat;
  final double left;
  final double top;
  final double right;
  final double bottom;
  double get contentWidth => pageFormat.width - left - right;
  double get contentHeight => pageFormat.height - top - bottom;
}

class InvoicePdfService {
  static final PdfPageFormat a5 = PdfPageFormat(
    148 * PdfPageFormat.mm,
    210 * PdfPageFormat.mm,
  );
  static const _innerMargin = 7.0 * PdfPageFormat.mm;
  static const _navy = PdfColor.fromInt(0xFF102A43);
  static const _muted = PdfColor.fromInt(0xFF52667A);
  static const _border = PdfColor.fromInt(0xFFD9E2EC);

  InvoicePageLayout layoutFor(PrintingSettings settings) {
    if (settings.paper == InvoicePaper.a5) {
      return InvoicePageLayout(
        pageFormat: a5,
        left: _innerMargin,
        top: _innerMargin,
        right: _innerMargin,
        bottom: _innerMargin,
      );
    }
    final page = PdfPageFormat.a4;
    final outerLeft = settings.a4Placement == A4Placement.centered
        ? (page.width - a5.width) / 2
        : 5 * PdfPageFormat.mm;
    final outerTop = settings.a4Placement == A4Placement.centered
        ? (page.height - a5.height) / 2
        : 5 * PdfPageFormat.mm;
    return InvoicePageLayout(
      pageFormat: page,
      left: outerLeft + _innerMargin,
      top: outerTop + _innerMargin,
      right: page.width - outerLeft - a5.width + _innerMargin,
      bottom: page.height - outerTop - a5.height + _innerMargin,
    );
  }

  Future<Uint8List> generate(InvoicePrintModel model) async {
    if (model.invoice.items.isEmpty) {
      throw const InvoicePdfException('Invoice has no printable items.');
    }
    try {
      return await _generate(model);
    } catch (error) {
      if (model.logoBytes != null) {
        try {
          return await _generate(model.withoutLogo());
        } catch (fallbackError) {
          throw InvoicePdfException(
            'Unable to generate the invoice PDF.',
            fallbackError,
          );
        }
      }
      throw InvoicePdfException('Unable to generate the invoice PDF.', error);
    }
  }

  Future<Uint8List> _generate(InvoicePrintModel model) async {
    final document = pw.Document(
      compress: false,
      title: 'Invoice ${model.invoice.invoiceNumber}',
      author: model.company.companyName,
      creator: 'Euro Tech Billing System',
    );
    final layout = layoutFor(model.settings);
    final pageTheme = pw.PageTheme(
      pageFormat: layout.pageFormat,
      margin: pw.EdgeInsets.fromLTRB(
        layout.left,
        layout.top,
        layout.right,
        layout.bottom,
      ),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );
    final logo = model.logoBytes == null
        ? null
        : pw.MemoryImage(model.logoBytes!);

    document.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        maxPages: 50,
        header: (context) =>
            _header(model, logo, continuation: context.pageNumber > 1),
        footer: (context) => _footer(model, context),
        build: (context) => [
          _customer(model),
          pw.SizedBox(height: 4 * PdfPageFormat.mm),
          _itemsTable(model),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          _totals(model),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _header(
    InvoicePrintModel model,
    pw.ImageProvider? logo, {
    required bool continuation,
  }) {
    final identity = _identity(model.company.companyName);
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) ...[
              pw.Container(
                width: 22 * PdfPageFormat.mm,
                height: 22 * PdfPageFormat.mm,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 3 * PdfPageFormat.mm),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    identity.$1,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                      letterSpacing: .8,
                    ),
                  ),
                  pw.Text(
                    identity.$2,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 2.5 * PdfPageFormat.mm),
                  pw.Text(
                    model.company.address,
                    style: const pw.TextStyle(fontSize: 6.6, color: _muted),
                    maxLines: 3,
                  ),
                  pw.Text(
                    _contacts(model),
                    style: const pw.TextStyle(fontSize: 6.6, color: _muted),
                  ),
                  if (model.company.email.trim().isNotEmpty)
                    pw.Text(
                      model.company.email.trim(),
                      style: const pw.TextStyle(fontSize: 6.6, color: _muted),
                    ),
                ],
              ),
            ),
            pw.SizedBox(width: 4 * PdfPageFormat.mm),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  model.invoice.invoiceNumber,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  DateFormat('dd MMM yyyy').format(model.invoice.issueDate),
                  style: const pw.TextStyle(fontSize: 7),
                ),
                if (continuation)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Text(
                      'CONTINUED',
                      style: pw.TextStyle(
                        fontSize: 6,
                        fontWeight: pw.FontWeight.bold,
                        color: _muted,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 3 * PdfPageFormat.mm),
        pw.Divider(color: _navy, thickness: 1),
        pw.SizedBox(height: 2 * PdfPageFormat.mm),
      ],
    );
  }

  pw.Widget _customer(InvoicePrintModel model) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(7),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _border, width: .6),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'BILL TO',
          style: pw.TextStyle(
            fontSize: 6.5,
            fontWeight: pw.FontWeight.bold,
            color: _muted,
            letterSpacing: .8,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          model.invoice.customerName,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        ),
        if (model.invoice.customerPhone.isNotEmpty)
          pw.Text(
            model.invoice.customerPhone,
            style: const pw.TextStyle(fontSize: 7),
          ),
        if (model.invoice.customerAddress.isNotEmpty)
          pw.Text(
            model.invoice.customerAddress,
            style: const pw.TextStyle(fontSize: 7),
            maxLines: 2,
          ),
      ],
    ),
  );

  pw.Widget _itemsTable(InvoicePrintModel model) =>
      pw.TableHelper.fromTextArray(
        headers: const [
          'Sr.',
          'Description / Particulars',
          'Qty\n(Pcs)',
          'Rate\n(PKR)',
          'Amount\n(PKR)',
        ],
        data: [
          for (var index = 0; index < model.invoice.items.length; index++)
            [
              '${index + 1}',
              model.invoice.items[index].description,
              '${model.invoice.items[index].quantity}',
              _money(model.invoice.items[index].unitPriceMinor),
              _money(model.invoice.items[index].lineTotalMinor),
            ],
        ],
        headerCount: 1,
        headerDecoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFEAF0F5),
        ),
        headerStyle: pw.TextStyle(
          fontSize: 6.6,
          fontWeight: pw.FontWeight.bold,
          color: _navy,
        ),
        cellStyle: const pw.TextStyle(fontSize: 7),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        border: pw.TableBorder.all(color: _border, width: .5),
        columnWidths: const {
          0: pw.FlexColumnWidth(.45),
          1: pw.FlexColumnWidth(3.2),
          2: pw.FlexColumnWidth(.75),
          3: pw.FlexColumnWidth(1.15),
          4: pw.FlexColumnWidth(1.25),
        },
        cellAlignments: const {
          0: pw.Alignment.center,
          2: pw.Alignment.center,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        },
      );

  pw.Widget _totals(InvoicePrintModel model) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border, width: .5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PAYMENT STATUS',
                style: pw.TextStyle(
                  fontSize: 6.3,
                  color: _muted,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                model.invoice.paymentStatus.replaceAll('_', ' ').toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _navy,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Balance as of ${DateFormat('dd MMM yyyy, hh:mm a').format(model.balanceAsOf)}',
                style: const pw.TextStyle(fontSize: 5.8, color: _muted),
              ),
            ],
          ),
        ),
      ),
      pw.SizedBox(width: 4 * PdfPageFormat.mm),
      pw.SizedBox(
        width: 63 * PdfPageFormat.mm,
        child: pw.Column(
          children: [
            _totalRow('Subtotal', model.invoice.subtotalMinor),
            if (model.invoice.discountMinor > 0)
              _totalRow('Discount', model.invoice.discountMinor),
            pw.Container(
              color: _navy,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 6,
              ),
              child: _totalRow(
                'GRAND TOTAL',
                model.invoice.grandTotalMinor,
                inverse: true,
              ),
            ),
            _totalRow('Total Received', model.invoice.paidMinor),
            _totalRow(
              'Remaining Balance',
              model.invoice.balanceMinor,
              strong: true,
            ),
          ],
        ),
      ),
    ],
  );

  pw.Widget _totalRow(
    String label,
    int value, {
    bool strong = false,
    bool inverse = false,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
    decoration: inverse
        ? null
        : const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _border, width: .4)),
          ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: strong || inverse
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            color: inverse ? PdfColors.white : PdfColors.black,
          ),
        ),
        pw.Text(
          'PKR ${_money(value)}',
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: strong || inverse
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            color: inverse ? PdfColors.white : PdfColors.black,
          ),
        ),
      ],
    ),
  );

  pw.Widget _footer(InvoicePrintModel model, pw.Context context) => pw.Column(
    children: [
      pw.Divider(color: _border, thickness: .5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Owner: ${model.company.ownerName}',
            style: const pw.TextStyle(fontSize: 5.8, color: _muted),
          ),
          pw.Text(
            model.settings.footerMessage.isEmpty
                ? 'Thank you for your business!'
                : model.settings.footerMessage,
            style: pw.TextStyle(
              fontSize: 5.8,
              color: _muted,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 5.8, color: _muted),
          ),
        ],
      ),
    ],
  );

  (String, String) _identity(String companyName) {
    final upper = companyName.trim().toUpperCase();
    const subtitle = 'EDGING AND CUTTING';
    if (upper.contains(subtitle)) {
      final heading = upper.replaceFirst(subtitle, '').trim();
      return (heading.isEmpty ? 'EURO TECH' : heading, subtitle);
    }
    return (upper, 'EDGING AND CUTTING');
  }

  String _contacts(InvoicePrintModel model) {
    final owner = model.company.ownerName.trim();
    final additionalContact = model.company.additionalContactName.trim();
    final values = <String>[
      if (model.company.primaryPhone.trim().isNotEmpty)
        _labeledPhone(owner, model.company.primaryPhone),
      if (model.company.secondaryPhone.trim().isNotEmpty)
        _labeledPhone(owner, model.company.secondaryPhone),
      if (model.company.additionalContactPhone.trim().isNotEmpty)
        _labeledPhone(additionalContact, model.company.additionalContactPhone),
    ];
    return values.join(' | ');
  }

  String _labeledPhone(String label, String phone) =>
      label.isEmpty ? phone.trim() : '$label: ${phone.trim()}';

  String _money(int minor) {
    final whole = NumberFormat('#,##0', 'en_US').format(minor ~/ 100);
    final fraction = minor.remainder(100).abs().toString().padLeft(2, '0');
    return '$whole.$fraction';
  }
}
