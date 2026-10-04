import 'package:floafinwatch/core/constants/app_colors.dart';
import 'package:floafinwatch/core/utils/currency_formatter.dart';
import 'package:floafinwatch/core/utils/date_formatter.dart';
import 'package:floafinwatch/core/widgets/liquid_glass.dart';
import 'package:floafinwatch/features/auth/domain/auth_state.dart';
import 'package:floafinwatch/features/auth/presentation/auth_notifier.dart';
import 'package:floafinwatch/features/developer/dashboard/domain/dashboard_model.dart';
import 'package:floafinwatch/features/developer/dashboard/presentation/dashboard_notifier.dart';
import 'package:floafinwatch/features/developer/dashboard/presentation/widgets/dashboard_skeleton.dart';
import 'package:floafinwatch/features/developer/dashboard/presentation/widgets/financial_chart_card.dart';
import 'package:floafinwatch/features/developer/dashboard/presentation/widgets/hero_financial_card.dart';
import 'package:floafinwatch/features/developer/payouts/domain/payout_model.dart';
import 'package:floafinwatch/features/developer/payouts/payouts_screen.dart';
import 'package:floafinwatch/features/developer/transactions/domain/transaction_model.dart';
import 'package:floafinwatch/features/developer/transactions/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DeveloperDashboardScreen extends ConsumerWidget {
  const DeveloperDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final dashboardAsync = ref.watch(dashboardNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: AmbientLiquidBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.read(dashboardNotifierProvider.notifier).refresh(),
                ref.refresh(transactionsProvider.future),
                ref.refresh(payoutsProvider.future),
              ]);
            },
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Sticky or sleek top bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: _buildHeader(context, ref, authState, isDark),
                  ),
                ),

                // Content body
                SliverToBoxAdapter(
                  child: dashboardAsync.when(
                    loading: () => const DashboardSkeleton(),
                    error: (error, _) =>
                        _buildErrorView(context, ref, error, isDark),
                    data: (data) => _buildDashboardContent(
                      context,
                      ref,
                      authState,
                      data,
                      isDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
    bool isDark,
  ) {
    final user = authState.user;
    final userName = user?.name ?? 'Developer';
    final initials = userName
        .trim()
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .take(2)
        .join();

    return Row(
      children: [
        // Avatar with initials
        GestureDetector(
          onTap: () => context.go('/profile'),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.35 : 0.85),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials.isNotEmpty ? initials : 'RD',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Greeting & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, $userName 👋',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Ringkasan finansial developer kamu',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(
    BuildContext context,
    WidgetRef ref,
    Object error,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.errorBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal Memuat Data Finansial',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textMutedDark
                    : AppColors.textMutedLight,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              onPressed: () {
                ref.read(dashboardNotifierProvider.notifier).refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
    DeveloperDashboardData data,
    bool isDark,
  ) {
    final summary = data.summary;
    final stats = data.payoutStatistics;
    final chart = data.chart;
    final recentTransactions = ref.watch(transactionsProvider).value ?? [];
    final recentPayouts = ref.watch(payoutsProvider).value ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Master Hero Financial Card (Seluruh Metrik Terpadu Liquid Glass)
          HeroFinancialCard(summary: summary, stats: stats),
          const SizedBox(height: 20),

          // Tren Pencairan Line Chart
          FinancialChartCard(chartData: chart),
          const SizedBox(height: 24),

          // Transaksi Terbaru Preview Section
          _buildRecentTransactionsSection(context, recentTransactions, isDark),
          const SizedBox(height: 24),

          // Payout Terbaru Preview Section
          _buildRecentPayoutsSection(context, recentPayouts, isDark),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsSection(
    BuildContext context,
    List<TransactionItem> transactions,
    bool isDark,
  ) {
    final previewList = transactions.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transaksi Terbaru',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            InkWell(
              onTap: () => context.go('/dev/transactions'),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Lihat Semua',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (previewList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Center(
              child: Text(
                'Belum ada transaksi terbaru',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight,
                ),
              ),
            ),
          )
        else
          ...previewList.map((tx) => _buildTransactionPreviewItem(tx, isDark)),
      ],
    );
  }

  Widget _buildTransactionPreviewItem(TransactionItem tx, bool isDark) {
    return Tooltip(
      message: tx.payerName,
      preferBelow: false,
      verticalOffset: 20,
      triggerMode: TooltipTriggerMode.longPress,
      showDuration: const Duration(seconds: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.95)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.25),
          width: 0.85,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.3,
      ),
      child: LiquidGlass(
        borderRadius: 18,
        blur: 16,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_downward_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.payerName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormatter.formatDateTime(tx.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatRupiah(tx.devNetShare),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.emeraldText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hak Dev',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPayoutsSection(
    BuildContext context,
    List<PayoutItem> payouts,
    bool isDark,
  ) {
    final previewList = payouts.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payout Terbaru',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            InkWell(
              onTap: () => context.go('/dev/payouts'),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Lihat Semua',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (previewList.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Center(
              child: Text(
                'Belum ada riwayat payout',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight,
                ),
              ),
            ),
          )
        else
          ...previewList.map(
            (po) => _buildPayoutPreviewItem(context, po, isDark),
          ),
      ],
    );
  }

  Map<String, dynamic> _getPayoutStatusConfig(String status, bool isDark) {
    switch (status) {
      case 'waiting_payout':
      case 'pending':
      case 'processing':
        return {
          'label': 'Menunggu Pembayaran',
          'shortLabel': 'Pending',
          'icon': Icons.hourglass_top_rounded,
          'bgColor': isDark
              ? const Color(0xFF78350F).withValues(alpha: 0.45)
              : const Color(0xFFFEF3C7),
          'borderColor': isDark
              ? const Color(0xFFD97706).withValues(alpha: 0.4)
              : const Color(0xFFFDE68A),
          'textColor': isDark
              ? const Color(0xFFFBBF24)
              : const Color(0xFFD97706),
        };
      case 'waiting_confirmation':
        return {
          'label': 'Menunggu Konfirmasi',
          'shortLabel': 'Konfirmasi',
          'icon': Icons.pending_actions_rounded,
          'bgColor': isDark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.45)
              : const Color(0xFFDBEAFE),
          'borderColor': isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
              : const Color(0xFFBFDBFE),
          'textColor': isDark
              ? const Color(0xFF60A5FA)
              : const Color(0xFF2563EB),
        };
      case 'confirmed':
      case 'completed':
        return {
          'label': 'Dikonfirmasi Diterima',
          'shortLabel': 'Selesai',
          'icon': Icons.check_circle_rounded,
          'bgColor': isDark
              ? const Color(0xFF064E3B).withValues(alpha: 0.45)
              : const Color(0xFFDCFCE7),
          'borderColor': isDark
              ? const Color(0xFF059669).withValues(alpha: 0.45)
              : const Color(0xFF86EFAC),
          'textColor': isDark
              ? const Color(0xFF34D399)
              : const Color(0xFF15803D),
        };
      case 'rejected':
      case 'failed':
        return {
          'label': 'Ditolak',
          'shortLabel': 'Ditolak',
          'icon': Icons.cancel_outlined,
          'bgColor': isDark
              ? const Color(0xFF7F1D1D).withValues(alpha: 0.25)
              : const Color(0xFFFEF2F2),
          'borderColor': isDark
              ? const Color(0xFF991B1B).withValues(alpha: 0.45)
              : const Color(0xFFFECACA),
          'textColor': isDark
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFB91C1C),
        };
      default:
        final normalized = status.toLowerCase().replaceAll(' ', '_');
        if (normalized.contains('payout') ||
            normalized.contains('wait') ||
            normalized.contains('pend') ||
            normalized.contains('proc')) {
          return {
            'label': 'Menunggu Pembayaran',
            'shortLabel': 'Pending',
            'icon': Icons.hourglass_top_rounded,
            'bgColor': isDark
                ? const Color(0xFF78350F).withValues(alpha: 0.45)
                : const Color(0xFFFEF3C7),
            'borderColor': isDark
                ? const Color(0xFFD97706).withValues(alpha: 0.4)
                : const Color(0xFFFDE68A),
            'textColor': isDark
                ? const Color(0xFFFBBF24)
                : const Color(0xFFD97706),
          };
        }
        final clean = status.replaceAll('_', ' ').trim();
        final short = clean.length > 10 ? '${clean.substring(0, 8)}..' : clean;
        return {
          'label': short.isNotEmpty
              ? short[0].toUpperCase() + short.substring(1).toLowerCase()
              : 'Pending',
          'shortLabel': short.isNotEmpty
              ? short[0].toUpperCase() + short.substring(1).toLowerCase()
              : 'Pending',
          'icon': Icons.hourglass_top_rounded,
          'bgColor': isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFF1F5F9),
          'borderColor': isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE2E8F0),
          'textColor': isDark
              ? AppColors.textSecondaryDark
              : const Color(0xFF475569),
        };
    }
  }

  Widget _buildPayoutPreviewItem(
    BuildContext context,
    PayoutItem po,
    bool isDark,
  ) {
    final statusConfig = _getPayoutStatusConfig(po.status, isDark);

    return InkWell(
      onTap: () => context.go('/dev/payouts'),
      borderRadius: BorderRadius.circular(18),
      child: LiquidGlass(
        borderRadius: 18,
        blur: 16,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusConfig['bgColor'] as Color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: (statusConfig['borderColor'] as Color).withValues(
                    alpha: isDark ? 0.4 : 0.6,
                  ),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Icon(
                  statusConfig['icon'] as IconData,
                  size: 17,
                  color: statusConfig['textColor'] as Color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    po.payoutNo,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    po.notes ?? DateFormatter.formatDate(po.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatRupiah(po.amount),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.emeraldDarkText
                        : AppColors.emeraldText,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7.5,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusConfig['bgColor'] as Color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusConfig['borderColor'] as Color,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4.5,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: statusConfig['textColor'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusConfig['shortLabel'] as String,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: statusConfig['textColor'] as Color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
