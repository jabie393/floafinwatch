import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../features/developer/dashboard/domain/dashboard_model.dart';
import '../features/widgets/presentation/homescreen_widgets.dart';

final widgetServiceProvider = Provider<WidgetService>((ref) {
  return WidgetService(storage: ref.watch(secureStorageServiceProvider));
});

/// Service bertanggung jawab me-render dan menyinkronkan data real ke
/// Home Screen Widget Android & iOS dengan tema iOS Liquid Glass
class WidgetService {
  final SecureStorageService storage;

  WidgetService({required this.storage});

  /// Cache decoded logo ui.Image di RAM agar render headless/background selalu instan & tidak pernah hilang
  static ui.Image? _cachedLogoImage;

  static Future<ui.Image?> getDecodedLogo() async {
    if (_cachedLogoImage != null) return _cachedLogoImage;
    try {
      final byteData = await rootBundle.load('assets/images/app_logo.png');
      final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _cachedLogoImage = frame.image;
      return _cachedLogoImage;
    } catch (e) {
      debugPrint('[WidgetService] Error decoding widget logo: $e');
      return null;
    }
  }

  /// Updates widget snapshot cache & re-renders native homescreen widgets
  Future<void> updateWidgetSnapshot(DeveloperDashboardData data) async {
    // 1. Simpan snapshot cache lokal
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

    // 2. Render dan perbarui widget homescreen native (Android / iOS)
    try {
      await _renderAndPushWidgets(data);
    } catch (e) {
      debugPrint('Error updating home widgets: $e');
    }
  }

  static FinancialChartData? _lastValid7dChart;

  Future<void> _renderAndPushWidgets(DeveloperDashboardData data) async {
    // Pastikan logo di-decode sinkron ke memory sebelum render offscreen
    final logoImage = await getDecodedLogo();

    // Widget 1: Hak Dev (Kotak 2x2)
    final path1 = await HomeWidget.renderFlutterWidget(
      Material(
        type: MaterialType.transparency,
        child: HakDevWidgetView(data: data, logoImage: logoImage),
      ),
      key: 'widget_hak_dev_img',
      logicalSize: const Size(170, 186),
      pixelRatio: 2.5,
    );
    await HomeWidget.saveWidgetData<String>('widget_hak_dev_img', path1);
    await HomeWidget.updateWidget(
      name: 'HakDevWidgetProvider',
      androidName: 'HakDevWidgetProvider',
    );

    // Widget 2: Payout Berikutnya (Kotak 2x2)
    final path2 = await HomeWidget.renderFlutterWidget(
      Material(
        type: MaterialType.transparency,
        child: PayoutWidgetView(data: data),
      ),
      key: 'widget_payout_img',
      logicalSize: const Size(170, 186),
      pixelRatio: 2.5,
    );
    await HomeWidget.saveWidgetData<String>('widget_payout_img', path2);
    await HomeWidget.updateWidget(
      name: 'PayoutWidgetProvider',
      androidName: 'PayoutWidgetProvider',
    );

    // Widget 3: Tren Pencairan (Lebar 4x2)
    // Pastikan widget tren selalu me-render chart 7 hari terakhir yang valid,
    // bukan filter 'year' atau 'month' yang mungkin sedang dipilih pengguna di dalam app.
    if (data.chart.period == '7d' && data.chart.values.isNotEmpty) {
      _lastValid7dChart = data.chart;
    }

    final chartForTrend = (data.chart.period == '7d' && data.chart.values.isNotEmpty)
        ? data.chart
        : (_lastValid7dChart ?? data.chart);

    final trendData = DeveloperDashboardData(
      summary: data.summary,
      payoutStatistics: data.payoutStatistics,
      chart: chartForTrend,
      lastUpdated: data.lastUpdated,
    );

    final path3 = await HomeWidget.renderFlutterWidget(
      Material(
        type: MaterialType.transparency,
        child: TrendChartWidgetView(data: trendData),
      ),
      key: 'widget_trend_img',
      logicalSize: const Size(368, 186),
      pixelRatio: 2.5,
    );
    await HomeWidget.saveWidgetData<String>('widget_trend_img', path3);
    await HomeWidget.updateWidget(
      name: 'TrendChartWidgetProvider',
      androidName: 'TrendChartWidgetProvider',
    );
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
