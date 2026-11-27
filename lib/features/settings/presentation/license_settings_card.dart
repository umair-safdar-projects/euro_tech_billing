import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/licensing/license_service.dart';

class LicenseSettingsCard extends GetView<LicenseService> {
  const LicenseSettingsCard({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (controller.isLoading.value) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final active = controller.isActive.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  active ? Icons.verified_rounded : Icons.lock_outline_rounded,
                  color: active ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lifetime activation',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(
                  label: Text(active ? 'ACTIVE' : 'NOT ACTIVATED'),
                  backgroundColor: active
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              active
                  ? 'Licensed to ${controller.licensedCompany.value ?? 'this company'} on this computer. This license does not expire.'
                  : 'Activation is required before invoices can be saved. Existing data remains available.',
              style: const TextStyle(color: Colors.blueGrey),
            ),
            if (!active) ...[
              const SizedBox(height: 16),
              const Text(
                'Computer code',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              SelectableText(
                ' ${controller.deviceCode.value}',
                style: TextStyle(
                  fontFamily: 'Consolas',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => controller.pendingCode.value = value,
                decoration: const InputDecoration(
                  labelText: 'Lifetime activation code',
                  hintText: 'ETL1.company.device.signature',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: controller.pendingCode.value.trim().isEmpty
                      ? null
                      : () async {
                          final activated = await controller.activate(
                            controller.pendingCode.value,
                          );
                          if (activated) {
                            Get.snackbar(
                              'Activation successful',
                              'Lifetime invoice saving is now enabled on this computer.',
                              snackPosition: SnackPosition.BOTTOM,
                              margin: const EdgeInsets.all(20),
                            );
                          }
                        },
                  icon: const Icon(Icons.key_rounded),
                  label: const Text('Activate software'),
                ),
              ),
              if (controller.errorMessage.value case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  });
}
