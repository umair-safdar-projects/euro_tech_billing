class PaymentInput {
  const PaymentInput({
    required this.invoiceId,
    required this.amountMinor,
    required this.method,
    required this.paymentDate,
    required this.saveToken,
    this.reference = '',
    this.notes = '',
  });

  final int invoiceId;
  final int amountMinor;
  final String method;
  final DateTime paymentDate;
  final String saveToken;
  final String reference;
  final String notes;
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.customerId,
    required this.customerName,
    required this.amountMinor,
    required this.method,
    required this.paymentDate,
    required this.reference,
    required this.notes,
    required this.createdAt,
  });

  factory PaymentRecord.fromMap(Map<String, Object?> map) => PaymentRecord(
    id: map['id']! as int,
    invoiceId: map['invoice_id']! as int,
    invoiceNumber: map['invoice_number']! as String,
    customerId: map['customer_id'] as int?,
    customerName: map['customer_name']! as String,
    amountMinor: map['amount_minor']! as int,
    method: map['payment_method']! as String,
    paymentDate: DateTime.parse(map['payment_date']! as String),
    reference: map['reference']! as String,
    notes: map['notes']! as String,
    createdAt: DateTime.parse(map['created_at']! as String),
  );

  final int id;
  final int invoiceId;
  final String invoiceNumber;
  final int? customerId;
  final String customerName;
  final int amountMinor;
  final String method;
  final DateTime paymentDate;
  final String reference;
  final String notes;
  final DateTime createdAt;
}

class PaymentPage {
  const PaymentPage({
    required this.items,
    required this.total,
    required this.collectedMinor,
  });
  final List<PaymentRecord> items;
  final int total;
  final int collectedMinor;
}

class InvoiceBalance {
  const InvoiceBalance({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.customerName,
    required this.grandTotalMinor,
    required this.paidMinor,
    required this.balanceMinor,
    required this.status,
  });

  factory InvoiceBalance.fromMap(Map<String, Object?> map) => InvoiceBalance(
    invoiceId: map['invoice_id']! as int,
    invoiceNumber: map['invoice_number']! as String,
    customerName: map['customer_name']! as String,
    grandTotalMinor: map['grand_total_minor']! as int,
    paidMinor: map['paid_minor']! as int,
    balanceMinor: map['balance_minor']! as int,
    status: map['payment_status']! as String,
  );

  final int invoiceId;
  final String invoiceNumber;
  final String customerName;
  final int grandTotalMinor;
  final int paidMinor;
  final int balanceMinor;
  final String status;
}
