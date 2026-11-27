import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency.dart';
import '../../../core/widgets/page_header.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customers_controller.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../products/domain/product.dart';
import '../../shell/presentation/shell_controller.dart';
import '../../printing/presentation/invoice_print_actions.dart';
import 'invoice_editor_controller.dart';
import 'invoice_history_controller.dart';

class InvoiceEditorScreen extends GetView<InvoiceEditorController> {
  const InvoiceEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          PageHeader(
            title: controller.isEditing ? 'Edit Invoice' : 'New Invoice',
            subtitle: controller.isEditing
                ? 'Correct this unpaid invoice without changing its number or payment history.'
                : 'Provisional invoice • Number allocated only when saved',
            action: Text(
              DateFormat('dd MMM yyyy').format(DateTime.now()),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 24),
          _customerCard(context),
          const SizedBox(height: 18),
          if (controller.isEditing)
            const Card(
              color: Color(0xFFFFF8E1),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Only unpaid invoices without payments can be corrected. Payment history remains immutable.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (controller.isEditing) const SizedBox(height: 18),
          _itemsCard(context),
          const SizedBox(height: 18),
          _summaryCard(context),
          if (!controller.isEditing) ...[
            const SizedBox(height: 18),
            _paymentCard(context),
          ],
          const SizedBox(height: 18),
          _actions(context),
        ],
      );
    });
  }

  Widget _customerCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final selector = DropdownMenu<Customer>(
            width: constraints.maxWidth < 760 ? constraints.maxWidth : 520,
            enableFilter: true,
            enableSearch: true,
            requestFocusOnTap: true,
            label: const Text('Search and select customer'),
            leadingIcon: const Icon(Icons.person_search_rounded),
            dropdownMenuEntries: controller.customers
                .map(
                  (customer) => DropdownMenuEntry(
                    value: customer,
                    label: customer.phone.isEmpty
                        ? customer.name
                        : '${customer.name} • ${customer.phone}',
                  ),
                )
                .toList(),
            onSelected: controller.selectCustomer,
          );
          final add = OutlinedButton.icon(
            onPressed: () async {
              final customer = await showCustomerDialog(
                context,
                Get.find<CustomersController>(),
              );
              if (customer != null) {
                await controller.loadLookups();
                controller.selectCustomer(
                  controller.customers.firstWhere(
                    (item) => item.id == customer.id,
                  ),
                );
              }
            },
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('New customer'),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              if (constraints.maxWidth < 760) ...[
                selector,
                const SizedBox(height: 12),
                add,
              ] else
                Row(
                  children: [
                    Expanded(child: selector),
                    const SizedBox(width: 12),
                    add,
                  ],
                ),
              if (controller.selectedCustomer.value case final customer?) ...[
                const SizedBox(height: 12),
                Text(
                  customer.phone.isEmpty
                      ? 'No phone number provided'
                      : 'Phone: ${customer.phone}',
                  style: const TextStyle(color: Colors.blueGrey),
                ),
              ],
              if (controller.selectedCustomer.value == null)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'A customer is required for Pay Later or partial payment. Fully paid invoices may use Walk-in Customer.',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _itemsCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Services',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: controller.addCustomLine,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Custom line'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) => DropdownMenu<Product>(
              width: constraints.maxWidth,
              enableFilter: true,
              enableSearch: true,
              requestFocusOnTap: true,
              label: const Text('Search service to add'),
              leadingIcon: const Icon(Icons.search_rounded),
              dropdownMenuEntries: controller.products
                  .map(
                    (product) => DropdownMenuEntry(
                      value: product,
                      label: product.requiresCustomPrice
                          ? '${product.name} • custom rate'
                          : '${product.name} • ${Currency.formatMinor(product.defaultPriceMinor ?? 0)}',
                    ),
                  )
                  .toList(),
              onSelected: (product) {
                if (product != null) controller.addProduct(product);
              },
            ),
          ),
          const SizedBox(height: 18),
          if (controller.lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text('Search for a service above or add a custom line.'),
              ),
            )
          else ...[
            for (var index = 0; index < controller.lines.length; index++)
              _lineEditor(context, controller.lines[index], index),
          ],
        ],
      ),
    ),
  );

  Widget _lineEditor(
    BuildContext context,
    EditableInvoiceLine line,
    int index,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final description = TextFormField(
          initialValue: line.description,
          decoration: const InputDecoration(labelText: 'Description'),
          onChanged: (value) {
            line.description = value;
            controller.recalculate();
          },
        );
        final quantity = TextFormField(
          initialValue: line.quantityText,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity'),
          onChanged: (value) {
            line.quantityText = value;
            controller.recalculate();
          },
        );
        final price = TextFormField(
          initialValue: line.priceText,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Unit price',
            prefixText: 'Rs. ',
          ),
          onChanged: (value) {
            line.priceText = value;
            controller.recalculate();
          },
        );
        final remove = IconButton(
          tooltip: 'Remove item',
          onPressed: () => controller.removeLine(index),
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
        );
        final calculatedTotal = controller.lineTotalMinor(line);
        final lineTotal = SizedBox(
          width: 145,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'LINE TOTAL',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
              const SizedBox(height: 5),
              Text(
                calculatedTotal == null
                    ? '—'
                    : Currency.formatMinor(calculatedTotal),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              description,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: quantity),
                  const SizedBox(width: 8),
                  Expanded(child: price),
                  const SizedBox(width: 8),
                  lineTotal,
                  remove,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 5, child: description),
            const SizedBox(width: 10),
            SizedBox(width: 115, child: quantity),
            const SizedBox(width: 10),
            SizedBox(width: 180, child: price),
            const SizedBox(width: 10),
            lineTotal,
            remove,
          ],
        );
      },
    ),
  );

  Widget _summaryCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment status: UNPAID',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Payment collection arrives in Milestone 3.',
                  style: TextStyle(color: Colors.blueGrey),
                ),
                if (controller.validationMessage.value case final message?)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 340,
            child: Column(
              children: [
                _totalRow('Subtotal', controller.subtotalMinor.value),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: controller.discountText.value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Fixed discount',
                    prefixText: 'Rs. ',
                  ),
                  onChanged: (value) {
                    controller.discountText.value = value;
                    controller.recalculate();
                  },
                ),
                const Divider(height: 26),
                _totalRow(
                  'Grand total',
                  controller.grandTotalMinor.value,
                  strong: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _paymentCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Initial payment',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: controller.paymentMode.value,
                  decoration: const InputDecoration(
                    labelText: 'Payment option',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'pay_later',
                      child: Text('Pay Later'),
                    ),
                    DropdownMenuItem(
                      value: 'full',
                      child: Text('Full Payment'),
                    ),
                    DropdownMenuItem(
                      value: 'partial',
                      child: Text('Partial Payment'),
                    ),
                  ],
                  onChanged: (value) =>
                      controller.paymentMode.value = value ?? 'pay_later',
                ),
              ),
              if (controller.paymentMode.value != 'pay_later')
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: controller.paymentMethod.value,
                    decoration: const InputDecoration(labelText: 'Method'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(
                        value: 'bank_transfer',
                        child: Text('Bank Transfer'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) =>
                        controller.paymentMethod.value = value ?? 'cash',
                  ),
                ),
              if (controller.paymentMode.value == 'partial')
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    initialValue: controller.initialPaymentText.value,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'Rs. ',
                    ),
                    onChanged: (value) =>
                        controller.initialPaymentText.value = value,
                  ),
                ),
              if (controller.paymentMode.value == 'full')
                Text(
                  'Amount: ${Currency.formatMinor(controller.grandTotalMinor.value)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _totalRow(String label, int amount, {bool strong = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      Text(
        Currency.formatMinor(amount),
        style: TextStyle(
          fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          fontSize: strong ? 20 : 15,
        ),
      ),
    ],
  );

  Widget _actions(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      TextButton(
        onPressed: () => _confirmClear(context),
        child: const Text('Clear form'),
      ),
      if (!controller.isEditing) ...[
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: controller.isSaving.value
              ? null
              : () => _save(context, startNew: true),
          child: const Text('Save & New Invoice'),
        ),
      ],
      const SizedBox(width: 10),
      ElevatedButton.icon(
        onPressed: controller.isSaving.value
            ? null
            : () => _save(context, startNew: false),
        icon: const Icon(Icons.save_rounded),
        label: Text(controller.isEditing ? 'Save Changes' : 'Save Invoice'),
      ),
    ],
  );

  Future<void> _save(BuildContext context, {required bool startNew}) async {
    try {
      final saved = await controller.save(startNew: startNew);
      Get.snackbar(
        controller.isEditing ? 'Invoice updated' : 'Invoice saved',
        controller.isEditing
            ? '${saved.invoiceNumber} was updated successfully.'
            : saved.paymentId == null
            ? '${saved.invoiceNumber} was saved as unpaid.'
            : '${saved.invoiceNumber} was saved with its initial payment.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
        mainButton: TextButton(
          onPressed: () => showInvoicePreview(context, saved.id),
          child: const Text('PREVIEW'),
        ),
      );
      await Get.find<InvoiceHistoryController>().load(targetPage: 1);
      if (!startNew) {
        controller.clear(force: true);
        Get.find<ShellController>().select(2);
      }
    } catch (error) {
      Get.snackbar(
        'Unable to save invoice',
        error is FormatException ? error.message : error.toString(),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
      );
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    if (!controller.hasUnsavedChanges) {
      controller.clear(force: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this invoice?'),
        content: const Text(
          'Customer, items, and discount changes will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) controller.clear(force: true);
  }
}
