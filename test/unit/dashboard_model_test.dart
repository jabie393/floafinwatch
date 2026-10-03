import 'package:floafinwatch/features/developer/dashboard/domain/dashboard_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeveloperDashboardData Model Tests', () {
    test('parses standard backend JSON correctly', () {
      final json = {
        'summary': {
          'total_earned': 3005000,
          'total_transferred': 2980000,
          'pending_payout': 0,
          'today_earned': 25000,
          'unpaid_payout_count': 0,
        },
        'payout_statistics': {
          'successful': 16,
          'pending': 0,
          'failed': 0,
        },
        'chart': {
          'period': '30d',
          'labels': ['2026-09-16', '2026-09-17'],
          'values': [180000.0, 210000.0],
        },
        'last_updated': '2026-10-01T20:00:00Z',
      };

      final data = DeveloperDashboardData.fromJson(json);

      expect(data.summary.totalEarned, 3005000);
      expect(data.summary.totalTransferred, 2980000);
      expect(data.summary.todayEarned, 25000);
      expect(data.summary.pendingPayout, 0);
      expect(data.payoutStatistics.successful, 16);
      expect(data.chart.period, '30d');
      expect(data.chart.labels.length, 2);
      expect(data.chart.values.length, 2);
      expect(data.chart.values[0], 180000.0);
    });

    test('handles fallback and string numeric conversions safely', () {
      final json = {
        'summary': {
          'dev_total_earned': '4500000',
          'dev_total_paid': 3000000,
          'unpaid_payout_total': '0',
          'dev_unpaid_balance': 1500000,
          'unpaid_payout_count': '2',
        },
        'payout_statistics': {
          'confirmed': '10',
          'waiting_payout': 2,
          'failed': 0,
        },
        'chart': {
          'period': '7d',
          'labels': [],
          'values': [],
        },
      };

      final data = DeveloperDashboardData.fromJson(json);

      expect(data.summary.totalEarned, 4500000);
      expect(data.summary.totalTransferred, 3000000);
      expect(data.summary.todayEarned, 1500000);
      expect(data.summary.unpaidPayoutCount, 2);
      expect(data.payoutStatistics.successful, 10);
      expect(data.payoutStatistics.pending, 2);
    });
  });
}
