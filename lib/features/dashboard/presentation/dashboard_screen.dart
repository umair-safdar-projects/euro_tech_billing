import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency.dart';
import '../../../core/widgets/page_header.dart';
import '../../customers/presentation/customers_controller.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../invoices/presentation/invoice_editor_controller.dart';
import '../../shell/domain/shell_destination.dart';
import '../../shell/presentation/shell_controller.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    final data = controller.snapshot.value;
    if (controller.isLoading.value && data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data == null) {
      return Center(
        child: OutlinedButton(
          onPressed: controller.load,
          child: const Text('Reload dashboard'),
        ),
      );
    }
    final metrics = [
      (
        'Today’s invoiced sales',
        Currency.formatMinor(data.todaySalesMinor),
        Icons.receipt_long_rounded,
        Colors.blue,
      ),
      (
        'Today’s payments received',
        Currency.formatMinor(data.todayCollectionsMinor),
        Icons.payments_rounded,
        Colors.green,
      ),
      (
        'Outstanding credit',
        Currency.formatMinor(data.outstandingMinor),
        Icons.account_balance_wallet_rounded,
        Colors.orange,
      ),
      (
        'Invoices today',
        '${data.todayInvoiceCount}',
        Icons.description_rounded,
        Colors.indigo,
      ),
    ];
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          PageHeader(
            title: 'Dashboard',
            subtitle:
                'Real invoicing, collections, and credit as of ${DateFormat('dd MMM yyyy').format(DateTime.now())}.',
            action: IconButton(
              onPressed: controller.load,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 24),
          _quickActions(context),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > 900
                  ? (constraints.maxWidth - 42) / 4
                  : (constraints.maxWidth - 14) / 2;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: metrics
                    .map(
                      (metric) => SizedBox(
                        width: width,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(metric.$3, color: metric.$4),
                                const SizedBox(height: 16),
                                Text(
                                  metric.$2,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  metric.$1,
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final invoices = _activityCard(
                context,
                'Recent invoices',
                data.recentInvoices.isEmpty
                    ? const [Text('No invoices yet.')]
                    : data.recentInvoices
                          .map(
                            (item) => ListTile(
                              dense: true,
                              title: Text(item.invoiceNumber),
                              subtitle: Text(
                                '${item.customerName} • ${DateFormat('dd MMM').format(item.issueDate)}',
                              ),
                              trailing: Text(
                                Currency.formatMinor(item.grandTotalMinor),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
              );
              final payments = _activityCard(
                context,
                'Recent payments',
                data.recentPayments.isEmpty
                    ? const [Text('No payments yet.')]
                    : data.recentPayments
                          .map(
                            (item) => ListTile(
                              dense: true,
                              title: Text(item.invoiceNumber),
                              subtitle: Text(
                                '${item.customerName} • ${DateFormat('dd MMM').format(item.paymentDate)}',
                              ),
                              trailing: Text(
                                Currency.formatMinor(item.amountMinor),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          )
                          .toList(),
              );
              return constraints.maxWidth < 800
                  ? Column(
                      children: [
                        invoices,
                        const SizedBox(height: 14),
                        payments,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: invoices),
                        const SizedBox(width: 14),
                        Expanded(child: payments),
                      ],
                    );
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'Invoiced sales represent issued work. Payments received represent cash collected, including receipts against older invoices.',
            style: TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    );
  });

  Widget _quickActions(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Quick actions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          FilledButton.icon(
            onPressed: () => _open(ShellDestination.newInvoice),
            icon: const Icon(Icons.note_add_rounded),
            label: const Text('New invoice'),
          ),
          OutlinedButton.icon(
            onPressed: () => _openCustomer(context),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add customer'),
          ),
          OutlinedButton.icon(
            onPressed: () => _open(ShellDestination.reports),
            icon: const Icon(Icons.bar_chart_rounded),
            label: const Text('View reports'),
          ),
        ],
      ),
    ),
  );

  Future<void> _open(ShellDestination destination) async {
    if (!Get.isRegistered<ShellController>()) return;
    Get.find<ShellController>().selectDestination(destination);
    if (destination == ShellDestination.newInvoice &&
        Get.isRegistered<InvoiceEditorController>()) {
      await Get.find<InvoiceEditorController>().loadLookups();
    }
  }

  Future<void> _openCustomer(BuildContext context) async {
    if (!Get.isRegistered<ShellController>() ||
        !Get.isRegistered<CustomersController>()) {
      return;
    }
    final customers = Get.find<CustomersController>();
    Get.find<ShellController>().selectDestination(ShellDestination.customers);
    await customers.load();
    if (context.mounted) showCustomerDialog(context, customers);
  }

  Widget _activityCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
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
          ...children,
        ],
      ),
    ),
  );
}
