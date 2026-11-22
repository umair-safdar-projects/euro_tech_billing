import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency.dart';
import '../../../core/utils/submission_token.dart';
import '../domain/payment_models.dart';
import 'payments_credit_controller.dart';

Future<PaymentRecord?> showRecordPaymentDialog(
  BuildContext context,
  int invoiceId,
) async {
  final controller = Get.find<PaymentsCreditController>();
  final balance = await controller.balance(invoiceId);
  if (balance == null || !context.mounted) return null;
  final amount = TextEditingController(text: _minorInput(balance.balanceMinor));
  final notes = TextEditingController();
  final reference = TextEditingController();
  final token = SubmissionToken.create();
  var method = 'cash';
  var date = DateTime.now();
  String? error;
  final result = await showDialog<PaymentRecord>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Record payment • ${balance.invoiceNumber}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  balance.customerName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _amountLabel('Invoice total', balance.grandTotalMinor),
                    _amountLabel('Already paid', balance.paidMinor),
                    _amountLabel(
                      'Remaining',
                      balance.balanceMinor,
                      strong: true,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Payment amount',
                    prefixText: 'Rs. ',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'bank_transfer',
                      child: Text('Bank Transfer'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) =>
                      setState(() => method = value ?? 'cash'),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDate: date,
                    );
                    if (picked != null) setState(() => date = picked);
                  },
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: Text(DateFormat('dd MMM yyyy').format(date)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'Reference number (optional)',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final minor = Currency.parseRupees(amount.text);
              if (minor == null || minor <= 0 || minor > balance.balanceMinor) {
                setState(
                  () => error =
                      'Enter an amount greater than zero and not above the remaining balance.',
                );
                return;
              }
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm payment'),
                  content: Text(
                    'Record ${Currency.formatMinor(minor)} against ${balance.invoiceNumber}? This entry cannot be edited or deleted.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Review'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Record payment'),
                    ),
                  ],
                ),
              );
              if (!(confirmed ?? false)) return;
              try {
                final payment = await controller.record(
                  invoiceId: invoiceId,
                  amountMinor: minor,
                  method: method,
                  date: date,
                  notes: notes.text,
                  reference: reference.text,
                  token: token,
                );
                if (context.mounted) Navigator.pop(context, payment);
              } catch (exception) {
                setState(
                  () => error = exception is FormatException
                      ? exception.message
                      : exception.toString(),
                );
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
  amount.dispose();
  notes.dispose();
  reference.dispose();
  return result;
}

Future<void> showPaymentDetailDialog(
  BuildContext context,
  PaymentRecord payment,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Payment #${payment.id}'),
    content: SizedBox(
      width: 450,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Currency.formatMinor(payment.amountMinor),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          _detailRow('Invoice', payment.invoiceNumber),
          _detailRow('Customer', payment.customerName),
          _detailRow(
            'Method',
            payment.method.replaceAll('_', ' ').toUpperCase(),
          ),
          _detailRow(
            'Payment date',
            DateFormat('dd MMM yyyy').format(payment.paymentDate),
          ),
          if (payment.reference.isNotEmpty)
            _detailRow('Reference', payment.reference),
          if (payment.notes.isNotEmpty) _detailRow('Notes', payment.notes),
          _detailRow(
            'Recorded',
            DateFormat(
              'dd MMM yyyy, hh:mm a',
            ).format(payment.createdAt.toLocal()),
          ),
          const SizedBox(height: 12),
          const Text(
            'Payments are immutable. Controlled reversals are deferred to a future correction workflow.',
            style: TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);

Widget _amountLabel(String label, int amount, {bool strong = false}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
    Text(
      Currency.formatMinor(amount),
      style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600),
    ),
  ],
);
Widget _detailRow(String label, String value) => Padding(
  padding: const EdgeInsets.only(bottom: 9),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 110,
        child: Text(label, style: const TextStyle(color: Colors.blueGrey)),
      ),
      Expanded(child: Text(value)),
    ],
  ),
);
String _minorInput(int value) => value.remainder(100) == 0
    ? '${value ~/ 100}'
    : '${value ~/ 100}.${value.remainder(100).toString().padLeft(2, '0')}';
