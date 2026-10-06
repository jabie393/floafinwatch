import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../developer/dashboard/domain/dashboard_model.dart';

/// Formatter format ringkas ala iOS ("Rp 4,1 jt", "Rp 300 rb")
String formatWidgetRupiah(num? amount) {
  if (amount == null || amount == 0) return 'Rp 0';
  final val = amount.toDouble();
  if (val >= 1000000000) {
    final formatted = (val / 1000000000).toStringAsFixed(1).replaceAll('.', ',');
    return 'Rp $formatted M';
  } else if (val >= 1000000) {
    final formatted = (val / 1000000).toStringAsFixed(1).replaceAll('.', ',');
    return 'Rp $formatted jt';
  } else if (val >= 1000) {
    final rounded = (val / 1000).round();
    return 'Rp $rounded rb';
  }
  return 'Rp ${val.toInt()}';
}

/// Liquid Glass Container dengan efek glossy border dan soft shadow
class WidgetGlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  const WidgetGlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xE8F4F9FD),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xC0FFFFFF),
          width: 1.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0A3554),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x40FFFFFF),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 1. Widget Kotak: HAK DEV (Small 2x2)
class HakDevWidgetView extends StatelessWidget {
  final DeveloperDashboardData? data;
  final double? width;
  final double? height;

  const HakDevWidgetView({
    super.key,
    this.data,
    this.width = 170,
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) {
    final hakDev = data?.summary.todayEarned ?? 4100000;
    final totalCair = data?.summary.totalTransferred ?? 3800000;

    return WidgetGlassCard(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Ikon Aplikasi Resmi F Loafinwatch (Transparent PNG - Rata Kiri Sejajar)
          Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/images/app_logo.png',
              height: 36,
              alignment: Alignment.centerLeft,
              fit: BoxFit.contain,
            ),
          ),

          // Body: "HAK DEV" & Nominal Besar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HAK DEV',
                style: TextStyle(
                  color: Color(0xFF6C8494),
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatWidgetRupiah(hakDev),
                  style: const TextStyle(
                    color: Color(0xFF0B3B5C),
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.6,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),

          // Footer: Centang + "Rp ... cair"
          Row(
            children: [
              const Icon(
                Icons.check_rounded,
                size: 15,
                color: Color(0xFF1B7A46),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${formatWidgetRupiah(totalCair)} cair',
                  style: const TextStyle(
                    color: Color(0xFF1B7A46),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2. Widget Kotak: PAYOUT BERIKUTNYA (Small 2x2)
class PayoutWidgetView extends StatelessWidget {
  final DeveloperDashboardData? data;
  final double? width;
  final double? height;

  const PayoutWidgetView({
    super.key,
    this.data,
    this.width = 170,
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) {
    final pending = data?.summary.pendingPayout ?? 300000;
    final unpaidCount = data?.summary.unpaidPayoutCount ?? 1;

    return WidgetGlassCard(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Icon Clock Jam
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFEAD8),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.access_time_filled_rounded,
                  size: 20,
                  color: Color(0xFFE2782A),
                ),
              ),
            ],
          ),

          // Body: "PAYOUT BERIKUTNYA" & Nominal Besar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PAYOUT BERIKUTNYA',
                style: TextStyle(
                  color: Color(0xFF6C8494),
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatWidgetRupiah(pending),
                  style: const TextStyle(
                    color: Color(0xFF0B3B5C),
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: -0.6,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),

          // Footer: "Perlu konfirmasi" / "Siap cair" + Chevron
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                unpaidCount > 0 ? 'Perlu konfirmasi' : 'Semua cair',
                style: const TextStyle(
                  color: Color(0xFF6C8494),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: Color(0xFF6C8494),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 3. Widget Lebar: TREN PENCAIRAN 7 HARI (Medium 4x2)
class TrendChartWidgetView extends StatelessWidget {
  final DeveloperDashboardData? data;
  final double? width;
  final double? height;

  const TrendChartWidgetView({
    super.key,
    this.data,
    this.width = 350,
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) {
    final values = (data != null && data!.chart.values.isNotEmpty)
        ? data!.chart.values.take(7).toList()
        : [15.0, 30.0, 20.0, 65.0, 35.0, 45.0, 18.0];

    final labels = (data != null && data!.chart.labels.isNotEmpty)
        ? data!.chart.labels.take(7).toList()
        : ['29 Sep', '30 Sep', '01 Okt', '02 Okt', '03 Okt', '04 Okt', '05 Okt'];

    final maxVal = values.isNotEmpty ? values.reduce(math.max) : 100.0;
    final maxIndex = values.indexOf(maxVal);

    final firstLabel = labels.isNotEmpty ? labels.first.toUpperCase() : '29 SEP';
    final lastLabel = labels.isNotEmpty ? labels.last.toUpperCase() : '05 OKT';

    return WidgetGlassCard(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Judul + Subtitle & Badge Persentase
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tren pencairan',
                    style: TextStyle(
                      color: Color(0xFF0B3B5C),
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    '7 hari terakhir',
                    style: TextStyle(
                      color: Color(0xFF6C8494),
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F0FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBDDFF5), width: 1),
                ),
                child: const Text(
                  '+12,4%',
                  style: TextStyle(
                    color: Color(0xFF0C5D97),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),

          // Chart Area: 7 Pillars with Guideline
          SizedBox(
            height: 70,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Horizontal guideline
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: const Color(0x336C8494),
                  ),
                ),

                // 7 Curved Bars
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(values.length, (index) {
                    final val = values[index];
                    final double ratio = maxVal > 0 ? (val / maxVal).clamp(0.18, 1.0) : 0.2;
                    final isPeak = index == maxIndex && maxVal > 0;

                    return Container(
                      width: 26,
                      height: (58 * ratio).clamp(16.0, 62.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        gradient: isPeak
                            ? const LinearGradient(
                                colors: [Color(0xFF75AEE0), Color(0xFF4385BE)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : const LinearGradient(
                                colors: [Color(0xFFD2E6F5), Color(0xFFB5D7EF)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Date Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                firstLabel,
                style: const TextStyle(
                  color: Color(0xFF6C8494),
                  fontWeight: FontWeight.w600,
                  fontSize: 9.5,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                lastLabel,
                style: const TextStyle(
                  color: Color(0xFF6C8494),
                  fontWeight: FontWeight.w600,
                  fontSize: 9.5,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 4. Master Overview Widget (All-in-one 4x3 / 4x4)
class MasterOverviewWidgetView extends StatelessWidget {
  final DeveloperDashboardData? data;

  const MasterOverviewWidgetView({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 350,
      height: 350,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: HakDevWidgetView(
                    data: data,
                    width: null,
                    height: null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PayoutWidgetView(
                    data: data,
                    width: null,
                    height: null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TrendChartWidgetView(
              data: data,
              width: double.infinity,
              height: null,
            ),
          ),
        ],
      ),
    );
  }
}
