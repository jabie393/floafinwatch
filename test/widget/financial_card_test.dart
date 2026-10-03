import 'package:floafinwatch/features/developer/dashboard/presentation/widgets/financial_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinancialCard Widget Tests', () {
    testWidgets('renders title, formatted rupiah amount, and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FinancialCard(
              title: 'Total Hak Dev Terkumpul',
              amount: 3005000,
              subtitle: 'Akumulasi seluruh transaksi lunas',
              icon: Icons.bar_chart_rounded,
              variant: FinancialCardVariant.neutral,
            ),
          ),
        ),
      );

      expect(find.text('Total Hak Dev Terkumpul'), findsOneWidget);
      expect(find.text('Rp 3.005.000'), findsOneWidget);
      expect(find.text('Akumulasi seluruh transaksi lunas'), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
    });

    testWidgets('renders trailing badge when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FinancialCard(
              title: 'Hak Dev Hari Ini',
              amount: 25000,
              subtitle: 'Saldo siap bayar',
              icon: Icons.account_balance_wallet_rounded,
              variant: FinancialCardVariant.action,
              trailingBadge: Text('Siap Cair'),
            ),
          ),
        ),
      );

      expect(find.text('Siap Cair'), findsOneWidget);
      expect(find.text('Rp 25.000'), findsOneWidget);
    });
  });
}
