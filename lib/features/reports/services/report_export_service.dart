import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/report_models.dart';

class ReportExportService {
  String buildCsv(ReportSnapshot report) {
    final rows = <List<Object>>[
      ['Euro Tech Billing Report'],
      ['From', DateFormat('yyyy-MM-dd').format(report.range.from)],
      ['To', DateFormat('yyyy-MM-dd').format(report.range.to)],
      ['Invoiced Sales (PKR)', _decimal(report.invoicedMinor)],
      ['Payments Collected (PKR)', _decimal(report.collectedMinor)],
      ['Current Outstanding Credit (PKR)', _decimal(report.outstandingMinor)],
      [],
      ['Invoice Status', 'Invoices', 'Amount (PKR)'],
      ...report.statusBreakdown.map(
        (r) => [r.name, r.count, _decimal(r.amountMinor)],
      ),
      [],
      ['Top Customers', 'Invoices', 'Invoiced (PKR)'],
      ...report.topCustomers.map(
        (r) => [r.name, r.count, _decimal(r.amountMinor)],
      ),
      [],
      ['Product / Service', 'Quantity', 'Sales (PKR)'],
      ...report.productSales.map(
        (r) => [r.name, r.count, _decimal(r.amountMinor)],
      ),
      [],
      ['Outstanding Customer', 'Invoices', 'Balance (PKR)'],
      ...report.outstandingCustomers.map(
        (r) => [r.name, r.count, _decimal(r.amountMinor)],
      ),
    ];
    return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  Future<Uint8List> buildPdf(ReportSnapshot report) async {
    final document = pw.Document(
      title: 'Euro Tech Sales Report',
      author: 'Euro Tech Edging and Cutting',
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'EURO TECH',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('EDGING AND CUTTING - SALES REPORT'),
            pw.SizedBox(height: 8),
            pw.Text(
              '${DateFormat('dd MMM yyyy').format(report.range.from)} - ${DateFormat('dd MMM yyyy').format(report.range.to)}',
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
        ),
        build: (context) => [
          pw.Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _metric('Invoiced sales', report.invoicedMinor),
              _metric('Payments collected', report.collectedMinor),
              _metric('Current outstanding', report.outstandingMinor),
            ],
          ),
          pw.SizedBox(height: 18),
          _table('Invoice status', report.statusBreakdown, 'Invoices'),
          _table('Top customers', report.topCustomers, 'Invoices'),
          _table('Product / service sales', report.productSales, 'Quantity'),
          _table(
            'Outstanding customer credit',
            report.outstandingCustomers,
            'Invoices',
          ),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _metric(String label, int amount) => pw.Container(
    width: 165,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.blueGrey200),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(color: PdfColors.blueGrey700, fontSize: 9),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _pkr(amount),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  pw.Widget _table(
    String title,
    List<ReportNamedAmount> rows,
    String countLabel,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 14),
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 5),
      if (rows.isEmpty)
        pw.Text('No data for this report.')
      else
        pw.TableHelper.fromTextArray(
          headers: ['Name', countLabel, 'Amount'],
          data: rows
              .map((r) => [r.name, r.count, _pkr(r.amountMinor)])
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.blueGrey100,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
    ],
  );

  String _decimal(int minor) => (minor / 100).toStringAsFixed(2);
  String _pkr(int minor) =>
      'PKR ${NumberFormat('#,##0.00', 'en_US').format(minor / 100)}';
  String _csvCell(Object value) {
    var text = value.toString();
    if (RegExp(r'^[=+\-@]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }
}
