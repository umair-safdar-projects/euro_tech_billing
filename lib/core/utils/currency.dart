import 'package:intl/intl.dart';

abstract final class Currency {
  static final NumberFormat _format = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  static String formatMinor(int minor) {
    final rupees = minor ~/ 100;
    final paisa = minor.remainder(100).abs();
    final base = _format.format(rupees);
    return paisa == 0 ? base : '$base.${paisa.toString().padLeft(2, '0')}';
  }

  static int? parseRupees(String value) {
    final normalized = value.replaceAll(',', '').trim();
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
    if (match == null) return null;
    final rupees = int.tryParse(match.group(1)!);
    if (rupees == null || rupees > 92233720368547758) return null;
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    final paisa = fraction.isEmpty ? 0 : int.parse(fraction);
    final minor = rupees * 100 + paisa;
    return minor <= 9223372036854775807 ? minor : null;
  }
}
