import '../../invoices/domain/invoice_models.dart';
import '../../payments/domain/payment_models.dart';

class CustomerCredit {
  const CustomerCredit({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.totalInvoicedMinor,
    required this.totalReceivedMinor,
    required this.outstandingMinor,
  });

  factory CustomerCredit.fromMap(Map<String, Object?> map) => CustomerCredit(
    customerId: map['customer_id']! as int,
    name: map['name']! as String,
    phone: map['phone']! as String,
    totalInvoicedMinor: map['total_invoiced_minor']! as int,
    totalReceivedMinor: map['total_received_minor']! as int,
    outstandingMinor: map['outstanding_minor']! as int,
  );

  final int customerId;
  final String name;
  final String phone;
  final int totalInvoicedMinor;
  final int totalReceivedMinor;
  final int outstandingMinor;
}

class CreditSummary {
  const CreditSummary({
    required this.outstandingMinor,
    required this.customerCount,
    required this.unpaidCount,
    required this.partialCount,
  });
  final int outstandingMinor;
  final int customerCount;
  final int unpaidCount;
  final int partialCount;
}

class CustomerLedger {
  const CustomerLedger({
    required this.credit,
    required this.invoices,
    required this.payments,
  });
  final CustomerCredit credit;
  final List<InvoiceListItem> invoices;
  final List<PaymentRecord> payments;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.todaySalesMinor,
    required this.todayCollectionsMinor,
    required this.outstandingMinor,
    required this.todayInvoiceCount,
    required this.recentInvoices,
    required this.recentPayments,
  });
  final int todaySalesMinor;
  final int todayCollectionsMinor;
  final int outstandingMinor;
  final int todayInvoiceCount;
  final List<InvoiceListItem> recentInvoices;
  final List<PaymentRecord> recentPayments;
}
