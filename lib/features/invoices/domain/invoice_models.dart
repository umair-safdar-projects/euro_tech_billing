class InvoiceLineInput {
  const InvoiceLineInput({
    this.productId,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPriceMinor,
  });

  final int? productId;
  final String description;
  final int quantity;
  final String unit;
  final int unitPriceMinor;
}

class InvoiceTotals {
  const InvoiceTotals({
    required this.lineTotals,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.grandTotalMinor,
  });

  final List<int> lineTotals;
  final int subtotalMinor;
  final int discountMinor;
  final int grandTotalMinor;
}

class InvoiceSaveInput {
  const InvoiceSaveInput({
    required this.customerId,
    required this.issueDate,
    required this.items,
    required this.discountMinor,
    required this.saveToken,
    this.notes = '',
    this.initialPayment,
  });

  final int? customerId;
  final DateTime issueDate;
  final List<InvoiceLineInput> items;
  final int discountMinor;
  final String saveToken;
  final String notes;
  final InitialPaymentInput? initialPayment;
}

class InitialPaymentInput {
  const InitialPaymentInput({
    required this.amountMinor,
    required this.method,
    required this.paymentDate,
    required this.saveToken,
    this.notes = '',
  });
  final int amountMinor;
  final String method;
  final DateTime paymentDate;
  final String saveToken;
  final String notes;
}

class SavedInvoice {
  const SavedInvoice({
    required this.id,
    required this.invoiceNumber,
    this.paymentId,
  });
  final int id;
  final String invoiceNumber;
  final int? paymentId;
}

class InvoiceListItem {
  const InvoiceListItem({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.customerId,
    required this.customerName,
    required this.grandTotalMinor,
    required this.paymentStatus,
  });

  factory InvoiceListItem.fromMap(Map<String, Object?> map) => InvoiceListItem(
    id: map['id']! as int,
    invoiceNumber: map['invoice_number']! as String,
    issueDate: DateTime.parse(map['issue_date']! as String),
    customerId: map['customer_id'] as int?,
    customerName: map['customer_name']! as String,
    grandTotalMinor: map['grand_total_minor']! as int,
    paymentStatus: map['payment_status']! as String,
  );

  final int id;
  final String invoiceNumber;
  final DateTime issueDate;
  final int? customerId;
  final String customerName;
  final int grandTotalMinor;
  final String paymentStatus;
}

class InvoicePage {
  const InvoicePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<InvoiceListItem> items;
  final int total;
  final int page;
  final int pageSize;
}

class InvoiceDetail {
  const InvoiceDetail({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.items,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.grandTotalMinor,
    required this.paymentStatus,
    required this.paidMinor,
    required this.balanceMinor,
    this.companyIdentity,
    this.usesLegacyIdentityFallback = false,
  });

  final int id;
  final String invoiceNumber;
  final DateTime issueDate;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final List<InvoiceDetailItem> items;
  final int subtotalMinor;
  final int discountMinor;
  final int grandTotalMinor;
  final String paymentStatus;
  final int paidMinor;
  final int balanceMinor;
  final InvoiceCompanyIdentity? companyIdentity;
  final bool usesLegacyIdentityFallback;
}

class InvoiceCompanyIdentity {
  const InvoiceCompanyIdentity({
    required this.companyName,
    required this.address,
    required this.ownerName,
    required this.primaryPhone,
    required this.secondaryPhone,
    required this.additionalContactName,
    required this.additionalContactPhone,
    required this.email,
  });

  final String companyName;
  final String address;
  final String ownerName;
  final String primaryPhone;
  final String secondaryPhone;
  final String additionalContactName;
  final String additionalContactPhone;
  final String email;
}

class InvoiceDetailItem {
  const InvoiceDetailItem({
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPriceMinor,
    required this.lineTotalMinor,
  });

  factory InvoiceDetailItem.fromMap(Map<String, Object?> map) =>
      InvoiceDetailItem(
        description: map['description_snapshot']! as String,
        quantity: map['quantity']! as int,
        unit: map['unit']! as String,
        unitPriceMinor: map['unit_price_minor']! as int,
        lineTotalMinor: map['line_total_minor']! as int,
      );

  final String description;
  final int quantity;
  final String unit;
  final int unitPriceMinor;
  final int lineTotalMinor;
}
