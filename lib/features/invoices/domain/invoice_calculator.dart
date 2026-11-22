import 'invoice_models.dart';

abstract final class InvoiceCalculator {
  static const maxInt64 = 9223372036854775807;

  static InvoiceTotals calculate(
    List<InvoiceLineInput> items,
    int discountMinor,
  ) {
    if (items.isEmpty) {
      throw const FormatException('Add at least one invoice item.');
    }
    if (discountMinor < 0) {
      throw const FormatException('Discount cannot be negative.');
    }
    var subtotal = 0;
    final lineTotals = <int>[];
    for (final item in items) {
      if (item.description.trim().isEmpty) {
        throw const FormatException('Every item needs a description.');
      }
      if (item.unit.trim().isEmpty) {
        throw const FormatException('Every item needs a unit.');
      }
      if (item.quantity <= 0) {
        throw const FormatException(
          'Quantity must be a positive whole number.',
        );
      }
      if (item.unitPriceMinor < 0) {
        throw const FormatException('Prices cannot be negative.');
      }
      final lineTotal = _multiply(item.quantity, item.unitPriceMinor);
      subtotal = _add(subtotal, lineTotal);
      lineTotals.add(lineTotal);
    }
    if (discountMinor > subtotal) {
      throw const FormatException('Discount cannot exceed the subtotal.');
    }
    return InvoiceTotals(
      lineTotals: List.unmodifiable(lineTotals),
      subtotalMinor: subtotal,
      discountMinor: discountMinor,
      grandTotalMinor: subtotal - discountMinor,
    );
  }

  static int _multiply(int first, int second) {
    if (first != 0 && second > maxInt64 ~/ first) {
      throw const FormatException('Invoice amount is too large.');
    }
    return first * second;
  }

  static int _add(int first, int second) {
    if (second > maxInt64 - first) {
      throw const FormatException('Invoice total is too large.');
    }
    return first + second;
  }
}
