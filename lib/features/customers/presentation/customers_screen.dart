import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency.dart';
import '../../../core/utils/submission_token.dart';
import '../../../core/widgets/page_header.dart';
import '../../credit/presentation/customer_ledger_dialog.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../invoices/presentation/invoice_detail_view.dart';
import '../../payments/presentation/payments_credit_controller.dart';
import '../domain/customer.dart';
import 'customers_controller.dart';

class CustomersScreen extends GetView<CustomersController> {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Customers',
            subtitle: 'Manage customer details and review invoice history.',
            action: ElevatedButton.icon(
              onPressed: () => showCustomerDialog(context, controller),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add customer'),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search by customer name or phone',
              suffixIcon: Icon(Icons.keyboard_return_rounded),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: controller.load,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 850;
                final list = _customerList(context);
                final detail = _customerDetail(context);
                return narrow
                    ? Column(
                        children: [
                          Expanded(flex: 2, child: list),
                          const SizedBox(height: 14),
                          Expanded(flex: 3, child: detail),
                        ],
                      )
                    : Row(
                        children: [
                          SizedBox(width: 340, child: list),
                          const SizedBox(width: 18),
                          Expanded(child: detail),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerList(BuildContext context) => Card(
    child: Obx(() {
      if (controller.isLoading.value && controller.customers.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.customers.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No customers found. Add the first customer to begin.'),
          ),
        );
      }
      return ListView.separated(
        itemCount: controller.customers.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final customer = controller.customers[index];
          return Obx(
            () => ListTile(
              selected: controller.selected.value?.id == customer.id,
              leading: CircleAvatar(
                child: Text(customer.name.characters.first.toUpperCase()),
              ),
              title: Text(
                customer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                customer.phone.isEmpty ? 'No phone number' : customer.phone,
              ),
              onTap: () => controller.select(customer),
            ),
          );
        },
      );
    }),
  );

  Widget _customerDetail(BuildContext context) => Card(
    child: Obx(() {
      final customer = controller.selected.value;
      if (customer == null) {
        return const Center(
          child: Text('Select a customer to view details and invoices.'),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  customer.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final ledger = await Get.find<PaymentsCreditController>()
                      .ledger(customer.id);
                  if (ledger != null && context.mounted) {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => CustomerLedgerDialog(ledger: ledger),
                    );
                  }
                },
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('Ledger'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    showCustomerDialog(context, controller, customer: customer),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _info(
            Icons.phone_outlined,
            customer.phone.isEmpty ? 'No phone number' : customer.phone,
          ),
          _info(
            Icons.location_on_outlined,
            customer.address.isEmpty ? 'No address' : customer.address,
          ),
          if (customer.notes.isNotEmpty)
            _info(Icons.notes_rounded, customer.notes),
          const SizedBox(height: 22),
          Text(
            'Invoice history',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (controller.history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text('No saved invoices for this customer.'),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('INVOICE')),
                  DataColumn(label: Text('DATE')),
                  DataColumn(label: Text('TOTAL'), numeric: true),
                  DataColumn(label: Text('STATUS')),
                ],
                rows: controller.history
                    .map(
                      (invoice) => DataRow(
                        onSelectChanged: (_) async {
                          final detail = await Get.find<InvoiceRepository>()
                              .detail(invoice.id);
                          if (detail != null && context.mounted) {
                            await showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  InvoiceDetailDialog(detail: detail),
                            );
                          }
                        },
                        cells: [
                          DataCell(Text(invoice.invoiceNumber)),
                          DataCell(
                            Text(
                              DateFormat(
                                'dd MMM yyyy',
                              ).format(invoice.issueDate),
                            ),
                          ),
                          DataCell(
                            Text(Currency.formatMinor(invoice.grandTotalMinor)),
                          ),
                          DataCell(
                            Text(
                              invoice.paymentStatus
                                  .replaceAll('_', ' ')
                                  .toUpperCase(),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          if (controller.historyTotal.value > 20)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: controller.historyPage.value > 1
                      ? () => controller.loadHistory(
                          customer.id,
                          targetPage: controller.historyPage.value - 1,
                        )
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  'Page ${controller.historyPage.value} of ${controller.historyTotalPages}',
                ),
                IconButton(
                  onPressed:
                      controller.historyPage.value <
                          controller.historyTotalPages
                      ? () => controller.loadHistory(
                          customer.id,
                          targetPage: controller.historyPage.value + 1,
                        )
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          const SizedBox(height: 18),
          const Text(
            'Customer balances arrive in Milestone 3.',
            style: TextStyle(color: Colors.blueGrey),
          ),
        ],
      );
    }),
  );

  Widget _info(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Colors.blueGrey),
        const SizedBox(width: 10),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

Future<Customer?> showCustomerDialog(
  BuildContext context,
  CustomersController controller, {
  Customer? customer,
}) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: customer?.name ?? '');
  final phone = TextEditingController(text: customer?.phone ?? '');
  final address = TextEditingController(text: customer?.address ?? '');
  final notes = TextEditingController(text: customer?.notes ?? '');
  final token = SubmissionToken.create();
  String? error;
  final result = await showDialog<Customer>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(customer == null ? 'Add customer' : 'Edit customer'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Customer name'),
                  validator: (value) => value?.trim().isEmpty ?? true
                      ? 'Customer name is required'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number (optional)',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: address,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          Obx(
            () => FilledButton(
              onPressed: controller.isSaving.value
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      try {
                        final input = CustomerInput(
                          name: name.text,
                          phone: phone.text,
                          address: address.text,
                          notes: notes.text,
                        );
                        if (customer == null) {
                          final created = await controller.create(
                            input,
                            token: token,
                          );
                          if (context.mounted) Navigator.pop(context, created);
                        } else {
                          await controller.updateCustomer(customer.id, input);
                          if (context.mounted) {
                            Navigator.pop(context, controller.selected.value);
                          }
                        }
                      } catch (exception) {
                        setState(
                          () => error = exception is FormatException
                              ? exception.message
                              : exception.toString(),
                        );
                      }
                    },
              child: Text(customer == null ? 'Add customer' : 'Save changes'),
            ),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  phone.dispose();
  address.dispose();
  notes.dispose();
  return result;
}
