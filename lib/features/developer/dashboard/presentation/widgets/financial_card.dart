import 'package:floafinwatch/core/constants/app_colors.dart';
import 'package:floafinwatch/core/utils/currency_formatter.dart';
import 'package:floafinwatch/core/widgets/liquid_glass.dart';
import 'package:flutter/material.dart';

enum FinancialCardVariant {
  neutral,
  success,
  warning,
  action,
}

class FinancialCard extends StatelessWidget {
  final String title;
  final num amount;
  final String subtitle;
  final IconData icon;
  final FinancialCardVariant variant;
  final Widget? trailingBadge;

  const FinancialCard({
    super.key,
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    this.variant = FinancialCardVariant.neutral,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color glassBorderColor;
    Color? glassTintColor;
    Color iconBgColor;
    Color iconColor;
    Color titleColor;
    Color amountColor;
    Color subtitleColor;

    switch (variant) {
      case FinancialCardVariant.success:
        glassTintColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
        glassBorderColor = isDark
            ? const Color(0xFF10B981).withValues(alpha: 0.3)
            : const Color(0xFFA7F3D0).withValues(alpha: 0.8);
        iconBgColor = isDark
            ? const Color(0xFF047857).withValues(alpha: 0.4)
            : const Color(0xFFD1FAE5);
        iconColor = isDark ? AppColors.emeraldDarkText : AppColors.emeraldText;
        titleColor = isDark ? AppColors.emeraldDarkText : AppColors.emeraldText;
        amountColor = isDark ? AppColors.emeraldDarkText : AppColors.emeraldText;
        subtitleColor = isDark
            ? AppColors.emeraldDarkText.withValues(alpha: 0.8)
            : AppColors.emeraldText.withValues(alpha: 0.85);
        break;
      case FinancialCardVariant.warning:
        glassTintColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB);
        glassBorderColor = isDark
            ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
            : const Color(0xFFFDE68A).withValues(alpha: 0.8);
        iconBgColor = isDark
            ? const Color(0xFFB45309).withValues(alpha: 0.4)
            : const Color(0xFFFEF3C7);
        iconColor = isDark ? AppColors.amberDarkText : AppColors.amberText;
        titleColor = isDark ? AppColors.amberDarkText : AppColors.amberText;
        amountColor = isDark ? AppColors.amberDarkText : AppColors.amberText;
        subtitleColor = isDark
            ? AppColors.amberDarkText.withValues(alpha: 0.8)
            : AppColors.amberText.withValues(alpha: 0.85);
        break;
      case FinancialCardVariant.action:
        glassTintColor = isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF);
        glassBorderColor = isDark
            ? const Color(0xFF6366F1).withValues(alpha: 0.35)
            : const Color(0xFFC7D2FE).withValues(alpha: 0.8);
        iconBgColor = isDark
            ? const Color(0xFF4338CA).withValues(alpha: 0.4)
            : const Color(0xFFE0E7FF);
        iconColor = isDark ? AppColors.indigoDarkText : AppColors.indigoText;
        titleColor = isDark ? AppColors.indigoDarkText : AppColors.indigoText;
        amountColor = isDark ? AppColors.indigoDarkText : AppColors.indigoText;
        subtitleColor = isDark
            ? AppColors.indigoDarkText.withValues(alpha: 0.8)
            : AppColors.indigoText.withValues(alpha: 0.85);
        break;
      case FinancialCardVariant.neutral:
        glassTintColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        glassBorderColor = isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.85);
        iconBgColor = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFF1F5F9);
        iconColor = isDark ? AppColors.textSecondaryDark : AppColors.slateText;
        titleColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
        amountColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        subtitleColor = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
        break;
    }

    return LiquidGlass(
      borderRadius: 18,
      tintColor: glassTintColor,
      borderColor: glassBorderColor,
      blur: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Liquid Bubble Icon (ala Apple circular glass buttons)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
          const SizedBox(width: 12),
          // Middle: Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: subtitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Right: Amount & optional badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                CurrencyFormatter.formatRupiah(amount),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: amountColor,
                ),
              ),
              if (trailingBadge != null) ...[
                const SizedBox(height: 3),
                trailingBadge!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
