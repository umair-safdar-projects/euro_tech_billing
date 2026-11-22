import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency.dart';
import '../../../core/widgets/page_header.dart';
import 'invoice_detail_view.dart';
import 'invoice_history_controller.dart';
import '../../printing/presentation/invoice_print_actions.dart';

class InvoiceHistoryScreen extends GetView<InvoiceHistoryController> {
  const InvoiceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Invoice History',
            subtitle: 'Search and review finalized invoices.',
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Invoice number or customer name',
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => controller.search.value = value,
                onSubmitted: (_) => controller.load(targetPage: 1),
              );
              final filter = OutlinedButton.icon(
                onPressed: () => _pickDates(context),
                icon: const Icon(Icons.date_range_rounded),
                label: Obx(() {
                  if (controller.from.value == null) {
                    return const Text('Date range');
                  }
                  return Text(
                    '${DateFormat('dd MMM').format(controller.from.value!)} – ${DateFormat('dd MMM').format(controller.to.value!)}',
                  );
                }),
              );
              final clear = Obx(
                () => controller.from.value == null
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: () => controller.setRange(null),
                        child: const Text('Clear dates'),
                      ),
              );
              return constraints.maxWidth < 720
                  ? Column(
                      children: [
                        search,
                        const SizedBox(height: 10),
                        Row(children: [filter, clear]),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 12),
                        filter,
                        clear,
                      ],
                    );
            },
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Card(
              child: Obx(() {
                if (controller.isLoading.value && controller.invoices.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.invoices.isEmpty) {
                  return const Center(
                    child: Text('No invoices match these filters.'),
                  );
                }
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('INVOICE')),
                              DataColumn(label: Text('DATE')),
                              DataColumn(label: Text('CUSTOMER')),
                              DataColumn(label: Text('TOTAL'), numeric: true),
                              DataColumn(label: Text('PAYMENT STATUS')),
                              DataColumn(label: Text('')),
                            ],
                            rows: controller.invoices
                                .map(
                                  (invoice) => DataRow(
                                    onSelectChanged: (_) =>
                                        _openDetail(context, invoice.id),
                                    cells: [
                                      DataCell(
                                        Text(
                                          invoice.invoiceNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          DateFormat(
                                            'dd MMM yyyy',
                                          ).format(invoice.issueDate),
                                        ),
                                      ),
                                      DataCell(Text(invoice.customerName)),
                                      DataCell(
                                        Text(
                                          Currency.formatMinor(
                                            invoice.grandTotalMinor,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        _StatusLabel(invoice.paymentStatus),
                                      ),
                                      DataCell(
                                        IconButton(
                                          tooltip: 'Preview invoice',
                                          onPressed: () => showInvoicePreview(
                                            context,
                                            invoice.id,
                                          ),
                                          icon: const Icon(
                                            Icons.preview_rounded,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${controller.total.value} invoice${controller.total.value == 1 ? '' : 's'}',
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: controller.page.value > 1
                                ? () => controller.load(
                                    targetPage: controller.page.value - 1,
                                  )
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Text(
                            'Page ${controller.page.value} of ${controller.totalPages}',
                          ),
                          IconButton(
                            onPressed:
                                controller.page.value < controller.totalPages
                                ? () => controller.load(
                                    targetPage: controller.page.value + 1,
                                  )
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDates(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: controller.from.value == null
          ? null
          : DateTimeRange(
              start: controller.from.value!,
              end: controller.to.value!,
            ),
    );
    if (range != null) {
      controller.setRange(DateTimeRangeValue(range.start, range.end));
    }
  }

  Future<void> _openDetail(BuildContext context, int id) async {
    final detail = await controller.detail(id);
    if (detail != null && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => InvoiceDetailDialog(detail: detail),
      );
    }
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel(this.status);
  final String status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: status == 'paid' ? Colors.green.shade50 : Colors.orange.shade50,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status.replaceAll('_', ' ').toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: status == 'paid'
            ? Colors.green.shade800
            : Colors.orange.shade900,
      ),
    ),
  );
}
