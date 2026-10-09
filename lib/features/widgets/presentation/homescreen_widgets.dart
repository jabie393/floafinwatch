import 'dart:math' as math;
import 'dart:ui' as ui;
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
  final ui.Image? logoImage;

  const HakDevWidgetView({
    super.key,
    this.data,
    this.width = 170,
    this.height = 186,
    this.logoImage,
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
          // Header: Ikon Aplikasi Resmi F Loafinwatch (Pre-decoded ui.Image atau Image.asset dengan fallback)
          Align(
            alignment: Alignment.centerLeft,
            child: logoImage != null
                ? RawImage(
                    image: logoImage,
                    height: 36,
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.contain,
                  )
                : Image.asset(
                    'assets/images/app_logo.png',
                    height: 36,
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      );
                    },
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
    this.height = 186,
  });

  @override
  Widget build(BuildContext context) {
    final pending = data?.summary.pendingPayout ?? 0;
    final waitingPayoutCount = data?.summary.waitingPayoutCount ?? 0;
    final waitingConfirmationCount = data?.summary.waitingConfirmationCount ?? 0;

    // Menentukan status & teks footer sesuai Opsi A:
    // 1. Campuran: X konfirmasi · Y antre
    // 2. Hanya konfirmasi: X perlu konfirmasi / Perlu konfirmasi
    // 3. Hanya antre: X menunggu transfer / Menunggu transfer
    // 4. Rp 0: Tidak ada antrean
    final String footerText;
    final Color footerColor;
    final Color iconBgColor;
    final Color iconColor;
    final IconData headerIcon;

    if (waitingConfirmationCount > 0 && waitingPayoutCount > 0) {
      footerText = '$waitingConfirmationCount konfirmasi · $waitingPayoutCount antre';
      footerColor = const Color(0xFF0284C7);
      iconBgColor = const Color(0xFFE0EDFB);
      iconColor = const Color(0xFF0284C7);
      headerIcon = Icons.notifications_active_rounded;
    } else if (waitingConfirmationCount > 0) {
      footerText = waitingConfirmationCount == 1 ? 'Perlu konfirmasi' : '$waitingConfirmationCount perlu konfirmasi';
      footerColor = const Color(0xFF0284C7);
      iconBgColor = const Color(0xFFE0EDFB);
      iconColor = const Color(0xFF0284C7);
      headerIcon = Icons.pending_actions_rounded;
    } else if (waitingPayoutCount > 0) {
      footerText = waitingPayoutCount == 1 ? 'Menunggu transfer' : '$waitingPayoutCount menunggu transfer';
      footerColor = const Color(0xFF6C8494);
      iconBgColor = const Color(0xFFFFEAD8);
      iconColor = const Color(0xFFE2782A);
      headerIcon = Icons.access_time_filled_rounded;
    } else {
      footerText = 'Tidak ada antrean';
      footerColor = const Color(0xFF8BA2B2);
      iconBgColor = const Color(0xFFF1F5F9);
      iconColor = const Color(0xFF94A3B8);
      headerIcon = Icons.check_circle_outline_rounded;
    }

    return WidgetGlassCard(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Icon Dinamis
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBgColor,
                ),
                alignment: Alignment.center,
                child: Icon(
                  headerIcon,
                  size: 20,
                  color: iconColor,
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

          // Footer: Status Dinamis + Chevron
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  footerText,
                  style: TextStyle(
                    color: footerColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: footerColor,
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
    this.width = 368,
    this.height = 186,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Pastikan data grafik selalu strictly 7 hari terakhir (bukan filter 'year' / 'month')
    final isStrict7d = data != null &&
        data!.chart.period == '7d' &&
        data!.chart.values.isNotEmpty &&
        data!.chart.labels.length <= 7;

    final List<double> values;
    final List<String> labels;

    if (isStrict7d) {
      values = data!.chart.values.take(7).toList();
      labels = data!.chart.labels.take(7).toList();
    } else {
      // Fallback tanggal 7 hari terakhir yang selalu dinamis sampai hari ini
      final now = DateTime.now();
      const monthShortNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      labels = List.generate(7, (i) {
        final d = now.subtract(Duration(days: 6 - i));
        final dayStr = d.day.toString().padLeft(2, '0');
        return '$dayStr ${monthShortNames[d.month - 1]}';
      });

      if (data != null && data!.chart.period == '7d' && data!.chart.values.isNotEmpty) {
        values = data!.chart.values.take(7).toList();
      } else {
        values = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      }
    }

    final effectiveValues = List<double>.generate(7, (i) => i < values.length ? values[i] : 0.0);
    final rawMax = effectiveValues.isNotEmpty ? effectiveValues.reduce(math.max) : 0.0;
    final hasPayout = rawMax > 0;
    final double maxVal = hasPayout ? rawMax : 500000.0; // Skala standar 500rb jika belum ada pencairan
    final maxIndex = hasPayout ? effectiveValues.indexOf(rawMax) : -1;

    final firstLabel = labels.isNotEmpty ? labels.first.toUpperCase() : '29 SEP';
    final lastLabel = labels.isNotEmpty ? labels.last.toUpperCase() : '05 OKT';
    final badgeText = hasPayout ? '+12,4%' : '0%';

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
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Color(0xFF0C5D97),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),

          // Chart Area: Nominal disamping grafik + 7 Pilar Lengkung
          SizedBox(
            height: 78,
            child: Stack(
              children: [
                // 3 Baris Garis Panduan dengan Nominal Terpasang Sejajar Presisi
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Level Atas (Maksimal)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text(
                            formatWidgetRupiah(maxVal),
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xFF6C8494),
                              fontWeight: FontWeight.w600,
                              fontSize: 8.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0x336C8494),
                          ),
                        ),
                      ],
                    ),

                    // Level Tengah (Setengah)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text(
                            formatWidgetRupiah(maxVal / 2),
                            maxLines: 1,
                            style: const TextStyle(
                              color: Color(0xFF8BA2B2),
                              fontWeight: FontWeight.w500,
                              fontSize: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0x1F6C8494),
                          ),
                        ),
                      ],
                    ),

                    // Level Bawah (Rp 0 - Sejajar Presisi dengan Garis Paling Bawah)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 48,
                          child: Text(
                            'Rp 0',
                            maxLines: 1,
                            style: TextStyle(
                              color: Color(0xFF8BA2B2),
                              fontWeight: FontWeight.w500,
                              fontSize: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0x336C8494),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 7 Pilar Lengkung (Jika nominal 0: resting pill halus di garis Rp 0; Jika ada: proporsional)
                Padding(
                  padding: const EdgeInsets.only(left: 52, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(effectiveValues.length, (index) {
                      final val = effectiveValues[index];
                      final isPeak = index == maxIndex && hasPayout;

                      final double pHeight;
                      final BoxDecoration pDecoration;

                      if (val <= 0) {
                        pHeight = 5.0;
                        pDecoration = BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: const Color(0xFFD6E4F0),
                        );
                      } else {
                        final double ratio = (val / maxVal).clamp(0.2, 1.0);
                        pHeight = (62 * ratio).clamp(16.0, 64.0);
                        pDecoration = BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
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
                        );
                      }

                      return Container(
                        width: 24,
                        height: pHeight,
                        decoration: pDecoration,
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Date Labels (Kembali ke semula dengan padding offset Y-Axis)
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Row(
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
          ),
        ],
      ),
    );
  }
}
