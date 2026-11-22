import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../domain/backup_models.dart';
import 'backup_controller.dart';

class BackupSettingsCard extends GetView<BackupController> {
  const BackupSettingsCard({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    final value = controller.status.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup and restore',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Daily backups are created while the application is running.',
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ],
                  ),
                ),
                if (controller.isBusy.value)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (controller.warning.value case final warning?)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(warning)),
                  ],
                ),
              ),
            Text('Destination', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            SelectableText(value?.destination ?? 'Loading…'),
            const SizedBox(height: 12),
            Text(
              value?.lastSuccessfulAt == null
                  ? 'No successful backup has been recorded.'
                  : 'Last successful backup: ${DateFormat('dd MMM yyyy, hh:mm a').format(value!.lastSuccessfulAt!)}',
              style: TextStyle(
                color: value?.isHealthy ?? false
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: controller.isBusy.value
                      ? null
                      : controller.chooseDestination,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Choose folder'),
                ),
                FilledButton.icon(
                  onPressed: controller.isBusy.value
                      ? null
                      : controller.createManualBackup,
                  icon: const Icon(Icons.backup_rounded),
                  label: const Text('Back up now'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.isBusy.value
                      ? null
                      : () => _restore(context),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Restore backup'),
                ),
              ],
            ),
            if (value?.history.isNotEmpty ?? false) ...[
              const SizedBox(height: 22),
              Text(
                'Recent backups',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...value!.history
                  .take(5)
                  .map(
                    (entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.green,
                      ),
                      title: Text(
                        entry.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${entry.type} • ${DateFormat('dd MMM yyyy, hh:mm a').format(entry.createdAt)} • ${(entry.fileSize / 1024).toStringAsFixed(0)} KB',
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  });

  Future<void> _restore(BuildContext context) async {
    final metadata = await controller.chooseRestoreFile();
    if (metadata == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Replace current billing data?'),
        content: _metadata(metadata),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create safety backup and restore'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.restore(metadata);
  }

  Widget _metadata(BackupMetadata value) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Current invoices, customers, and payments will be replaced. A safety backup will be created first.',
      ),
      const SizedBox(height: 14),
      Text(
        'Created: ${DateFormat('dd MMM yyyy, hh:mm a').format(value.createdAt)}',
      ),
      Text('Schema version: ${value.schemaVersion}'),
      Text('Invoices: ${value.invoiceCount}'),
      Text('Customers: ${value.customerCount}'),
      Text('Payments: ${value.paymentCount}'),
      const SizedBox(height: 8),
      Text(
        value.path,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.blueGrey),
      ),
    ],
  );
}
