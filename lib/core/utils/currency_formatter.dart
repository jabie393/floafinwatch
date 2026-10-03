import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Formats an integer or numeric amount to Indonesian Rupiah.
  /// Example: 3005000 -> "Rp 3.005.000"
  static String formatRupiah(num? amount) {
    if (amount == null) return 'Rp 0';
    return _formatter.format(amount.round()).trim();
  }

  /// Compact format for small cards/widgets if needed.
  /// Example: 1500000 -> "Rp 1,5 Jt"
  static String formatCompact(num? amount) {
    if (amount == null || amount == 0) return 'Rp 0';
    final rounded = amount.round();
    if (rounded >= 1000000000) {
      return 'Rp ${(rounded / 1000000000).toStringAsFixed(1)} M';
    } else if (rounded >= 1000000) {
      return 'Rp ${(rounded / 1000000).toStringAsFixed(1)} Jt';
    } else if (rounded >= 1000) {
      return 'Rp ${(rounded / 1000).toStringAsFixed(1)} Rb';
    }
    return formatRupiah(rounded);
  }
}
