import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/currency.dart';
import '../../../core/widgets/page_header.dart';
import '../domain/product.dart';
import 'products_controller.dart';

class ProductsScreen extends GetView<ProductsController> {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Products & Prices',
            subtitle: 'Manage services, rates, and billing availability.',
            action: ElevatedButton.icon(
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add service'),
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Card(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.errorMessage.value case final error?) {
                  return Center(child: Text('Unable to load products: $error'));
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('SERVICE')),
                        DataColumn(label: Text('UNIT')),
                        DataColumn(label: Text('DEFAULT PRICE')),
                        DataColumn(label: Text('ACTIVE')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final product in controller.products)
                          _row(context, product),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(BuildContext context, Product product) => DataRow(
    cells: [
      DataCell(
        Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      DataCell(Text(product.unit)),
      DataCell(
        Text(
          product.requiresCustomPrice
              ? 'Entered when billing'
              : Currency.formatMinor(product.defaultPriceMinor ?? 0),
        ),
      ),
      DataCell(
        Switch(
          value: product.isActive,
          onChanged: (value) => controller.setActive(product, value),
        ),
      ),
      DataCell(
        IconButton(
          tooltip: 'Edit price',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _showPriceDialog(context, product),
        ),
      ),
    ],
  );

  Future<void> _showPriceDialog(BuildContext context, Product product) async {
    final field = TextEditingController(
      text: product.defaultPriceMinor == null
          ? ''
          : (product.defaultPriceMinor! / 100).toStringAsFixed(0),
    );
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit ${product.name} price'),
          content: TextField(
            controller: field,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Price in rupees',
              prefixText: 'Rs. ',
              errorText: error,
            ),
            onSubmitted: (_) async => _savePrice(
              context,
              product,
              field.text,
              (value) => setState(() => error = value),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _savePrice(
                context,
                product,
                field.text,
                (value) => setState(() => error = value),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    field.dispose();
  }

  Future<void> _savePrice(
    BuildContext context,
    Product product,
    String value,
    ValueChanged<String?> setError,
  ) async {
    try {
      await controller.updatePrice(product, value);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      setError(error is FormatException ? error.message : error.toString());
    }
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final name = TextEditingController();
    final unit = TextEditingController(text: 'piece');
    final price = TextEditingController();
    var custom = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add custom service'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Service name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: price,
                  enabled: !custom,
                  decoration: const InputDecoration(
                    labelText: 'Default price',
                    prefixText: 'Rs. ',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: custom,
                  title: const Text('Rate entered when billing'),
                  onChanged: (value) => setState(() => custom = value ?? false),
                ),
                if (error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await controller.addProduct(
                    name: name.text,
                    unit: unit.text,
                    price: price.text,
                    customPrice: custom,
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (exception) {
                  setState(
                    () => error = exception is FormatException
                        ? exception.message
                        : exception.toString(),
                  );
                }
              },
              child: const Text('Add service'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    unit.dispose();
    price.dispose();
  }
}
