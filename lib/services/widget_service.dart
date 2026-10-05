import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../features/developer/dashboard/domain/dashboard_model.dart';

final widgetServiceProvider = Provider<WidgetService>((ref) {
  return WidgetService(storage: ref.watch(secureStorageServiceProvider));
});

/// Service responsible for preparing and synchronizing financial summary snapshots
/// for Android Home Screen Widget consumption.
class WidgetService {
  final SecureStorageService storage;

  WidgetService({required this.storage});

  /// Updates widget snapshot cache from latest backend dashboard data.
  /// Does NOT store tokens or sensitive credentials.
  Future<void> updateWidgetSnapshot(DeveloperDashboardData data) async {
    final payload = {
      'total_earned_formatted': CurrencyFormatter.formatRupiah(data.summary.totalEarned),
      'total_transferred_formatted': CurrencyFormatter.formatRupiah(data.summary.totalTransferred),
      'pending_payout_formatted': CurrencyFormatter.formatRupiah(data.summary.pendingPayout),
      'today_earned_formatted': CurrencyFormatter.formatRupiah(data.summary.todayEarned),
      'unpaid_payout_count': data.summary.unpaidPayoutCount,
      'successful_payout_count': data.payoutStatistics.successful,
      'last_updated': DateFormatter.formatTimestamp(data.lastUpdated),
      'raw_timestamp': data.lastUpdated?.toIso8601String(),
    };

    await storage.saveWidgetSnapshot(json.encode(payload));
  }

  /// Retrieves the last recorded snapshot for offline widget rendering.
  Future<Map<String, dynamic>?> getLastWidgetSnapshot() async {
    final raw = await storage.getWidgetSnapshot();
    if (raw == null) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
