import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/database/app_database.dart';
import '../domain/invoice_calculator.dart';
import '../domain/invoice_models.dart';
import '../../payments/data/payment_repository.dart';
import '../../payments/domain/payment_models.dart';

class InvoiceRepository {
  InvoiceRepository(this._appDatabase, [PaymentRepository? payments])
    : _payments = payments ?? PaymentRepository(_appDatabase);

  final AppDatabase _appDatabase;
  final PaymentRepository _payments;

  Future<SavedInvoice> save(InvoiceSaveInput input) async {
    if (input.saveToken.trim().isEmpty) {
      throw const FormatException('A submission token is required.');
    }
    final totals = InvoiceCalculator.calculate(
      input.items,
      input.discountMinor,
    );
    final initial = input.initialPayment;
    if (initial != null && totals.grandTotalMinor == 0) {
      throw const FormatException(
        'A zero-value invoice cannot receive a payment.',
      );
    }
    if (input.customerId == null &&
        (initial == null || initial.amountMinor != totals.grandTotalMinor)) {
      throw const FormatException(
        'Select a saved customer for credit or partial-payment invoices.',
      );
    }
    return _appDatabase.financialTransaction((transaction) async {
      final existing = await _findByToken(transaction, input.saveToken);
      if (existing != null) return existing;
      if (input.customerId != null) {
        final customer = await transaction.query(
          'customers',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [input.customerId],
          limit: 1,
        );
        if (customer.isEmpty) {
          throw const FormatException(
            'The selected customer no longer exists.',
          );
        }
      }

      final companyRows = await transaction.query(
        'company_settings',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (companyRows.isEmpty) {
        throw StateError('Company settings record is missing.');
      }
      final company = companyRows.single;
      Map<String, Object?>? customer;
      if (input.customerId != null) {
        final rows = await transaction.query(
          'customers',
          where: 'id = ?',
          whereArgs: [input.customerId],
          limit: 1,
        );
        customer = rows.single;
      }

      final number = await _allocateNumber(transaction);
      final now = DateTime.now().toUtc().toIso8601String();
      final invoiceId = await transaction.insert('invoices', {
        'invoice_number': number,
        'customer_id': input.customerId,
        'issue_date': input.issueDate.toLocal().toIso8601String(),
        'subtotal_minor': totals.subtotalMinor,
        'discount_minor': totals.discountMinor,
        'grand_total_minor': totals.grandTotalMinor,
        'status': 'issued',
        'notes': input.notes.trim(),
        'save_token': input.saveToken,
        'company_name_snapshot': company['company_name'],
        'company_address_snapshot': company['address'],
        'company_owner_snapshot': company['owner_name'],
        'company_primary_phone_snapshot': company['primary_phone'],
        'company_secondary_phone_snapshot': company['secondary_phone'],
        'company_contact_name_snapshot': company['additional_contact_name'],
        'company_contact_phone_snapshot': company['additional_contact_phone'],
        'company_email_snapshot': company['email'],
        'customer_name_snapshot': customer?['name'] ?? 'Walk-in Customer',
        'customer_phone_snapshot': customer?['phone'] ?? '',
        'customer_address_snapshot': customer?['address'] ?? '',
        'created_at': now,
        'updated_at': now,
      });
      for (var index = 0; index < input.items.length; index++) {
        final item = input.items[index];
        await transaction.insert('invoice_items', {
          'invoice_id': invoiceId,
          'product_id': item.productId,
          'description_snapshot': item.description.trim(),
          'quantity': item.quantity,
          'unit': item.unit.trim(),
          'unit_price_minor': item.unitPriceMinor,
          'line_total_minor': totals.lineTotals[index],
        });
      }
      await transaction.insert('audit_logs', {
        'entity_type': 'invoice',
        'entity_id': invoiceId,
        'action': 'created',
        'metadata': jsonEncode({
          'invoice_number': number,
          'grand_total_minor': totals.grandTotalMinor,
        }),
        'created_at': now,
      });
      int? paymentId;
      if (initial != null) {
        final payment = await _payments.recordInTransaction(
          transaction,
          PaymentInput(
            invoiceId: invoiceId,
            amountMinor: initial.amountMinor,
            method: initial.method,
            paymentDate: initial.paymentDate,
            saveToken: initial.saveToken,
            notes: initial.notes,
          ),
        );
        paymentId = payment.id;
      }
      return SavedInvoice(
        id: invoiceId,
        invoiceNumber: number,
        paymentId: paymentId,
      );
    });
  }

  Future<InvoicePage> list({
    String search = '',
    DateTime? from,
    DateTime? to,
    int? customerId,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (page < 1 || pageSize < 1 || pageSize > 100) {
      throw ArgumentError('Invalid pagination.');
    }
    final clauses = <String>[];
    final arguments = <Object?>[];
    final term = search.trim();
    if (term.isNotEmpty) {
      clauses.add(
        "(i.invoice_number LIKE ? ESCAPE '\\' OR "
        "CASE WHEN i.customer_name_snapshot IS NULL THEN c.name ELSE i.customer_name_snapshot END "
        "LIKE ? ESCAPE '\\')",
      );
      final escaped = '%${_escape(term)}%';
      arguments.addAll([escaped, escaped]);
    }
    if (from != null) {
      clauses.add('i.issue_date >= ?');
      arguments.add(_startOfDay(from).toIso8601String());
    }
    if (to != null) {
      clauses.add('i.issue_date < ?');
      arguments.add(
        _startOfDay(to).add(const Duration(days: 1)).toIso8601String(),
      );
    }
    if (customerId != null) {
      clauses.add('i.customer_id = ?');
      arguments.add(customerId);
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final countRows = await _appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM invoices i LEFT JOIN customers c ON c.id = i.customer_id $where',
      arguments,
    );
    final rows = await _appDatabase.database.rawQuery(
      '''SELECT i.id, i.invoice_number, i.issue_date, i.customer_id,
         CASE WHEN i.customer_name_snapshot IS NULL
           THEN COALESCE(c.name, 'Walk-in Customer') ELSE i.customer_name_snapshot END AS customer_name,
         i.grand_total_minor, s.payment_status
         FROM invoices i LEFT JOIN customers c ON c.id = i.customer_id
         JOIN invoice_payment_summary s ON s.invoice_id = i.id
         $where ORDER BY i.issue_date DESC, i.id DESC LIMIT ? OFFSET ?''',
      [...arguments, pageSize, (page - 1) * pageSize],
    );
    return InvoicePage(
      items: rows.map(InvoiceListItem.fromMap).toList(growable: false),
      total: countRows.single['count']! as int,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<InvoiceDetail?> detail(int id) async {
    final rows = await _appDatabase.database.rawQuery(
      '''SELECT i.*,
         CASE WHEN i.customer_name_snapshot IS NULL THEN COALESCE(c.name, 'Walk-in Customer') ELSE i.customer_name_snapshot END AS customer_name,
         CASE WHEN i.customer_name_snapshot IS NULL THEN COALESCE(c.phone, '') ELSE i.customer_phone_snapshot END AS customer_phone,
         CASE WHEN i.customer_name_snapshot IS NULL THEN COALESCE(c.address, '') ELSE i.customer_address_snapshot END AS customer_address,
         s.payment_status, s.paid_minor, s.balance_minor
         FROM invoices i LEFT JOIN customers c ON c.id = i.customer_id
         JOIN invoice_payment_summary s ON s.invoice_id = i.id WHERE i.id = ? LIMIT 1''',
      [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final itemRows = await _appDatabase.database.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    );
    return InvoiceDetail(
      id: row['id']! as int,
      invoiceNumber: row['invoice_number']! as String,
      customerId: row['customer_id'] as int?,
      issueDate: DateTime.parse(row['issue_date']! as String),
      customerName: row['customer_name']! as String,
      customerPhone: row['customer_phone']! as String,
      customerAddress: row['customer_address']! as String,
      items: itemRows.map(InvoiceDetailItem.fromMap).toList(growable: false),
      subtotalMinor: row['subtotal_minor']! as int,
      discountMinor: row['discount_minor']! as int,
      grandTotalMinor: row['grand_total_minor']! as int,
      paymentStatus: row['payment_status']! as String,
      paidMinor: row['paid_minor']! as int,
      balanceMinor: row['balance_minor']! as int,
      companyIdentity: row['company_name_snapshot'] == null
          ? null
          : InvoiceCompanyIdentity(
              companyName: row['company_name_snapshot']! as String,
              address: row['company_address_snapshot']! as String,
              ownerName: row['company_owner_snapshot']! as String,
              primaryPhone: row['company_primary_phone_snapshot']! as String,
              secondaryPhone:
                  row['company_secondary_phone_snapshot']! as String,
              additionalContactName:
                  row['company_contact_name_snapshot']! as String,
              additionalContactPhone:
                  row['company_contact_phone_snapshot']! as String,
              email: row['company_email_snapshot']! as String,
            ),
      usesLegacyIdentityFallback: row['company_name_snapshot'] == null,
    );
  }

  Future<void> updateUnpaid(InvoiceUpdateInput input) async {
    final totals = InvoiceCalculator.calculate(
      input.items,
      input.discountMinor,
    );
    if (input.customerId == null && totals.grandTotalMinor > 0) {
      throw const FormatException(
        'Select a saved customer for an unpaid invoice.',
      );
    }
    await _appDatabase.financialTransaction((transaction) async {
      final invoiceRows = await transaction.query(
        'invoices',
        columns: ['id', 'invoice_number', 'status'],
        where: 'id = ?',
        whereArgs: [input.id],
        limit: 1,
      );
      if (invoiceRows.isEmpty) {
        throw StateError('The invoice no longer exists.');
      }
      final invoice = invoiceRows.single;
      if (invoice['status'] != 'issued') {
        throw StateError('Only issued invoices can be edited.');
      }
      final paymentRows = await transaction.query(
        'payments',
        columns: ['id'],
        where: 'invoice_id = ?',
        whereArgs: [input.id],
        limit: 1,
      );
      if (paymentRows.isNotEmpty) {
        throw StateError(
          'This invoice has payments and cannot be edited. Payment history is immutable.',
        );
      }

      Map<String, Object?>? customer;
      if (input.customerId != null) {
        final customerRows = await transaction.query(
          'customers',
          where: 'id = ?',
          whereArgs: [input.customerId],
          limit: 1,
        );
        if (customerRows.isEmpty) {
          throw const FormatException(
            'The selected customer no longer exists.',
          );
        }
        customer = customerRows.single;
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await transaction.update(
        'invoices',
        {
          'customer_id': input.customerId,
          'issue_date': input.issueDate.toLocal().toIso8601String(),
          'subtotal_minor': totals.subtotalMinor,
          'discount_minor': totals.discountMinor,
          'grand_total_minor': totals.grandTotalMinor,
          'customer_name_snapshot': customer?['name'] ?? 'Walk-in Customer',
          'customer_phone_snapshot': customer?['phone'] ?? '',
          'customer_address_snapshot': customer?['address'] ?? '',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [input.id],
      );
      await transaction.delete(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [input.id],
      );
      for (var index = 0; index < input.items.length; index++) {
        final item = input.items[index];
        await transaction.insert('invoice_items', {
          'invoice_id': input.id,
          'product_id': item.productId,
          'description_snapshot': item.description.trim(),
          'quantity': item.quantity,
          'unit': item.unit.trim(),
          'unit_price_minor': item.unitPriceMinor,
          'line_total_minor': totals.lineTotals[index],
        });
      }
      await transaction.insert('audit_logs', {
        'entity_type': 'invoice',
        'entity_id': input.id,
        'action': 'updated',
        'metadata': jsonEncode({
          'invoice_number': invoice['invoice_number'],
          'grand_total_minor': totals.grandTotalMinor,
        }),
        'created_at': now,
      });
    });
  }

  Future<void> deleteUnpaid(int invoiceId) async {
    await _appDatabase.financialTransaction((transaction) async {
      final invoiceRows = await transaction.query(
        'invoices',
        columns: ['id', 'invoice_number', 'status'],
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      if (invoiceRows.isEmpty) {
        throw StateError('The invoice no longer exists.');
      }
      final invoice = invoiceRows.single;
      if (invoice['status'] != 'issued') {
        throw StateError('Only issued invoices can be deleted.');
      }
      final paymentRows = await transaction.query(
        'payments',
        columns: ['id'],
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      if (paymentRows.isNotEmpty) {
        throw StateError(
          'This invoice has payments and cannot be deleted. Payment history is immutable.',
        );
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await transaction.insert('audit_logs', {
        'entity_type': 'invoice',
        'entity_id': invoiceId,
        'action': 'deleted',
        'metadata': jsonEncode({'invoice_number': invoice['invoice_number']}),
        'created_at': now,
      });
      await transaction.delete(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
    });
  }

  Future<SavedInvoice?> _findByToken(DatabaseExecutor db, String token) async {
    final rows = await db.query(
      'invoices',
      columns: ['id', 'invoice_number'],
      where: 'save_token = ?',
      whereArgs: [token],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SavedInvoice(
      id: rows.single['id']! as int,
      invoiceNumber: rows.single['invoice_number']! as String,
    );
  }

  Future<String> _allocateNumber(Transaction transaction) async {
    final rows = await transaction.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['invoice_sequence'],
      limit: 1,
    );
    final current = rows.isEmpty
        ? 0
        : int.parse(rows.single['value']! as String);
    if (current >= 999999) {
      throw StateError('The invoice number sequence is exhausted.');
    }
    final next = current + 1;
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction.insert('app_settings', {
      'key': 'invoice_sequence',
      'value': next.toString(),
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return 'ET-${next.toString().padLeft(6, '0')}';
  }

  DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  String _escape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
