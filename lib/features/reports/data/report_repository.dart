import '../../../core/database/app_database.dart';
import '../domain/report_models.dart';

class ReportRepository {
  ReportRepository(this._appDatabase);
  final AppDatabase _appDatabase;

  Future<ReportSnapshot> load(ReportRange range) async {
    final from = _day(range.from).toIso8601String();
    final until = _day(range.to).add(const Duration(days: 1)).toIso8601String();
    final database = _appDatabase.database;
    final totals = await database.rawQuery(
      '''SELECT COUNT(*) AS invoice_count,
         COALESCE(SUM(grand_total_minor), 0) AS invoiced_minor
         FROM invoices WHERE status = 'issued' AND issue_date >= ? AND issue_date < ?''',
      [from, until],
    );
    final collections = await database.rawQuery(
      '''SELECT COALESCE(SUM(amount_minor), 0) AS collected_minor
         FROM payments WHERE payment_date >= ? AND payment_date < ?''',
      [from, until],
    );
    final outstanding = await database.rawQuery(
      '''SELECT COALESCE(SUM(s.balance_minor), 0) AS outstanding_minor
         FROM invoice_payment_summary s JOIN invoices i ON i.id = s.invoice_id
         WHERE i.status = 'issued' AND s.balance_minor > 0''',
    );
    final statuses = await database.rawQuery(
      '''SELECT CASE s.payment_status
           WHEN 'partially_paid' THEN 'Partially paid'
           WHEN 'unpaid' THEN 'Unpaid'
           WHEN 'paid' THEN 'Paid'
           WHEN 'void' THEN 'Void'
           ELSE s.payment_status END AS name, COUNT(*) AS item_count,
         COALESCE(SUM(i.grand_total_minor), 0) AS amount_minor
         FROM invoices i JOIN invoice_payment_summary s ON s.invoice_id = i.id
         WHERE i.issue_date >= ? AND i.issue_date < ?
         GROUP BY s.payment_status ORDER BY item_count DESC''',
      [from, until],
    );
    final customers = await database.rawQuery(
      '''SELECT CASE WHEN i.customer_name_snapshot IS NULL
           THEN COALESCE(c.name, 'Walk-in Customer') ELSE i.customer_name_snapshot END AS name,
         COUNT(*) AS item_count, SUM(i.grand_total_minor) AS amount_minor
         FROM invoices i LEFT JOIN customers c ON c.id = i.customer_id
         WHERE i.status = 'issued' AND i.issue_date >= ? AND i.issue_date < ?
         GROUP BY i.customer_id,
           CASE WHEN i.customer_name_snapshot IS NULL THEN COALESCE(c.name, 'Walk-in Customer') ELSE i.customer_name_snapshot END
         ORDER BY amount_minor DESC LIMIT 20''',
      [from, until],
    );
    final products = await database.rawQuery(
      '''SELECT ii.description_snapshot AS name, SUM(ii.quantity) AS item_count,
         SUM(ii.line_total_minor) AS amount_minor
         FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id
         WHERE i.status = 'issued' AND i.issue_date >= ? AND i.issue_date < ?
         GROUP BY ii.description_snapshot ORDER BY amount_minor DESC LIMIT 50''',
      [from, until],
    );
    final credit = await database.rawQuery(
      '''SELECT CASE WHEN i.customer_name_snapshot IS NULL
           THEN COALESCE(c.name, 'Walk-in Customer') ELSE i.customer_name_snapshot END AS name,
         COUNT(*) AS item_count, SUM(s.balance_minor) AS amount_minor
         FROM invoices i JOIN invoice_payment_summary s ON s.invoice_id = i.id
         LEFT JOIN customers c ON c.id = i.customer_id
         WHERE i.status = 'issued' AND s.balance_minor > 0
         GROUP BY i.customer_id,
           CASE WHEN i.customer_name_snapshot IS NULL THEN COALESCE(c.name, 'Walk-in Customer') ELSE i.customer_name_snapshot END
         ORDER BY amount_minor DESC''',
    );
    return ReportSnapshot(
      range: range,
      invoicedMinor: totals.single['invoiced_minor']! as int,
      collectedMinor: collections.single['collected_minor']! as int,
      outstandingMinor: outstanding.single['outstanding_minor']! as int,
      invoiceCount: totals.single['invoice_count']! as int,
      statusBreakdown: _amounts(statuses),
      topCustomers: _amounts(customers),
      productSales: _amounts(products),
      outstandingCustomers: _amounts(credit),
    );
  }

  List<ReportNamedAmount> _amounts(List<Map<String, Object?>> rows) => rows
      .map(
        (row) => ReportNamedAmount(
          row['name']! as String,
          row['amount_minor']! as int,
          count: row['item_count']! as int,
        ),
      )
      .toList(growable: false);

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}
