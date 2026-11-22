class ReportRange {
  const ReportRange(this.from, this.to);
  final DateTime from;
  final DateTime to;
}

class ReportNamedAmount {
  const ReportNamedAmount(this.name, this.amountMinor, {this.count = 0});
  final String name;
  final int amountMinor;
  final int count;
}

class ReportSnapshot {
  const ReportSnapshot({
    required this.range,
    required this.invoicedMinor,
    required this.collectedMinor,
    required this.outstandingMinor,
    required this.invoiceCount,
    required this.statusBreakdown,
    required this.topCustomers,
    required this.productSales,
    required this.outstandingCustomers,
  });

  final ReportRange range;
  final int invoicedMinor;
  final int collectedMinor;
  final int outstandingMinor;
  final int invoiceCount;
  final List<ReportNamedAmount> statusBreakdown;
  final List<ReportNamedAmount> topCustomers;
  final List<ReportNamedAmount> productSales;
  final List<ReportNamedAmount> outstandingCustomers;
}
