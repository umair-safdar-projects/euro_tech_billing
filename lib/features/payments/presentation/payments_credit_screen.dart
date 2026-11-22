import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency.dart';
import '../../../core/widgets/page_header.dart';
import '../../credit/presentation/customer_ledger_dialog.dart';
import '../domain/payment_models.dart';
import 'payment_dialogs.dart';
import 'payments_credit_controller.dart';

class PaymentsCreditScreen extends GetView<PaymentsCreditController> {
  const PaymentsCreditScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Payments / Credit',
            subtitle:
                'Collected cash and outstanding credit are tracked separately.',
            action: ElevatedButton.icon(
              onPressed: () => _selectInvoice(context),
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Record payment'),
            ),
          ),
          const SizedBox(height: 20),
          const TabBar(
            tabs: [
              Tab(text: 'Credit Overview'),
              Tab(text: 'Payments'),
              Tab(text: 'Outstanding Customers'),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value &&
                  controller.creditSummary.value == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return TabBarView(
                children: [
                  _credit(context),
                  _payments(context),
                  _customers(context),
                ],
              );
            }),
          ),
        ],
      ),
    ),
  );

  Widget _credit(BuildContext context) {
    final summary = controller.creditSummary.value;
    if (summary == null) {
      return const Center(child: Text('Credit information is unavailable.'));
    }
    return ListView(
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _summaryCard(
              context,
              'Outstanding credit',
              Currency.formatMinor(summary.outstandingMinor),
              Icons.account_balance_wallet_rounded,
            ),
            _summaryCard(
              context,
              'Customers with credit',
              '${summary.customerCount}',
              Icons.people_alt_rounded,
            ),
            _summaryCard(
              context,
              'Unpaid invoices',
              '${summary.unpaidCount}',
              Icons.receipt_long_rounded,
            ),
            _summaryCard(
              context,
              'Partially paid',
              '${summary.partialCount}',
              Icons.pie_chart_rounded,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Highest outstanding balances',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Card(
          child: controller.outstandingCustomers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No outstanding customer credit.')),
                )
              : Column(
                  children: controller.outstandingCustomers
                      .take(10)
                      .map(
                        (customer) => ListTile(
                          title: Text(customer.name),
                          subtitle: Text(
                            customer.phone.isEmpty
                                ? 'No phone number'
                                : customer.phone,
                          ),
                          trailing: Text(
                            Currency.formatMinor(customer.outstandingMinor),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          onTap: () =>
                              _openLedger(context, customer.customerId),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _payments(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Customer or invoice number',
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) => controller.search.value = value,
              onSubmitted: (_) => controller.refreshAll(targetPage: 1),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () => _pickDates(context),
            icon: const Icon(Icons.date_range_rounded),
            label: const Text('Date range'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          'Collected in filter: ${Currency.formatMinor(controller.collectedMinor.value)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: Card(
          child: controller.payments.isEmpty
              ? const Center(child: Text('No payments match these filters.'))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('DATE')),
                              DataColumn(label: Text('INVOICE')),
                              DataColumn(label: Text('CUSTOMER')),
                              DataColumn(label: Text('METHOD')),
                              DataColumn(label: Text('AMOUNT'), numeric: true),
                            ],
                            rows: controller.payments
                                .map(
                                  (payment) => DataRow(
                                    onSelectChanged: (_) =>
                                        showPaymentDetailDialog(
                                          context,
                                          payment,
                                        ),
                                    cells: [
                                      DataCell(
                                        Text(
                                          DateFormat(
                                            'dd MMM yyyy',
                                          ).format(payment.paymentDate),
                                        ),
                                      ),
                                      DataCell(Text(payment.invoiceNumber)),
                                      DataCell(Text(payment.customerName)),
                                      DataCell(
                                        Text(
                                          payment.method
                                              .replaceAll('_', ' ')
                                              .toUpperCase(),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          Currency.formatMinor(
                                            payment.amountMinor,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: controller.page.value > 1
                              ? () => controller.refreshAll(
                                  targetPage: controller.page.value - 1,
                                )
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          'Page ${controller.page.value} of ${controller.totalPages}',
                        ),
                        IconButton(
                          onPressed:
                              controller.page.value < controller.totalPages
                              ? () => controller.refreshAll(
                                  targetPage: controller.page.value + 1,
                                )
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    ],
  );

  Widget _customers(BuildContext context) => Column(
    children: [
      TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded),
          hintText: 'Search outstanding customers by name or phone',
        ),
        textInputAction: TextInputAction.search,
        onChanged: (value) => controller.search.value = value,
        onSubmitted: (_) => controller.refreshAll(targetPage: 1),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: Card(
          child: controller.outstandingCustomers.isEmpty
              ? const Center(
                  child: Text('No customers have outstanding balances.'),
                )
              : ListView.separated(
                  itemCount: controller.outstandingCustomers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final customer = controller.outstandingCustomers[index];
                    return ListTile(
                      title: Text(customer.name),
                      subtitle: Text(
                        '${customer.phone.isEmpty ? 'No phone' : customer.phone} • Invoiced ${Currency.formatMinor(customer.totalInvoicedMinor)} • Received ${Currency.formatMinor(customer.totalReceivedMinor)}',
                      ),
                      trailing: Text(
                        Currency.formatMinor(customer.outstandingMinor),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.orange,
                        ),
                      ),
                      onTap: () => _openLedger(context, customer.customerId),
                    );
                  },
                ),
        ),
      ),
    ],
  );

  Widget _summaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) => SizedBox(
    width: 245,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, style: const TextStyle(color: Colors.blueGrey)),
          ],
        ),
      ),
    ),
  );

  Future<void> _selectInvoice(BuildContext context) async {
    final invoices = await controller.payableInvoices('');
    if (!context.mounted) return;
    if (invoices.isEmpty) {
      Get.snackbar(
        'No payable invoices',
        'All eligible invoices have been paid.',
      );
      return;
    }
    final selected = await showDialog<InvoiceBalance>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select an invoice'),
        children: invoices
            .map(
              (invoice) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, invoice),
                child: ListTile(
                  title: Text(invoice.invoiceNumber),
                  subtitle: Text(invoice.customerName),
                  trailing: Text(Currency.formatMinor(invoice.balanceMinor)),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null && context.mounted) {
      final payment = await showRecordPaymentDialog(
        context,
        selected.invoiceId,
      );
      if (payment != null) {
        Get.snackbar(
          'Payment recorded',
          '${Currency.formatMinor(payment.amountMinor)} received for ${payment.invoiceNumber}.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(20),
        );
      }
    }
  }

  Future<void> _pickDates(BuildContext context) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: controller.from.value == null
          ? null
          : DateTimeRange(
              start: controller.from.value!,
              end: controller.to.value!,
            ),
    );
    if (range != null) {
      controller.from.value = range.start;
      controller.to.value = range.end;
      await controller.refreshAll(targetPage: 1);
    }
  }

  Future<void> _openLedger(BuildContext context, int customerId) async {
    final ledger = await controller.ledger(customerId);
    if (ledger != null && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => CustomerLedgerDialog(ledger: ledger),
      );
    }
  }
}
