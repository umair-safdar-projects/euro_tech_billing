import '../../../core/database/app_database.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/domain/payment_models.dart';
import '../domain/credit_models.dart';

class CreditRepository {
  CreditRepository(this._appDatabase, this._invoices, this._payments);

  final AppDatabase _appDatabase;
  final InvoiceRepository _invoices;
  final PaymentRepository _payments;

  Future<CreditSummary> summary() async {
    final row = (await _appDatabase.database.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN i.status = 'issued' THEN s.balance_minor ELSE 0 END), 0) AS outstanding,
      COUNT(DISTINCT CASE WHEN i.status = 'issued' AND s.balance_minor > 0 AND i.customer_id IS NOT NULL THEN i.customer_id END) AS customers,
      COALESCE(SUM(CASE WHEN i.status = 'issued' AND s.payment_status = 'unpaid' AND i.grand_total_minor > 0 THEN 1 ELSE 0 END), 0) AS unpaid,
      COALESCE(SUM(CASE WHEN i.status = 'issued' AND s.payment_status = 'partially_paid' THEN 1 ELSE 0 END), 0) AS partial
      FROM invoices i JOIN invoice_payment_summary s ON s.invoice_id = i.id''',
    )).single;
    return CreditSummary(
      outstandingMinor: row['outstanding']! as int,
      customerCount: row['customers']! as int,
      unpaidCount: row['unpaid']! as int,
      partialCount: row['partial']! as int,
    );
  }

  Future<List<CustomerCredit>> outstandingCustomers({
    String search = '',
    int limit = 100,
  }) async {
    final term = search.trim();
    final where = term.isEmpty
        ? ''
        : "AND (c.name LIKE ? ESCAPE '\\' OR c.phone LIKE ? ESCAPE '\\')";
    final args = term.isEmpty
        ? <Object?>[]
        : <Object?>['%${_escape(term)}%', '%${_escape(term)}%'];
    final rows = await _appDatabase.database.rawQuery(
      '''
      SELECT c.id AS customer_id, c.name, c.phone,
      COALESCE(SUM(i.grand_total_minor), 0) AS total_invoiced_minor,
      COALESCE(SUM(s.paid_minor), 0) AS total_received_minor,
      COALESCE(SUM(s.balance_minor), 0) AS outstanding_minor
      FROM customers c JOIN invoices i ON i.customer_id = c.id AND i.status = 'issued'
      JOIN invoice_payment_summary s ON s.invoice_id = i.id
      WHERE 1 = 1 $where GROUP BY c.id HAVING outstanding_minor > 0
      ORDER BY outstanding_minor DESC, c.name COLLATE NOCASE LIMIT ?''',
      [...args, limit],
    );
    return rows.map(CustomerCredit.fromMap).toList(growable: false);
  }

  Future<CustomerLedger?> ledger(int customerId) async {
    final rows = await _appDatabase.database.rawQuery(
      '''
      SELECT c.id AS customer_id, c.name, c.phone,
      COALESCE(SUM(CASE WHEN i.status = 'issued' THEN i.grand_total_minor ELSE 0 END), 0) AS total_invoiced_minor,
      COALESCE(SUM(CASE WHEN i.status = 'issued' THEN s.paid_minor ELSE 0 END), 0) AS total_received_minor,
      COALESCE(SUM(CASE WHEN i.status = 'issued' THEN s.balance_minor ELSE 0 END), 0) AS outstanding_minor
      FROM customers c LEFT JOIN invoices i ON i.customer_id = c.id
      LEFT JOIN invoice_payment_summary s ON s.invoice_id = i.id
      WHERE c.id = ? GROUP BY c.id''',
      [customerId],
    );
    if (rows.isEmpty) return null;
    final invoicePage = await _invoices.list(
      customerId: customerId,
      pageSize: 100,
    );
    final paymentRows = await _appDatabase.database.rawQuery(
      '''
      SELECT p.*, i.invoice_number, i.customer_id, c.name AS customer_name
      FROM payments p JOIN invoices i ON i.id = p.invoice_id
      JOIN customers c ON c.id = i.customer_id WHERE i.customer_id = ?
      ORDER BY p.payment_date DESC, p.id DESC LIMIT 100''',
      [customerId],
    );
    return CustomerLedger(
      credit: CustomerCredit.fromMap(rows.single),
      invoices: invoicePage.items,
      payments: paymentRows.map(PaymentRecord.fromMap).toList(growable: false),
    );
  }

  Future<DashboardSnapshot> dashboard({DateTime? businessDate}) async {
    final date = businessDate ?? DateTime.now();
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final invoiceRow = (await _appDatabase.database.rawQuery(
      '''
      SELECT COALESCE(SUM(grand_total_minor), 0) AS sales, COUNT(*) AS count
      FROM invoices WHERE status = 'issued' AND issue_date >= ? AND issue_date < ?''',
      [start.toIso8601String(), end.toIso8601String()],
    )).single;
    final paymentRow = (await _appDatabase.database.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_minor), 0) AS collected FROM payments
      WHERE payment_date >= ? AND payment_date < ?''',
      [start.toIso8601String(), end.toIso8601String()],
    )).single;
    final credit = await summary();
    final recentInvoices = await _invoices.list(pageSize: 5);
    final recentPayments = await _payments.list(pageSize: 5);
    return DashboardSnapshot(
      todaySalesMinor: invoiceRow['sales']! as int,
      todayCollectionsMinor: paymentRow['collected']! as int,
      outstandingMinor: credit.outstandingMinor,
      todayInvoiceCount: invoiceRow['count']! as int,
      recentInvoices: recentInvoices.items,
      recentPayments: recentPayments.items,
    );
  }

  String _escape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
