import 'package:floafinwatch/core/constants/app_colors.dart';
import 'package:floafinwatch/core/utils/currency_formatter.dart';
import 'package:floafinwatch/core/widgets/liquid_glass.dart';
import 'package:floafinwatch/features/developer/dashboard/domain/dashboard_model.dart';
import 'package:flutter/material.dart';

class HeroFinancialCard extends StatelessWidget {
  final FinancialSummary summary;
  final PayoutStatistics stats;

  const HeroFinancialCard({
    super.key,
    required this.summary,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final glassTintColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final glassBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.85);

    final emeraldColor = isDark
        ? AppColors.emeraldDarkText
        : AppColors.emeraldText;
    final amberColor = isDark ? AppColors.amberDarkText : AppColors.amberText;
    final indigoColor = isDark
        ? AppColors.indigoDarkText
        : AppColors.indigoText;

    return LiquidGlass(
      borderRadius: 24,
      tintColor: glassTintColor,
      borderColor: glassBorderColor,
      blur: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Total Hak Dev Terkumpul
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Liquid Bubble Icon: Wallet
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2563EB).withValues(alpha: 0.18)
                      : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                        : const Color(0xFFBFDBFE),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: isDark ? 0.22 : 0.10,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Hak Dev Terkumpul',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.formatRupiah(summary.totalEarned),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Sudah Ditransfer ke Dev (Sejajar dengan Total Hak Dev di atasnya)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Liquid Bubble Icon: Check
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF047857).withValues(alpha: 0.25)
                      : const Color(0xFFD1FAE5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFFA7F3D0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: emeraldColor.withValues(
                        alpha: isDark ? 0.20 : 0.10,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 20,
                    color: emeraldColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Sudah Ditransfer ke Dev',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          '${stats.successful}x Berhasil',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textMutedDark
                                : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.formatRupiah(
                          summary.totalTransferred,
                        ),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: emeraldColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Divider Tipis Halus
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Container(
              height: 0.85,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),

          // 3. Lower Section: Tepat 2 Info (Hari Ini di kiri & Pending di kanan)
          Row(
            children: [
              // Info 1: Hak Dev Hari Ini (Kiri)
              Expanded(
                child: _buildBottomMetric(
                  icon: Icons.trending_up_rounded,
                  iconColor: indigoColor,
                  iconBgColor: isDark
                      ? const Color(0xFF4338CA).withValues(alpha: 0.25)
                      : const Color(0xFFE0E7FF),
                  label: 'Hak Dev Hari Ini',
                  amount: summary.todayEarned,
                  amountColor: indigoColor,
                  subWidget: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: summary.todayEarned > 0
                          ? (isDark
                                ? const Color(0xFF10B981)
                                      .withValues(alpha: 0.16)
                                : AppColors.emeraldBg)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : AppColors.slateBg),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: summary.todayEarned > 0
                            ? (isDark
                                  ? const Color(0xFF10B981)
                                        .withValues(alpha: 0.35)
                                  : AppColors.emeraldBorder)
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : AppColors.borderLight),
                        width: 0.85,
                      ),
                    ),
                    child: Text(
                      summary.todayEarned > 0 ? 'Siap Cair' : 'Lunas',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: summary.todayEarned > 0
                            ? emeraldColor
                            : (isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMutedLight),
                      ),
                    ),
                  ),
                  isDark: isDark,
                ),
              ),

              // Vertical Hairline Separator
              Container(
                width: 0.85,
                height: 52,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),

              // Info 2: Menunggu Payout (Kanan)
              Expanded(
                child: _buildBottomMetric(
                  icon: Icons.schedule_rounded,
                  iconColor: amberColor,
                  iconBgColor: isDark
                      ? const Color(0xFFB45309).withValues(alpha: 0.25)
                      : const Color(0xFFFEF3C7),
                  label: 'Menunggu Payout',
                  amount: summary.pendingPayout,
                  amountColor: amberColor,
                  subWidget: Text(
                    summary.pendingPayout > 0
                        ? (summary.waitingConfirmationCount > 0 &&
                                summary.waitingPayoutCount > 0
                            ? '${summary.waitingPayoutCount} pending, ${summary.waitingConfirmationCount} konfirmasi'
                            : (summary.waitingConfirmationCount > 0
                                ? '${summary.waitingConfirmationCount} perlu konfirmasi'
                                : '${summary.unpaidPayoutCount} tagihan pending'))
                        : 'Dana belum dicairkan',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomMetric({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required num amount,
    required Color amountColor,
    required Widget subWidget,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top: Label di kiri & Mini Bubble Icon nempel di kanan
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.8),
                  width: 0.85,
                ),
              ),
              child: Center(child: Icon(icon, size: 12, color: iconColor)),
            ),
          ],
        ),

        const SizedBox(height: 5),

        // Middle: Amount
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            CurrencyFormatter.formatRupiah(amount),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: amountColor,
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Bottom: Status or subtitle
        subWidget,
      ],
    );
  }
}
