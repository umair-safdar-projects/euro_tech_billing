import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/database/app_database.dart';
import '../domain/payment_models.dart';

class PaymentRepository {
  PaymentRepository(this._appDatabase);

  static const supportedMethods = {'cash', 'bank_transfer', 'other'};
  final AppDatabase _appDatabase;

  Future<PaymentRecord> record(PaymentInput input) =>
      _appDatabase.financialTransaction(
        (transaction) => recordInTransaction(transaction, input),
      );

  Future<PaymentRecord> recordInTransaction(
    DatabaseExecutor db,
    PaymentInput input,
  ) async {
    _validateInput(input);
    final existing = await _findByToken(db, input.saveToken);
    if (existing != null) return existing;
    final balance = await invoiceBalance(input.invoiceId, executor: db);
    if (balance == null) throw const FormatException('Invoice does not exist.');
    if (balance.status == 'void' ||
        balance.grandTotalMinor <= 0 ||
        balance.balanceMinor <= 0) {
      throw const FormatException('Invoice is not eligible for payment.');
    }
    if (input.amountMinor > balance.balanceMinor) {
      throw const FormatException(
        'Payment cannot exceed the outstanding balance.',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      final id = await db.insert('payments', {
        'invoice_id': input.invoiceId,
        'amount_minor': input.amountMinor,
        'payment_method': input.method,
        'payment_date': input.paymentDate.toLocal().toIso8601String(),
        'reference': input.reference.trim(),
        'notes': input.notes.trim(),
        'save_token': input.saveToken,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('audit_logs', {
        'entity_type': 'payment',
        'entity_id': id,
        'action': 'created',
        'metadata': jsonEncode({
          'invoice_id': input.invoiceId,
          'amount_minor': input.amountMinor,
          'method': input.method,
        }),
        'created_at': now,
      });
      return (await detail(id, executor: db))!;
    } catch (_) {
      final repeated = await _findByToken(db, input.saveToken);
      if (repeated != null) return repeated;
      rethrow;
    }
  }

  Future<InvoiceBalance?> invoiceBalance(
    int invoiceId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? _appDatabase.database;
    final rows = await db.rawQuery(
      '''SELECT s.invoice_id, i.invoice_number, COALESCE(c.name, 'Walk-in Customer') AS customer_name,
         s.grand_total_minor, s.paid_minor, s.balance_minor, s.payment_status
         FROM invoice_payment_summary s JOIN invoices i ON i.id = s.invoice_id
         LEFT JOIN customers c ON c.id = i.customer_id WHERE s.invoice_id = ? LIMIT 1''',
      [invoiceId],
    );
    return rows.isEmpty ? null : InvoiceBalance.fromMap(rows.single);
  }

  Future<PaymentRecord?> detail(int id, {DatabaseExecutor? executor}) async {
    final db = executor ?? _appDatabase.database;
    final rows = await db.rawQuery(
      '''SELECT p.*, i.invoice_number, i.customer_id,
         COALESCE(c.name, 'Walk-in Customer') AS customer_name
         FROM payments p JOIN invoices i ON i.id = p.invoice_id
         LEFT JOIN customers c ON c.id = i.customer_id WHERE p.id = ? LIMIT 1''',
      [id],
    );
    return rows.isEmpty ? null : PaymentRecord.fromMap(rows.single);
  }

  Future<List<PaymentRecord>> forInvoice(int invoiceId) async {
    final rows = await _appDatabase.database.rawQuery(
      '''SELECT p.*, i.invoice_number, i.customer_id,
         COALESCE(c.name, 'Walk-in Customer') AS customer_name
         FROM payments p JOIN invoices i ON i.id = p.invoice_id
         LEFT JOIN customers c ON c.id = i.customer_id
         WHERE p.invoice_id = ? ORDER BY p.payment_date DESC, p.id DESC''',
      [invoiceId],
    );
    return rows.map(PaymentRecord.fromMap).toList(growable: false);
  }

  Future<List<InvoiceBalance>> payableInvoices({
    String search = '',
    int limit = 100,
  }) async {
    final term = search.trim();
    final where = term.isEmpty
        ? ''
        : "AND (i.invoice_number LIKE ? ESCAPE '\\' OR c.name LIKE ? ESCAPE '\\')";
    final args = term.isEmpty
        ? <Object?>[]
        : <Object?>['%${_escape(term)}%', '%${_escape(term)}%'];
    final rows = await _appDatabase.database.rawQuery(
      '''
      SELECT s.invoice_id, i.invoice_number, COALESCE(c.name, 'Walk-in Customer') AS customer_name,
      s.grand_total_minor, s.paid_minor, s.balance_minor, s.payment_status
      FROM invoice_payment_summary s JOIN invoices i ON i.id = s.invoice_id
      LEFT JOIN customers c ON c.id = i.customer_id
      WHERE i.status = 'issued' AND s.balance_minor > 0 AND i.grand_total_minor > 0 $where
      ORDER BY i.issue_date DESC, i.id DESC LIMIT ?''',
      [...args, limit],
    );
    return rows.map(InvoiceBalance.fromMap).toList(growable: false);
  }

  Future<PaymentPage> list({
    String search = '',
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (search.trim().isNotEmpty) {
      clauses.add(
        "(i.invoice_number LIKE ? ESCAPE '\\' OR c.name LIKE ? ESCAPE '\\')",
      );
      final value = '%${_escape(search.trim())}%';
      args.addAll([value, value]);
    }
    if (from != null) {
      clauses.add('p.payment_date >= ?');
      args.add(_day(from).toIso8601String());
    }
    if (to != null) {
      clauses.add('p.payment_date < ?');
      args.add(_day(to).add(const Duration(days: 1)).toIso8601String());
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final base = '''FROM payments p JOIN invoices i ON i.id = p.invoice_id
      LEFT JOIN customers c ON c.id = i.customer_id $where''';
    final aggregate = (await _appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count, COALESCE(SUM(p.amount_minor), 0) AS collected $base',
      args,
    )).single;
    final rows = await _appDatabase.database.rawQuery(
      '''SELECT p.*, i.invoice_number, i.customer_id,
         COALESCE(c.name, 'Walk-in Customer') AS customer_name $base
         ORDER BY p.payment_date DESC, p.id DESC LIMIT ? OFFSET ?''',
      [...args, pageSize, (page - 1) * pageSize],
    );
    return PaymentPage(
      items: rows.map(PaymentRecord.fromMap).toList(growable: false),
      total: aggregate['count']! as int,
      collectedMinor: aggregate['collected']! as int,
    );
  }

  void _validateInput(PaymentInput input) {
    if (input.amountMinor <= 0) {
      throw const FormatException('Payment amount must be greater than zero.');
    }
    if (!supportedMethods.contains(input.method)) {
      throw const FormatException('Select a valid payment method.');
    }
    if (input.saveToken.trim().isEmpty) {
      throw const FormatException('A submission token is required.');
    }
  }

  Future<PaymentRecord?> _findByToken(DatabaseExecutor db, String token) async {
    final rows = await db.query(
      'payments',
      columns: ['id'],
      where: 'save_token = ?',
      whereArgs: [token],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : detail(rows.single['id']! as int, executor: db);
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
  String _escape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
