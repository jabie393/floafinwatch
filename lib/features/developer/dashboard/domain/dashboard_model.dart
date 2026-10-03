class FinancialSummary {
  final int totalEarned;
  final int totalTransferred;
  final int pendingPayout;
  final int todayEarned;
  final int unpaidPayoutCount;

  const FinancialSummary({
    required this.totalEarned,
    required this.totalTransferred,
    required this.pendingPayout,
    required this.todayEarned,
    this.unpaidPayoutCount = 0,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.round();
      if (val is String) return int.tryParse(val) ?? (double.tryParse(val)?.round() ?? 0);
      return 0;
    }

    return FinancialSummary(
      totalEarned: parseInt(json['total_earned'] ?? json['dev_total_earned']),
      totalTransferred: parseInt(json['total_transferred'] ?? json['dev_total_paid']),
      pendingPayout: parseInt(json['pending_payout'] ?? json['unpaid_payout_total']),
      todayEarned: parseInt(json['today_earned'] ?? json['dev_unpaid_balance']),
      unpaidPayoutCount: parseInt(json['unpaid_payout_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_earned': totalEarned,
      'total_transferred': totalTransferred,
      'pending_payout': pendingPayout,
      'today_earned': todayEarned,
      'unpaid_payout_count': unpaidPayoutCount,
    };
  }
}

class PayoutStatistics {
  final int successful;
  final int pending;
  final int failed;

  const PayoutStatistics({
    required this.successful,
    required this.pending,
    required this.failed,
  });

  factory PayoutStatistics.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.round();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return PayoutStatistics(
      successful: parseInt(json['successful'] ?? json['confirmed']),
      pending: parseInt(json['pending'] ?? json['waiting_payout']),
      failed: parseInt(json['failed']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'successful': successful,
      'pending': pending,
      'failed': failed,
    };
  }
}

class FinancialChartData {
  final String period;
  final List<String> labels;
  final List<double> values;

  const FinancialChartData({
    required this.period,
    required this.labels,
    required this.values,
  });

  factory FinancialChartData.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'] is List ? (json['labels'] as List) : [];
    final rawValues = json['values'] is List ? (json['values'] as List) : [];

    final labels = rawLabels.map((e) => e.toString()).toList();
    final values = rawValues.map((e) {
      if (e is num) return e.toDouble();
      if (e is String) return double.tryParse(e) ?? 0.0;
      return 0.0;
    }).toList();

    return FinancialChartData(
      period: json['period']?.toString() ?? '30d',
      labels: labels,
      values: values,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'labels': labels,
      'values': values,
    };
  }
}

class DeveloperDashboardData {
  final FinancialSummary summary;
  final PayoutStatistics payoutStatistics;
  final FinancialChartData chart;
  final DateTime? lastUpdated;

  const DeveloperDashboardData({
    required this.summary,
    required this.payoutStatistics,
    required this.chart,
    this.lastUpdated,
  });

  factory DeveloperDashboardData.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] is Map<String, dynamic>
        ? json['summary'] as Map<String, dynamic>
        : <String, dynamic>{};
    final statsJson = json['payout_statistics'] is Map<String, dynamic>
        ? json['payout_statistics'] as Map<String, dynamic>
        : <String, dynamic>{};
    final chartJson = json['chart'] is Map<String, dynamic>
        ? json['chart'] as Map<String, dynamic>
        : <String, dynamic>{};

    DateTime? lastUpdated;
    if (json['last_updated'] != null) {
      lastUpdated = DateTime.tryParse(json['last_updated'].toString());
    }

    return DeveloperDashboardData(
      summary: FinancialSummary.fromJson(summaryJson),
      payoutStatistics: PayoutStatistics.fromJson(statsJson),
      chart: FinancialChartData.fromJson(chartJson),
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }
}
