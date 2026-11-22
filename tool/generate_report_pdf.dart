import 'dart:io';

import 'package:eurotechbilling/features/reports/domain/report_models.dart';
import 'package:eurotechbilling/features/reports/services/report_export_service.dart';

Future<void> main() async {
  final report = ReportSnapshot(
    range: ReportRange(DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
    invoicedMinor: 87545000,
    collectedMinor: 61230000,
    outstandingMinor: 26315000,
    invoiceCount: 38,
    statusBreakdown: const [
      ReportNamedAmount('Paid', 52000000, count: 20),
      ReportNamedAmount('Partially paid', 24045000, count: 11),
      ReportNamedAmount('Unpaid', 11500000, count: 7),
    ],
    topCustomers: const [
      ReportNamedAmount('Rawalpindi Furniture Works', 26000000, count: 8),
      ReportNamedAmount('City Interior Studio', 18550000, count: 7),
      ReportNamedAmount('Modern Wood Craft', 14200000, count: 5),
      ReportNamedAmount('Walk-in Customer', 7250000, count: 10),
    ],
    productSales: const [
      ReportNamedAmount('Sheet Cutting', 38200000, count: 96),
      ReportNamedAmount('Edging and Taping', 29945000, count: 224),
      ReportNamedAmount('Custom Workshop Service', 19400000, count: 18),
    ],
    outstandingCustomers: const [
      ReportNamedAmount('Rawalpindi Furniture Works', 11200000, count: 3),
      ReportNamedAmount('Modern Wood Craft', 7950000, count: 2),
      ReportNamedAmount('City Interior Studio', 7165000, count: 4),
    ],
  );
  final output = File('output/pdf/euro_tech_report_sample.pdf');
  await output.parent.create(recursive: true);
  await output.writeAsBytes(
    await ReportExportService().buildPdf(report),
    flush: true,
  );
  stdout.writeln(output.absolute.path);
}
