import 'package:floafinwatch/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('formats standard rupiah amounts correctly', () {
      expect(CurrencyFormatter.formatRupiah(3005000), 'Rp 3.005.000');
      expect(CurrencyFormatter.formatRupiah(25000), 'Rp 25.000');
      expect(CurrencyFormatter.formatRupiah(0), 'Rp 0');
      expect(CurrencyFormatter.formatRupiah(null), 'Rp 0');
    });

    test('formats compact amounts correctly for summaries', () {
      expect(CurrencyFormatter.formatCompact(1500000), 'Rp 1.5 Jt');
      expect(CurrencyFormatter.formatCompact(2500000000), 'Rp 2.5 M');
      expect(CurrencyFormatter.formatCompact(50000), 'Rp 50.0 Rb');
      expect(CurrencyFormatter.formatCompact(500), 'Rp 500');
      expect(CurrencyFormatter.formatCompact(0), 'Rp 0');
      expect(CurrencyFormatter.formatCompact(null), 'Rp 0');
    });
  });
}
