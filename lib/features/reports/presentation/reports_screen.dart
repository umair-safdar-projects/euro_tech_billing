import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency.dart';
import '../../../core/widgets/page_header.dart';
import '../domain/report_models.dart';
import 'reports_controller.dart';

class ReportsScreen extends GetView<ReportsController> {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    final data = controller.report.value;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        PageHeader(
          title: 'Reports',
          subtitle:
              'Invoiced sales, collected payments, and outstanding credit are reported separately.',
          action: Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: data == null ? null : controller.exportCsv,
                icon: const Icon(Icons.table_view_rounded),
                label: const Text('Export CSV'),
              ),
              OutlinedButton.icon(
                onPressed: data == null ? null : controller.exportPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Export PDF'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.tonal(
              onPressed: controller.setToday,
              child: const Text('Daily'),
            ),
            FilledButton.tonal(
              onPressed: controller.setThisMonth,
              child: const Text('Monthly'),
            ),
            OutlinedButton.icon(
              onPressed: () => controller.chooseRange(context),
              icon: const Icon(Icons.date_range_rounded),
              label: Text(
                '${DateFormat('dd MMM yyyy').format(controller.from)} – ${DateFormat('dd MMM yyyy').format(controller.to)}',
              ),
            ),
            IconButton(
              onPressed: controller.load,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (controller.isLoading.value) const LinearProgressIndicator(),
        if (controller.errorMessage.value case final message?)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(message, style: const TextStyle(color: Colors.red)),
          ),
        if (data != null) ...[
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 42) / 4
                  : (constraints.maxWidth - 14) / 2;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _metric(
                    context,
                    width,
                    'Invoiced sales',
                    data.invoicedMinor,
                    Icons.receipt_long_rounded,
                    Colors.blue,
                  ),
                  _metric(
                    context,
                    width,
                    'Payments collected',
                    data.collectedMinor,
                    Icons.payments_rounded,
                    Colors.green,
                  ),
                  _metric(
                    context,
                    width,
                    'Current outstanding',
                    data.outstandingMinor,
                    Icons.account_balance_wallet_rounded,
                    Colors.orange,
                  ),
                  _metric(
                    context,
                    width,
                    'Invoices in range',
                    null,
                    Icons.description_rounded,
                    Colors.indigo,
                    value: '${data.invoiceCount}',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final first = _table(
                context,
                'Invoice status breakdown',
                data.statusBreakdown,
                'Invoices',
              );
              final second = _table(
                context,
                'Top customers by invoiced amount',
                data.topCustomers,
                'Invoices',
              );
              return constraints.maxWidth < 850
                  ? Column(
                      children: [first, const SizedBox(height: 14), second],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: first),
                        const SizedBox(width: 14),
                        Expanded(child: second),
                      ],
                    );
            },
          ),
          const SizedBox(height: 14),
          _table(
            context,
            'Product / service sales summary',
            data.productSales,
            'Quantity',
          ),
          const SizedBox(height: 14),
          _table(
            context,
            'Outstanding customer credit (current)',
            data.outstandingCustomers,
            'Invoices',
          ),
          const SizedBox(height: 10),
          const Text(
            'Payments are grouped by their actual payment date. A payment against an older invoice is not counted as a sale for the payment day.',
            style: TextStyle(color: Colors.blueGrey),
          ),
        ],
      ],
    );
  });

  Widget _metric(
    BuildContext context,
    double width,
    String label,
    int? amount,
    IconData icon,
    Color color, {
    String? value,
  }) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value ?? Currency.formatMinor(amount!),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.blueGrey)),
          ],
        ),
      ),
    ),
  );

  Widget _table(
    BuildContext context,
    String title,
    List<ReportNamedAmount> rows,
    String countLabel,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No data for this report.',
                style: TextStyle(color: Colors.blueGrey),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('Name')),
                  DataColumn(label: Text(countLabel), numeric: true),
                  const DataColumn(label: Text('Amount'), numeric: true),
                ],
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 250,
                              child: Text(
                                row.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text('${row.count}')),
                          DataCell(Text(Currency.formatMinor(row.amountMinor))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    ),
  );
}
