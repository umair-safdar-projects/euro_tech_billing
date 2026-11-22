import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/currency.dart';
import '../domain/credit_models.dart';

class CustomerLedgerDialog extends StatelessWidget {
  const CustomerLedgerDialog({super.key, required this.ledger});
  final CustomerLedger ledger;

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 960, maxHeight: 780),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ledger.credit.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          ledger.credit.phone.isEmpty
                              ? 'No phone number'
                              : ledger.credit.phone,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metric(
                    'Total invoiced',
                    ledger.credit.totalInvoicedMinor,
                    Colors.blue,
                  ),
                  _metric(
                    'Total received',
                    ledger.credit.totalReceivedMinor,
                    Colors.green,
                  ),
                  _metric(
                    'Outstanding',
                    ledger.credit.outstandingMinor,
                    Colors.orange,
                  ),
                ],
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'Invoices'),
                Tab(text: 'Payments'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ledger.invoices.isEmpty
                      ? const Center(child: Text('No invoices.'))
                      : SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('INVOICE')),
                              DataColumn(label: Text('DATE')),
                              DataColumn(label: Text('TOTAL'), numeric: true),
                              DataColumn(label: Text('STATUS')),
                            ],
                            rows: ledger.invoices
                                .map(
                                  (item) => DataRow(
                                    cells: [
                                      DataCell(Text(item.invoiceNumber)),
                                      DataCell(
                                        Text(
                                          DateFormat(
                                            'dd MMM yyyy',
                                          ).format(item.issueDate),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          Currency.formatMinor(
                                            item.grandTotalMinor,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          item.paymentStatus
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
                  ledger.payments.isEmpty
                      ? const Center(child: Text('No payments.'))
                      : SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('DATE')),
                              DataColumn(label: Text('INVOICE')),
                              DataColumn(label: Text('METHOD')),
                              DataColumn(label: Text('AMOUNT'), numeric: true),
                            ],
                            rows: ledger.payments
                                .map(
                                  (item) => DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          DateFormat(
                                            'dd MMM yyyy',
                                          ).format(item.paymentDate),
                                        ),
                                      ),
                                      DataCell(Text(item.invoiceNumber)),
                                      DataCell(
                                        Text(
                                          item.method
                                              .replaceAll('_', ' ')
                                              .toUpperCase(),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          Currency.formatMinor(
                                            item.amountMinor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _metric(String label, int amount, MaterialColor color) => Container(
    width: 260,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.shade50,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color.shade800)),
        const SizedBox(height: 5),
        Text(
          Currency.formatMinor(amount),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
