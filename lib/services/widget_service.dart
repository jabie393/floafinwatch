import 'dart:convert';
import 'dart:math' as math;
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
  static DeveloperDashboardData? _lastRenderedData;

  /// Memeriksa apakah widget harus di-render dalam Dark Mode
  Future<bool> resolveIsDark() async {
    try {
      final appTheme = await storage.getThemeMode();
      if (appTheme == 'dark') return true;
      if (appTheme == 'light') return false;

      return ui.PlatformDispatcher.instance.platformBrightness == ui.Brightness.dark;
    } catch (_) {
      return ui.PlatformDispatcher.instance.platformBrightness == ui.Brightness.dark;
    }
  }

  /// Memperbarui preferensi mode tema widget dan menyinkronkan ke launcher preview
  Future<void> updateThemeMode(String themeModeStr) async {
    final isDark = switch (themeModeStr) {
      'dark' => true,
      'light' => false,
      _ => ui.PlatformDispatcher.instance.platformBrightness == ui.Brightness.dark,
    };
    await HomeWidget.saveWidgetData<String>('theme_mode', themeModeStr);
    await HomeWidget.saveWidgetData<bool>('is_dark_theme', isDark);
    try {
      const channel = MethodChannel('com.example.floafinwatch/app_settings');
      await channel.invokeMethod('updateWidgetPreviews', {
        'theme_mode': themeModeStr,
        'is_dark': isDark,
      });
    } catch (_) {}
  }

  /// Re-render widget secara instan (misal saat berganti tema gelap/terang)
  Future<void> reRenderWidgets([DeveloperDashboardData? fallbackData]) async {
    final data = fallbackData ?? _lastRenderedData;
    if (data != null) {
      await _renderAndPushWidgets(data);
    } else {
      final isDark = await resolveIsDark();
      final themeModeStr = await storage.getThemeMode() ?? 'system';
      await HomeWidget.saveWidgetData<String>('theme_mode', themeModeStr);
      await HomeWidget.saveWidgetData<bool>('is_dark_theme', isDark);
      try {
        const channel = MethodChannel('com.example.floafinwatch/app_settings');
        await channel.invokeMethod('updateWidgetPreviews', {
          'theme_mode': themeModeStr,
          'is_dark': isDark,
        });
      } catch (_) {}
    }
  }

  Future<void> _renderAndPushWidgets(DeveloperDashboardData data) async {
    _lastRenderedData = data;
    final isDark = await resolveIsDark();
    final themeModeStr = await storage.getThemeMode() ?? 'system';
    await HomeWidget.saveWidgetData<String>('theme_mode', themeModeStr);
    await HomeWidget.saveWidgetData<bool>('is_dark_theme', isDark);

    // Pastikan logo di-decode sinkron ke memory sebelum render offscreen
    final logoImage = await getDecodedLogo();

    // Widget 1: Hak Dev (Kotak 2x2)
    final path1 = await HomeWidget.renderFlutterWidget(
      Material(
        type: MaterialType.transparency,
        child: HakDevWidgetView(data: data, logoImage: logoImage, isDark: isDark),
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
        child: PayoutWidgetView(data: data, isDark: isDark),
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
        child: TrendChartWidgetView(data: trendData, isDark: isDark),
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

    // Simpan string data realtime untuk dynamic XML preview
    await HomeWidget.saveWidgetData<String>('hak_dev_amount_str', formatWidgetRupiah(data.summary.todayEarned));
    await HomeWidget.saveWidgetData<String>('hak_dev_cair_str', '${formatWidgetRupiah(data.summary.totalTransferred)} cair');
    await HomeWidget.saveWidgetData<String>('payout_amount_str', formatWidgetRupiah(data.summary.pendingPayout));

    final String payoutFooterStr;
    if (data.summary.waitingConfirmationCount > 0 && data.summary.waitingPayoutCount > 0) {
      payoutFooterStr = '${data.summary.waitingConfirmationCount} konfirmasi · ${data.summary.waitingPayoutCount} antre';
    } else if (data.summary.waitingConfirmationCount > 0) {
      payoutFooterStr = data.summary.waitingConfirmationCount == 1 ? 'Perlu konfirmasi' : '${data.summary.waitingConfirmationCount} perlu konfirmasi';
    } else if (data.summary.waitingPayoutCount > 0) {
      payoutFooterStr = data.summary.waitingPayoutCount == 1 ? 'Menunggu transfer' : '${data.summary.waitingPayoutCount} menunggu transfer';
    } else {
      payoutFooterStr = 'Tidak ada antrean';
    }
    await HomeWidget.saveWidgetData<String>('payout_footer_str', payoutFooterStr);

    String toEnglishMonth(String label) {
      return label
          .replaceAll('OKT', 'OCT')
          .replaceAll('Okt', 'Oct')
          .replaceAll('MEI', 'MAY')
          .replaceAll('Mei', 'May')
          .replaceAll('AGU', 'AUG')
          .replaceAll('Agu', 'Aug')
          .replaceAll('DES', 'DEC')
          .replaceAll('Des', 'Dec');
    }

    final chartValues = trendData.chart.values.isNotEmpty ? trendData.chart.values.take(7).toList() : [0.0];
    final maxVal = chartValues.isNotEmpty ? chartValues.reduce(math.max) : 0.0;
    final hasPayout = maxVal > 0;
    await HomeWidget.saveWidgetData<String>('trend_badge_str', hasPayout ? '+12,4%' : '0%');
    await HomeWidget.saveWidgetData<String>('trend_max_str', formatWidgetRupiah(hasPayout ? maxVal : 500000));
    await HomeWidget.saveWidgetData<String>('trend_mid_str', formatWidgetRupiah(hasPayout ? maxVal / 2 : 250000));

    final chartValues7 = List<double>.generate(7, (i) => i < chartValues.length ? chartValues[i] : 0.0);
    final peakIdx = hasPayout ? chartValues7.indexOf(maxVal) : -1;
    for (int i = 0; i < 7; i++) {
      final val = chartValues7[i];
      final ratio = maxVal > 0 ? (val / maxVal).clamp(0.18, 1.0) : 0.2;
      final isPeak = i == peakIdx && maxVal > 0;
      final heightDp = (58 * ratio).clamp(16.0, 62.0);
      await HomeWidget.saveWidgetData<double>('trend_pillar_${i + 1}_height', heightDp);
      await HomeWidget.saveWidgetData<bool>('trend_pillar_${i + 1}_is_peak', isPeak);
    }

    if (trendData.chart.labels.isNotEmpty) {
      await HomeWidget.saveWidgetData<String>('trend_date_start_str', toEnglishMonth(trendData.chart.labels.first.toUpperCase()));
      await HomeWidget.saveWidgetData<String>('trend_date_end_str', toEnglishMonth(trendData.chart.labels.last.toUpperCase()));
    } else {
      final now = DateTime.now();
      const monthEnglish = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      final dStart = now.subtract(const Duration(days: 6));
      final startStr = '${dStart.day.toString().padLeft(2, '0')} ${monthEnglish[dStart.month - 1]}';
      final endStr = '${now.day.toString().padLeft(2, '0')} ${monthEnglish[now.month - 1]}';
      await HomeWidget.saveWidgetData<String>('trend_date_start_str', startStr);
      await HomeWidget.saveWidgetData<String>('trend_date_end_str', endStr);
    }

    // 4. Update system dynamic previews for Android 15+ launcher picker
    try {
      const channel = MethodChannel('com.example.floafinwatch/app_settings');
      await channel.invokeMethod('updateWidgetPreviews', {
        'theme_mode': themeModeStr,
        'is_dark': isDark,
      });
    } catch (_) {}
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

  /// Mereset seluruh data widget homescreen dan preview ke kondisi kosong/nol (misal saat logout)
  Future<void> clearWidgetData() async {
    _lastRenderedData = null;
    _lastValid7dChart = null;

    // 1. Hapus cache snapshot lokal
    await storage.clearWidgetSnapshot();

    // 2. Data kosong (Rp 0 & tidak ada antrean)
    final isDark = await resolveIsDark();
    final themeModeStr = await storage.getThemeMode() ?? 'system';
    await HomeWidget.saveWidgetData<String>('theme_mode', themeModeStr);
    await HomeWidget.saveWidgetData<bool>('is_dark_theme', isDark);

    // Reset data string dynamic preview
    await HomeWidget.saveWidgetData<String>('hak_dev_amount_str', 'Rp 0');
    await HomeWidget.saveWidgetData<String>('hak_dev_cair_str', 'Rp 0 cair');
    await HomeWidget.saveWidgetData<String>('payout_amount_str', 'Rp 0');
    await HomeWidget.saveWidgetData<String>('payout_footer_str', 'Tidak ada antrean');
    await HomeWidget.saveWidgetData<String>('trend_badge_str', '0%');
    await HomeWidget.saveWidgetData<String>('trend_max_str', 'Rp 0');
    await HomeWidget.saveWidgetData<String>('trend_mid_str', 'Rp 0');

    for (int i = 0; i < 7; i++) {
      await HomeWidget.saveWidgetData<double>('trend_pillar_${i + 1}_height', 16.0);
      await HomeWidget.saveWidgetData<bool>('trend_pillar_${i + 1}_is_peak', false);
    }

    final now = DateTime.now();
    const monthEnglish = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final dStart = now.subtract(const Duration(days: 6));
    final startStr = '${dStart.day.toString().padLeft(2, '0')} ${monthEnglish[dStart.month - 1]}';
    final endStr = '${now.day.toString().padLeft(2, '0')} ${monthEnglish[now.month - 1]}';
    await HomeWidget.saveWidgetData<String>('trend_date_start_str', startStr);
    await HomeWidget.saveWidgetData<String>('trend_date_end_str', endStr);

    final emptyData = DeveloperDashboardData(
      summary: const FinancialSummary(
        totalEarned: 0,
        totalTransferred: 0,
        pendingPayout: 0,
        todayEarned: 0,
        unpaidPayoutCount: 0,
        waitingPayoutCount: 0,
        waitingConfirmationCount: 0,
      ),
      payoutStatistics: const PayoutStatistics(
        successful: 0,
        pending: 0,
        failed: 0,
      ),
      chart: FinancialChartData(
        period: '7d',
        labels: [startStr, endStr],
        values: const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      ),
      lastUpdated: null,
    );

    final logoImage = await getDecodedLogo();

    // Render ulang gambar widget menjadi state kosong
    final path1 = await HomeWidget.renderFlutterWidget(
      Material(
        type: MaterialType.transparency,
        child: HakDevWidgetView(data: emptyData, logoImage: logoImage, isDark: isDark),
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

    final path2 = await HomeWidget.renderFlutterWidget(
      Material(
        type: MaterialType.transparency,
        child: PayoutWidgetView(data: emptyData, isDark: isDark),
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

    final path3 = await HomeWidget.renderFlutterWidget(
      Material(
        type: MaterialType.transparency,
        child: TrendChartWidgetView(data: emptyData, isDark: isDark),
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

    // Update dynamic preview di launcher
    try {
      const channel = MethodChannel('com.example.floafinwatch/app_settings');
      await channel.invokeMethod('updateWidgetPreviews', {
        'theme_mode': themeModeStr,
        'is_dark': isDark,
      });
    } catch (_) {}
  }
}
