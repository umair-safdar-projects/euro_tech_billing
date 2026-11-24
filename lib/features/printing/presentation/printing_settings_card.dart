import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../domain/printing_models.dart';
import 'printing_settings_controller.dart';

class PrintingSettingsCard extends GetView<PrintingSettingsController> {
  const PrintingSettingsCard({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (controller.isLoading.value) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Printing settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: controller.isSaving.value ? null : controller.save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save printing settings'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'A4 mode places an actual-size A5 invoice on the sheet without stretching.',
              style: TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final paper = DropdownButtonFormField<InvoicePaper>(
                  initialValue: controller.paper.value,
                  decoration: const InputDecoration(
                    labelText: 'Default invoice paper',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: InvoicePaper.a5,
                      child: Text('ISO A5 - 148 x 210 mm'),
                    ),
                    DropdownMenuItem(
                      value: InvoicePaper.a4,
                      child: Text('A5 content on A4 paper'),
                    ),
                  ],
                  onChanged: (value) =>
                      controller.paper.value = value ?? InvoicePaper.a5,
                );
                final placement = DropdownButtonFormField<A4Placement>(
                  initialValue: controller.placement.value,
                  decoration: const InputDecoration(labelText: 'A4 placement'),
                  items: const [
                    DropdownMenuItem(
                      value: A4Placement.centered,
                      child: Text('Centered'),
                    ),
                    DropdownMenuItem(
                      value: A4Placement.topLeft,
                      child: Text('Top-left with safe margin'),
                    ),
                  ],
                  onChanged: controller.paper.value == InvoicePaper.a4
                      ? (value) => controller.placement.value =
                            value ?? A4Placement.centered
                      : null,
                );
                return constraints.maxWidth < 650
                    ? Column(
                        children: [
                          paper,
                          const SizedBox(height: 14),
                          placement,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: paper),
                          const SizedBox(width: 14),
                          Expanded(child: placement),
                        ],
                      );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller.footer,
              decoration: const InputDecoration(
                labelText: 'Invoice footer message',
              ),
            ),
          ],
        ),
      ),
    );
  });
}
