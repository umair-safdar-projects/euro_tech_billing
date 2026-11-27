import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency.dart';
import '../../settings/data/company_settings_repository.dart';
import '../../settings/domain/company_settings.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/presentation/payment_dialogs.dart';
import '../../printing/presentation/invoice_print_actions.dart';
import '../../shell/domain/shell_destination.dart';
import '../../shell/presentation/shell_controller.dart';
import '../data/invoice_repository.dart';
import 'invoice_editor_controller.dart';
import '../domain/invoice_models.dart';

class InvoiceDetailDialog extends StatelessWidget {
  const InvoiceDetailDialog({super.key, required this.detail});

  final InvoiceDetail detail;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 18, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Invoice ${detail.invoiceNumber}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (detail.balanceMinor > 0 &&
                      detail.grandTotalMinor > 0) ...[
                    FilledButton.icon(
                      onPressed: () async {
                        final payment = await showRecordPaymentDialog(
                          context,
                          detail.id,
                        );
                        if (payment != null && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.add_card_rounded),
                      label: const Text('Record Payment'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    tooltip: 'Preview Invoice',
                    onPressed: () => showInvoicePreview(context, detail.id),
                    icon: const Icon(Icons.preview_rounded),
                  ),
                  IconButton(
                    tooltip: 'Print Invoice',
                    onPressed: () => printInvoice(detail.id),
                    icon: const Icon(Icons.print_rounded),
                  ),
                  IconButton(
                    tooltip: 'Export PDF',
                    onPressed: () => exportInvoicePdf(detail.id),
                    icon: const Icon(Icons.download_rounded),
                  ),
                  if (detail.paymentStatus == 'unpaid')
                    PopupMenuButton<String>(
                      tooltip: 'Invoice actions',
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editInvoice(context);
                        } else if (value == 'delete') {
                          _deleteInvoice(context);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit invoice'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline_rounded),
                            title: Text('Delete invoice'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<CompanySettings>(
                future: Get.find<CompanySettingsRepository>().load(),
                builder: (context, snapshot) => ListView(
                  padding: const EdgeInsets.all(28),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                snapshot.data?.companyName ??
                                    'Euro Tech Edging and Cutting',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 5),
                              Text(snapshot.data?.address ?? ''),
                              Text(snapshot.data?.primaryPhone ?? ''),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              DateFormat(
                                'dd MMM yyyy',
                              ).format(detail.issueDate),
                            ),
                            const SizedBox(height: 6),
                            _StatusChip(status: detail.paymentStatus),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BILLED TO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            detail.customerName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (detail.customerPhone.isNotEmpty)
                            Text(detail.customerPhone),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('SERVICE')),
                          DataColumn(label: Text('QTY'), numeric: true),
                          DataColumn(label: Text('UNIT')),
                          DataColumn(label: Text('RATE'), numeric: true),
                          DataColumn(label: Text('TOTAL'), numeric: true),
                        ],
                        rows: detail.items
                            .map(
                              (item) => DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 260,
                                      child: Text(item.description),
                                    ),
                                  ),
                                  DataCell(Text('${item.quantity}')),
                                  DataCell(Text(item.unit)),
                                  DataCell(
                                    Text(
                                      Currency.formatMinor(item.unitPriceMinor),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      Currency.formatMinor(item.lineTotalMinor),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 330,
                        child: Column(
                          children: [
                            _total('Subtotal', detail.subtotalMinor),
                            _total('Discount', detail.discountMinor),
                            _total('Paid', detail.paidMinor),
                            _total('Balance', detail.balanceMinor),
                            const Divider(),
                            _total(
                              'Grand total',
                              detail.grandTotalMinor,
                              strong: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Payment history',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder(
                      future: Get.find<PaymentRepository>().forInvoice(
                        detail.id,
                      ),
                      builder: (context, snapshot) {
                        final payments = snapshot.data ?? [];
                        if (payments.isEmpty) {
                          return const Text(
                            'No payments recorded.',
                            style: TextStyle(color: Colors.blueGrey),
                          );
                        }
                        return Column(
                          children: payments
                              .map(
                                (payment) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.payments_outlined),
                                  title: Text(
                                    Currency.formatMinor(payment.amountMinor),
                                  ),
                                  subtitle: Text(
                                    '${payment.method.replaceAll('_', ' ').toUpperCase()} • ${DateFormat('dd MMM yyyy').format(payment.paymentDate)}',
                                  ),
                                  onTap: () =>
                                      showPaymentDetailDialog(context, payment),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editInvoice(BuildContext context) async {
    try {
      final editor = Get.find<InvoiceEditorController>();
      await editor.prepareForEdit(detail);
      if (!context.mounted) return;
      Navigator.pop(context);
      Get.find<ShellController>().select(ShellDestination.newInvoice.index);
    } catch (error) {
      Get.snackbar(
        'Unable to edit invoice',
        error is FormatException || error is StateError
            ? error.toString().replaceFirst('Bad state: ', '')
            : 'Only unpaid invoices without payments can be edited.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
      );
    }
  }

  Future<void> _deleteInvoice(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this invoice?'),
        content: Text(
          'Invoice ${detail.invoiceNumber} has no recorded payment. Its items will be deleted and the invoice number will not be reused.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep invoice'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete invoice'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Get.find<InvoiceRepository>().deleteUnpaid(detail.id);
      if (context.mounted) Navigator.pop(context);
      Get.snackbar(
        'Invoice deleted',
        '${detail.invoiceNumber} was removed. The number will not be reused.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
      );
    } catch (error) {
      Get.snackbar(
        'Invoice was not deleted',
        error is StateError
            ? error.toString().replaceFirst('Bad state: ', '')
            : 'The invoice could not be deleted.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
      );
    }
  }

  Widget _total(String label, int value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          Currency.formatMinor(value),
          style: TextStyle(
            fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
            fontSize: strong ? 18 : 14,
          ),
        ),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(status.replaceAll('_', ' ').toUpperCase()),
    backgroundColor: status == 'paid'
        ? Colors.green.shade50
        : Colors.orange.shade50,
    side: BorderSide(
      color: status == 'paid' ? Colors.green.shade200 : Colors.orange.shade200,
    ),
  );
}
