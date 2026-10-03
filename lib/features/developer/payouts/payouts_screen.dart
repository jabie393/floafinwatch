import 'package:floafinwatch/core/constants/app_colors.dart';
import 'package:floafinwatch/core/utils/currency_formatter.dart';
import 'package:floafinwatch/core/utils/date_formatter.dart';
import 'package:floafinwatch/core/widgets/liquid_glass.dart';
import 'package:floafinwatch/features/developer/dashboard/data/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain/payout_model.dart';

final payoutsProvider = FutureProvider<List<PayoutItem>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchPayouts();
});

class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> {
  String _selectedFilter = 'all'; // 'all', 'completed', 'pending'

  @override
  Widget build(BuildContext context) {
    final payoutsAsync = ref.watch(payoutsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: AmbientLiquidBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(payoutsProvider.future),
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payouts',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Riwayat pencairan dana hak developer',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content
                payoutsAsync.when(
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                            const SizedBox(height: 12),
                            Text(
                              'Gagal memuat riwayat payout: $err',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref.refresh(payoutsProvider),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  data: (payouts) {
                    final completedPayouts = payouts.where((po) => po.status == 'confirmed' || po.status == 'completed').toList();
                    final pendingPayouts = payouts.where((po) => po.status != 'confirmed' && po.status != 'completed').toList();

                    final totalCompletedAmount = completedPayouts.fold<num>(0, (sum, po) => sum + po.amount);
                    final totalPendingAmount = pendingPayouts.fold<num>(0, (sum, po) => sum + po.amount);

                    final filteredPayouts = _selectedFilter == 'all'
                        ? payouts
                        : (_selectedFilter == 'completed' ? completedPayouts : pendingPayouts);

                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 3 Liquid Glass Metric Cards
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricMiniCard(
                                    title: 'Total Payout',
                                    value: CurrencyFormatter.formatRupiah(totalCompletedAmount),
                                    isDark: isDark,
                                    isEmerald: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MetricMiniCard(
                                    title: 'Pending',
                                    value: CurrencyFormatter.formatRupiah(totalPendingAmount),
                                    isDark: isDark,
                                    isAmber: totalPendingAmount > 0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MetricMiniCard(
                                    title: 'Pencairan',
                                    value: '${completedPayouts.length} Kali',
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Liquid Glass Filter Pills
                            Row(
                              children: [
                                LiquidGlassPill(
                                  isSelected: _selectedFilter == 'all',
                                  onTap: () {
                                    setState(() {
                                      _selectedFilter = 'all';
                                    });
                                  },
                                  child: Text(
                                    'Semua (${payouts.length})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _selectedFilter == 'all' ? FontWeight.w700 : FontWeight.w500,
                                      color: _selectedFilter == 'all'
                                          ? (isDark ? Colors.white : AppColors.primary)
                                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                LiquidGlassPill(
                                  isSelected: _selectedFilter == 'completed',
                                  onTap: () {
                                    setState(() {
                                      _selectedFilter = 'completed';
                                    });
                                  },
                                  child: Text(
                                    'Berhasil (${completedPayouts.length})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _selectedFilter == 'completed' ? FontWeight.w700 : FontWeight.w500,
                                      color: _selectedFilter == 'completed'
                                          ? (isDark ? Colors.white : AppColors.primary)
                                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                LiquidGlassPill(
                                  isSelected: _selectedFilter == 'pending',
                                  onTap: () {
                                    setState(() {
                                      _selectedFilter = 'pending';
                                    });
                                  },
                                  child: Text(
                                    'Pending (${pendingPayouts.length})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _selectedFilter == 'pending' ? FontWeight.w700 : FontWeight.w500,
                                      color: _selectedFilter == 'pending'
                                          ? (isDark ? Colors.white : AppColors.primary)
                                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Payouts List
                            if (filteredPayouts.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.surfaceDark : AppColors.emeraldBg,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.payments_rounded,
                                          color: AppColors.emeraldText,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Belum Ada Riwayat Payout',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Pencairan dana hak developer akan dicatat di sini.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredPayouts.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final po = filteredPayouts[index];
                                  return _buildPayoutCard(po, isDark);
                                },
                              ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPayoutCard(PayoutItem po, bool isDark) {
    final isCompleted = po.status == 'confirmed' || po.status == 'completed';

    return LiquidGlass(
      borderRadius: 18,
      blur: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Liquid Bubble Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? (isDark ? const Color(0xFF064E3B) : AppColors.emeraldBg)
                      : (isDark ? const Color(0xFF78350F) : AppColors.amberBg),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.8),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isCompleted ? Icons.check_circle_rounded : Icons.pending_rounded,
                    size: 18,
                    color: isCompleted
                        ? (isDark ? AppColors.emeraldDarkText : AppColors.emeraldText)
                        : (isDark ? AppColors.amberDarkText : AppColors.amberText),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (po.notes != null && po.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        po.notes!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isCompleted
                          ? (isDark ? AppColors.emeraldDarkText : AppColors.emeraldText)
                          : (isDark ? AppColors.amberDarkText : AppColors.amberText),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? (isDark ? const Color(0xFF064E3B) : AppColors.emeraldBg)
                          : (isDark ? const Color(0xFF78350F) : AppColors.amberBg),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCompleted ? 'Berhasil' : 'Menunggu Payout',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isCompleted
                            ? (isDark ? AppColors.emeraldDarkText : AppColors.emeraldText)
                            : (isDark ? AppColors.amberDarkText : AppColors.amberText),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tanggal Pencairan',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                Text(
                  DateFormatter.formatDate(po.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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

class _MetricMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final bool isDark;
  final bool isEmerald;
  final bool isAmber;

  const _MetricMiniCard({
    required this.title,
    required this.value,
    required this.isDark,
    this.isEmerald = false,
    this.isAmber = false,
  });

  @override
  Widget build(BuildContext context) {
    Color valueColor;
    if (isEmerald) {
      valueColor = isDark ? AppColors.emeraldDarkText : AppColors.emeraldText;
    } else if (isAmber) {
      valueColor = isDark ? AppColors.amberDarkText : AppColors.amberText;
    } else {
      valueColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    }

    return LiquidGlass(
      borderRadius: 14,
      blur: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
