import 'dart:async';
import 'dart:ui';

import 'package:floafinwatch/core/constants/app_colors.dart';
import 'package:floafinwatch/core/utils/currency_formatter.dart';
import 'package:floafinwatch/core/utils/date_formatter.dart';
import 'package:floafinwatch/core/network/reverb_service.dart';
import 'package:floafinwatch/core/widgets/liquid_glass.dart';
import 'package:floafinwatch/features/developer/dashboard/data/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/payout_model.dart';
import 'payouts_skeleton.dart';

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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<PayoutItem> _payouts = [];
  int _currentPage = 1;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  int _totalPayouts = 0;
  num _totalCompletedAmount = 0;
  num _totalPendingAmount = 0;
  int _completedCount = 0;

  String _selectedStatus = 'all'; // 'all', 'completed', 'pending'
  String _selectedPeriod = 'all'; // 'all', 'today', '7d', 'month', 'prev_month', 'year', '30d', 'month_year'
  int? _selectedYear;
  int? _selectedMonth;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPayouts(reset: true);
    });
  }

  OverlayEntry? _currentToastEntry;

  @override
  void dispose() {
    if (_currentToastEntry != null && _currentToastEntry!.mounted) {
      _currentToastEntry!.remove();
    }
    _currentToastEntry = null;
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showIosTopNotification({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_currentToastEntry != null && _currentToastEntry!.mounted) {
      _currentToastEntry!.remove();
    }
    _currentToastEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _IosTopToastWidget(
        title: title,
        message: message,
        icon: icon,
        iconColor: iconColor,
        isDark: isDark,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
          }
          if (_currentToastEntry == entry) {
            _currentToastEntry = null;
          }
        },
      ),
    );

    _currentToastEntry = entry;
    overlay.insert(entry);

    Timer(duration, () {
      if (_currentToastEntry == entry) {
        if (entry.mounted) {
          entry.remove();
        }
        _currentToastEntry = null;
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (max - current <= 250) {
      if (_hasMore && !_isLoadingMore && !_isLoading) {
        _fetchPayouts(reset: false);
      }
    }
  }

  Future<void> _fetchPayouts({
    bool reset = false,
    bool isRefresh = false,
  }) async {
    if (reset) {
      if (!isRefresh) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
      _currentPage = 1;
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final repo = ref.read(dashboardRepositoryProvider);
      final pageToLoad = reset ? 1 : _currentPage + 1;

      final res = await repo.fetchPayoutsPaginated(
        page: pageToLoad,
        period: _selectedPeriod,
        year: _selectedYear,
        month: _selectedMonth,
        status: _selectedStatus,
        search: _searchQuery,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _payouts = res.items;
        } else {
          _payouts.addAll(res.items);
        }
        _currentPage = res.currentPage;
        _hasMore = res.hasMore;
        _totalPayouts = res.total;
        _totalCompletedAmount = res.totalCompletedAmount;
        _totalPendingAmount = res.totalPendingAmount;
        _completedCount = res.completedCount;
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = query;
      });
      _fetchPayouts(reset: true);
    });
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
      if (period != 'month_year' && period != 'year') {
        _selectedYear = null;
        _selectedMonth = null;
      }
    });
    _fetchPayouts(reset: true);
  }

  void _onMonthYearChanged(int year, int month) {
    setState(() {
      _selectedPeriod = 'month_year';
      _selectedYear = year;
      _selectedMonth = month;
    });
    _fetchPayouts(reset: true);
  }

  void _onYearChanged(int year) {
    setState(() {
      _selectedPeriod = 'year';
      _selectedYear = year;
      _selectedMonth = null;
    });
    _fetchPayouts(reset: true);
  }

  void _onStatusChanged(String status) {
    setState(() {
      _selectedStatus = status;
    });
    _fetchPayouts(reset: true);
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'today':
        return 'Hari Ini';
      case '7d':
        return '7 Hari';
      case '30d':
        return '30 Hari';
      case 'month':
        return 'Bulan Ini';
      case 'prev_month':
        return 'Bulan Lalu';
      case 'year':
        return _selectedYear != null ? 'Tahun $_selectedYear' : 'Tahun Ini';
      case 'month_year':
        if (_selectedYear != null && _selectedMonth != null) {
          const monthNames = [
            'Januari',
            'Februari',
            'Maret',
            'April',
            'Mei',
            'Juni',
            'Juli',
            'Agustus',
            'September',
            'Oktober',
            'November',
            'Desember',
          ];
          return '${monthNames[_selectedMonth! - 1]} $_selectedYear';
        }
        return 'Semua';
      default:
        return 'Semua';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(realtimeSyncTriggerProvider, (prev, next) {
      if (prev != next && mounted) {
        _fetchPayouts(reset: true, isRefresh: true);
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: AmbientLiquidBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _fetchPayouts(reset: true, isRefresh: true),
            color: AppColors.primary,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payouts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Riwayat pencairan dana hak developer',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Controls: Metric Cards, Quick Filter Chips, Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2 Liquid Glass Metric Cards (Equal Height matching screenshot)
                        // 2 Liquid Glass Metric Cards (Seamless, Equal Height, Proportional Typography)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Card 1: Total Payout & Pending
                              Expanded(
                                child: LiquidGlassCard(
                                  borderRadius: 16,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 11,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Total Payout',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors
                                                        .textSecondaryLight,
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 5,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? AppColors
                                                            .emeraldDarkText
                                                      : AppColors.emeraldText,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Berhasil',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? AppColors
                                                            .emeraldDarkText
                                                      : AppColors.emeraldText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        alignment: Alignment.centerLeft,
                                        fit: BoxFit.scaleDown,
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: 'Rp ',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? AppColors
                                                            .emeraldDarkText
                                                      : AppColors.emeraldText,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    CurrencyFormatter.formatRupiah(
                                                          _totalCompletedAmount,
                                                        )
                                                        .replaceFirst('Rp ', '')
                                                        .replaceFirst('Rp', '')
                                                        .trim(),
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.2,
                                                  color: isDark
                                                      ? AppColors
                                                            .emeraldDarkText
                                                      : AppColors.emeraldText,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.hourglass_top_rounded,
                                            size: 10,
                                            color: isDark
                                                ? AppColors.amberDarkText
                                                : AppColors.amberText,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: RichText(
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'Pending: ',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: isDark
                                                          ? AppColors
                                                                .textMutedDark
                                                          : AppColors
                                                                .textMutedLight,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        CurrencyFormatter.formatRupiah(
                                                          _totalPendingAmount,
                                                        ),
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          _totalPendingAmount >
                                                              0
                                                          ? (isDark
                                                                ? AppColors
                                                                      .amberDarkText
                                                                : AppColors
                                                                      .amberText)
                                                          : (isDark
                                                                ? AppColors
                                                                      .textSecondaryDark
                                                                : AppColors
                                                                      .textSecondaryLight),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Card 2: Pencairan with Period & Filter button
                              Expanded(
                                child: LiquidGlassCard(
                                  borderRadius: 16,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 11,
                                  ),
                                  onTap: () =>
                                      _showFilterSheet(context, isDark),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Pencairan',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors
                                                        .textSecondaryLight,
                                            ),
                                          ),
                                          Icon(
                                            Icons.tune_rounded,
                                            size: 14,
                                            color:
                                                (_selectedPeriod != 'all' ||
                                                    _selectedYear != null)
                                                ? AppColors.primary
                                                : (isDark
                                                      ? AppColors
                                                            .textSecondaryDark
                                                      : AppColors
                                                            .textSecondaryLight),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        alignment: Alignment.centerLeft,
                                        fit: BoxFit.scaleDown,
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: '$_completedCount',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.2,
                                                  color: isDark
                                                      ? AppColors
                                                            .textPrimaryDark
                                                      : AppColors
                                                            .textPrimaryLight,
                                                ),
                                              ),
                                              TextSpan(
                                                text: ' Kali',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark
                                                      ? AppColors
                                                            .textSecondaryDark
                                                      : AppColors
                                                            .textSecondaryLight,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 10,
                                            color:
                                                (_selectedPeriod != 'all' ||
                                                    _selectedYear != null)
                                                ? AppColors.primary
                                                : (isDark
                                                      ? AppColors.textMutedDark
                                                      : AppColors
                                                            .textMutedLight),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _getPeriodLabel(),
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight:
                                                    (_selectedPeriod != 'all' ||
                                                        _selectedYear != null)
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color:
                                                    (_selectedPeriod != 'all' ||
                                                        _selectedYear != null)
                                                    ? AppColors.primary
                                                    : (isDark
                                                          ? AppColors
                                                                .textMutedDark
                                                          : AppColors
                                                                .textMutedLight),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quick Filter Chips Bar (matching Transactions without "Jenis Layanan")
                        SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              if (_selectedPeriod == 'year' &&
                                  _selectedYear != null) ...[
                                _buildQuickChip(
                                  'Tahun $_selectedYear',
                                  true,
                                  () => _showFilterSheet(context, isDark),
                                  isDark,
                                ),
                                const SizedBox(width: 8),
                              ] else if (_selectedPeriod == 'month_year' &&
                                  _selectedYear != null &&
                                  _selectedMonth != null) ...[
                                _buildQuickChip(
                                  _getPeriodLabel(),
                                  true,
                                  () => _showFilterSheet(context, isDark),
                                  isDark,
                                ),
                                const SizedBox(width: 8),
                              ],
                              _buildQuickChip(
                                'Semua',
                                _selectedPeriod == 'all' &&
                                    _selectedStatus == 'all',
                                () {
                                  setState(() {
                                    _selectedPeriod = 'all';
                                    _selectedYear = null;
                                    _selectedMonth = null;
                                    _selectedStatus = 'all';
                                  });
                                  _fetchPayouts(reset: true);
                                },
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickChip(
                                'Hari Ini',
                                _selectedPeriod == 'today',
                                () => _onPeriodChanged('today'),
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickChip(
                                '7 Hari',
                                _selectedPeriod == '7d',
                                () => _onPeriodChanged('7d'),
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickChip(
                                'Bulan Ini',
                                _selectedPeriod == 'month',
                                () => _onPeriodChanged('month'),
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickChip(
                                'Bulan Lalu',
                                _selectedPeriod == 'prev_month',
                                () => _onPeriodChanged('prev_month'),
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickChip(
                                'Tahun Ini',
                                _selectedPeriod == 'year' &&
                                    _selectedYear == DateTime.now().year,
                                () => _onYearChanged(DateTime.now().year),
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickChip(
                                '30 Hari',
                                _selectedPeriod == '30d',
                                () => _onPeriodChanged('30d'),
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickChip(
                                'Konfirmasi',
                                _selectedStatus == 'waiting_confirmation',
                                () => _onStatusChanged(
                                  _selectedStatus == 'waiting_confirmation'
                                      ? 'all'
                                      : 'waiting_confirmation',
                                ),
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickChip(
                                'Pending',
                                _selectedStatus == 'waiting_payout',
                                () => _onStatusChanged(
                                  _selectedStatus == 'waiting_payout'
                                      ? 'all'
                                      : 'waiting_payout',
                                ),
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickChip(
                                'Selesai',
                                _selectedStatus == 'completed',
                                () => _onStatusChanged(
                                  _selectedStatus == 'completed'
                                      ? 'all'
                                      : 'completed',
                                ),
                                isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickChip(
                                'Ditolak',
                                _selectedStatus == 'rejected',
                                () => _onStatusChanged(
                                  _selectedStatus == 'rejected'
                                      ? 'all'
                                      : 'rejected',
                                ),
                                isDark,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Search Bar
                        LiquidGlass(
                          borderRadius: 14,
                          blur: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextField(
                            controller: _searchController,
                            textAlignVertical: TextAlignVertical.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                            decoration: InputDecoration(
                              filled: false,
                              fillColor: Colors.transparent,
                              isDense: true,
                              hintText: 'Cari nomor payout, catatan...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMutedLight,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                size: 19,
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMutedLight,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 42,
                                minHeight: 44,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                      ),
                                      splashRadius: 18,
                                      color: isDark
                                          ? AppColors.textMutedDark
                                          : AppColors.textMutedLight,
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                    )
                                  : null,
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 44,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Riwayat Payout Header Row
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Riwayat Payout',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$_totalPayouts Payout',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textMutedDark
                                        : AppColors.textMutedLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Payouts List / States
                if (_isLoading)
                  PayoutsListSkeleton(isDark: isDark)
                else if (_errorMessage != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 36,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Gagal memuat riwayat payout: $_errorMessage',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _fetchPayouts(reset: true),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (_payouts.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.surfaceDark
                                    : AppColors.emeraldBg,
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
                              _searchQuery.isNotEmpty
                                  ? 'Payout Tidak Ditemukan'
                                  : 'Belum Ada Riwayat Payout',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Tidak ada payout yang sesuai kata kunci "$_searchQuery".'
                                  : 'Tidak ada payout untuk filter periode yang dipilih.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMutedLight,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedPeriod = 'all';
                                  _selectedYear = null;
                                  _selectedMonth = null;
                                  _selectedStatus = 'all';
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                                _fetchPayouts(reset: true);
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Reset Filter'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index < _payouts.length) {
                          final po = _payouts[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildPayoutCard(po, isDark),
                          );
                        }

                        // Footer Pagination Area
                        if (_isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          );
                        }

                        if (_hasMore) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: TextButton.icon(
                                onPressed: () => _fetchPayouts(reset: false),
                                icon: const Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Muat Lebih Banyak',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 90),
                          child: Center(
                            child: Text(
                              'Menampilkan ${_payouts.length} riwayat payout',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMutedLight,
                              ),
                            ),
                          ),
                        );
                      }, childCount: _payouts.length + 1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    bool isDark,
  ) {
    return LiquidGlassPill(
      isSelected: isSelected,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? (isDark ? Colors.white : AppColors.primary)
              : (isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
        ),
      ),
    );
  }

  Widget _buildModalFilterChip(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onSelected,
    bool isDark, {
    Color? dotColor,
  }) {
    final isSelected = value == currentValue;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalResetButton({
    required VoidCallback onTap,
    required bool isDark,
    bool isEnabled = true,
  }) {
    final activeBg = isDark
        ? const Color(0xFF2563EB).withValues(alpha: 0.18)
        : const Color(0xFFEFF6FF);
    final activeBorder = isDark
        ? const Color(0xFF3B82F6).withValues(alpha: 0.35)
        : const Color(0xFF2563EB).withValues(alpha: 0.25);
    final activeColor = isDark
        ? const Color(0xFF60A5FA)
        : const Color(0xFF2563EB);

    final disabledBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final disabledBorder = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final disabledColor = isDark
        ? AppColors.textMutedDark.withValues(alpha: 0.45)
        : AppColors.textMutedLight.withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isEnabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isEnabled ? activeBg : disabledBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isEnabled ? activeBorder : disabledBorder,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.rotate_left_rounded,
                size: 13,
                color: isEnabled ? activeColor : disabledColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Reset',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isEnabled ? FontWeight.w700 : FontWeight.w500,
                  color: isEnabled ? activeColor : disabledColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, bool isDark) {
    final currentYear = DateTime.now().year;
    int tempYear = _selectedYear ?? currentYear;

    const monthShortNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ags',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final hasActiveFilter = _selectedPeriod != 'all' ||
                _selectedYear != null ||
                _selectedStatus != 'all';

            return LiquidGlassModalSheet(
              maxHeightRatio: 0.88,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter Payout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        _buildModalResetButton(
                          isEnabled: hasActiveFilter,
                          isDark: isDark,
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _selectedPeriod = 'all';
                              _selectedYear = null;
                              _selectedMonth = null;
                              _selectedStatus = 'all';
                            });
                            _fetchPayouts(reset: true);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 1. Status Payout Filter
                    Text(
                      'Status Payout',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildModalFilterChip(
                          'Semua',
                          'all',
                          _selectedStatus,
                          (val) {
                            Navigator.pop(ctx);
                            _onStatusChanged(val);
                          },
                          isDark,
                        ),
                        _buildModalFilterChip(
                          'Konfirmasi',
                          'waiting_confirmation',
                          _selectedStatus,
                          (val) {
                            Navigator.pop(ctx);
                            _onStatusChanged(val);
                          },
                          isDark,
                          dotColor: isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB),
                        ),
                        _buildModalFilterChip(
                          'Pending',
                          'waiting_payout',
                          _selectedStatus,
                          (val) {
                            Navigator.pop(ctx);
                            _onStatusChanged(val);
                          },
                          isDark,
                          dotColor: isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706),
                        ),
                        _buildModalFilterChip(
                          'Selesai',
                          'completed',
                          _selectedStatus,
                          (val) {
                            Navigator.pop(ctx);
                            _onStatusChanged(val);
                          },
                          isDark,
                          dotColor: isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF15803D),
                        ),
                        _buildModalFilterChip(
                          'Ditolak',
                          'rejected',
                          _selectedStatus,
                          (val) {
                            Navigator.pop(ctx);
                            _onStatusChanged(val);
                          },
                          isDark,
                          dotColor: isDark
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFB91C1C),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 2. Preset Periode
                    Text(
                      'Preset Periode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildModalFilterChip(
                          'Semua Waktu',
                          'all',
                          _selectedPeriod == 'month_year'
                              ? ''
                              : _selectedPeriod,
                          (val) {
                            Navigator.pop(ctx);
                            _onPeriodChanged(val);
                          },
                          isDark,
                        ),
                        _buildModalFilterChip(
                          'Hari Ini',
                          'today',
                          _selectedPeriod == 'month_year'
                              ? ''
                              : _selectedPeriod,
                          (val) {
                            Navigator.pop(ctx);
                            _onPeriodChanged(val);
                          },
                          isDark,
                        ),
                        _buildModalFilterChip(
                          '7 Hari Terakhir',
                          '7d',
                          _selectedPeriod == 'month_year'
                              ? ''
                              : _selectedPeriod,
                          (val) {
                            Navigator.pop(ctx);
                            _onPeriodChanged(val);
                          },
                          isDark,
                        ),
                        _buildModalFilterChip(
                          'Bulan Ini',
                          'month',
                          _selectedPeriod == 'month_year'
                              ? ''
                              : _selectedPeriod,
                          (val) {
                            Navigator.pop(ctx);
                            _onPeriodChanged(val);
                          },
                          isDark,
                        ),
                        _buildModalFilterChip(
                          'Bulan Lalu',
                          'prev_month',
                          _selectedPeriod == 'month_year'
                              ? ''
                              : _selectedPeriod,
                          (val) {
                            Navigator.pop(ctx);
                            _onPeriodChanged(val);
                          },
                          isDark,
                        ),
                        _buildModalFilterChip(
                          '30 Hari Terakhir',
                          '30d',
                          _selectedPeriod == 'month_year'
                              ? ''
                              : _selectedPeriod,
                          (val) {
                            Navigator.pop(ctx);
                            _onPeriodChanged(val);
                          },
                          isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 2. Kalender Periode (Matching Transactions Modal identically)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Calendar Header Navigation (< 2026 >)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kalender Periode',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ],
                              ),
                              // Year Navigation Controls
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : Colors.black.withValues(alpha: 0.08),
                                    width: 0.85,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        setModalState(() => tempYear--);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        child: Icon(
                                          Icons.chevron_left_rounded,
                                          size: 20,
                                          color: isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        '$tempYear',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: tempYear < DateTime.now().year + 1
                                          ? () {
                                              setModalState(() => tempYear++);
                                            }
                                          : null,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        child: Icon(
                                          Icons.chevron_right_rounded,
                                          size: 20,
                                          color:
                                              tempYear < DateTime.now().year + 1
                                              ? (isDark
                                                    ? AppColors.textPrimaryDark
                                                    : AppColors
                                                          .textPrimaryLight)
                                              : (isDark
                                                    ? Colors.white24
                                                    : Colors.black26),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Option: Filter Pertahunan (1 Tahun Penuh)
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.pop(ctx);
                              _onYearChanged(tempYear);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 9,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (_selectedPeriod == 'year' &&
                                        _selectedYear == tempYear)
                                    ? AppColors.primary
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.white),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      (_selectedPeriod == 'year' &&
                                          _selectedYear == tempYear)
                                      ? AppColors.primary
                                      : (isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.1,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.08,
                                              )),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.date_range_rounded,
                                    size: 15,
                                    color:
                                        (_selectedPeriod == 'year' &&
                                            _selectedYear == tempYear)
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Filter Sepanjang Tahun $tempYear (Semua Bulan)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          (_selectedPeriod == 'year' &&
                                              _selectedYear == tempYear)
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color:
                                          (_selectedPeriod == 'year' &&
                                              _selectedYear == tempYear)
                                          ? Colors.white
                                          : (isDark
                                                ? AppColors.textPrimaryDark
                                                : AppColors.textPrimaryLight),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 12 Months Calendar Grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  childAspectRatio: 2.1,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: 12,
                            itemBuilder: (context, idx) {
                              final monthNum = idx + 1;
                              final isSelected =
                                  _selectedPeriod == 'month_year' &&
                                  _selectedYear == tempYear &&
                                  _selectedMonth == monthNum;
                              final isCurrentMonth =
                                  tempYear == DateTime.now().year &&
                                  monthNum == DateTime.now().month;

                              return InkWell(
                                borderRadius: BorderRadius.circular(9),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _onMonthYearChanged(tempYear, monthNum);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.05,
                                                )
                                              : Colors.white),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isCurrentMonth
                                                ? AppColors.primary.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : (isDark
                                                      ? Colors.white.withValues(
                                                          alpha: 0.08,
                                                        )
                                                      : Colors.black.withValues(
                                                          alpha: 0.08,
                                                        ))),
                                      width: isCurrentMonth ? 1.2 : 0.9,
                                    ),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          monthShortNames[idx],
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : (isDark
                                                      ? AppColors
                                                            .textPrimaryDark
                                                      : AppColors
                                                            .textPrimaryLight),
                                          ),
                                        ),
                                        if (isCurrentMonth && !isSelected) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            width: 5,
                                            height: 5,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _getStatusConfig(String status, bool isDark) {
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

  Future<void> _confirmPayoutAction(PayoutItem po) async {
    BuildContext? dialogContext;
    try {
      showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dCtx) {
          dialogContext = dCtx;
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        },
      );

      final repo = ref.read(dashboardRepositoryProvider);
      final success = await repo.confirmPayout(po.id);

      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      } else if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;

      if (success) {
        _showIosTopNotification(
          title: 'Konfirmasi Berhasil',
          message: 'Payout ${po.payoutNo} telah berhasil dikonfirmasi!',
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF2563EB),
        );
        _fetchPayouts(reset: true);
      }
    } catch (e) {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      } else if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      _showIosTopNotification(
        title: 'Gagal Konfirmasi',
        message: '$e',
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFB91C1C),
      );
    }
  }

  Future<void> _rejectPayoutAction(PayoutItem po, String reason) async {
    BuildContext? dialogContext;
    try {
      showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dCtx) {
          dialogContext = dCtx;
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        },
      );

      final repo = ref.read(dashboardRepositoryProvider);
      final success = await repo.rejectPayout(po.id, reason);

      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      } else if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;

      if (success) {
        _showIosTopNotification(
          title: 'Laporan Penolakan Terkirim',
          message: 'Laporan penolakan payout ${po.payoutNo} telah terkirim.',
          icon: Icons.cancel_outlined,
          iconColor: const Color(0xFFB91C1C),
        );
        _fetchPayouts(reset: true);
      }
    } catch (e) {
      if (dialogContext != null && dialogContext!.mounted) {
        Navigator.of(dialogContext!).pop();
      } else if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!mounted) return;
      _showIosTopNotification(
        title: 'Gagal Mengirim Laporan',
        message: '$e',
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFB91C1C),
      );
    }
  }

  void _showConfirmDialog(PayoutItem po, bool isDark) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return LiquidGlassModalSheet(
          maxHeightRatio: 0.7,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 30,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Konfirmasi Penerimaan Dana',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'Apakah Anda yakin telah menerima transfer dana sebesar ${CurrencyFormatter.formatRupiah(po.amount)} ke rekening Anda?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Batal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(ctx);
                          _confirmPayoutAction(po);
                        },
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Ya, Dana Diterima',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRejectDialog(PayoutItem po, bool isDark) {
    final reasonController = TextEditingController();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: LiquidGlassModalSheet(
            maxHeightRatio: 0.85,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFB91C1C).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFB91C1C)
                                .withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.report_problem_rounded,
                            size: 19,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Laporkan Masalah Payout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dana akan dikembalikan ke saldo tertunda.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  RichText(
                    text: TextSpan(
                      text: 'Alasan Penolakan / Masalah',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      children: const [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: reasonController,
                      maxLines: 3,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Mutasi rekening belum masuk setelah dicek, mohon verifikasi kembali...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMutedLight,
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Batal',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            final reason = reasonController.text.trim();
                            if (reason.isEmpty) {
                              _showIosTopNotification(
                                title: 'Perhatian',
                                message: 'Alasan penolakan wajib diisi.',
                                icon: Icons.info_outline_rounded,
                                iconColor: const Color(0xFFD97706),
                              );
                              return;
                            }
                            Navigator.pop(ctx);
                            _rejectPayoutAction(po, reason);
                          },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFB91C1C)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Kirim Laporan',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPayoutDetailModal(PayoutItem po, bool isDark) {
    final statusConfig = _getStatusConfig(po.status, isDark);
    final canTakeAction = po.status == 'waiting_confirmation';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return LiquidGlassModalSheet(
          maxHeightRatio: 0.9,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Title (No X icon - pure iOS style)
                Text(
                  'Kuitansi Payout',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 14),

                // TOP RECEIPT HEADER CARD (Liquid Glass Receipt)
                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'BUKTI MUTASI PEMBAYARAN DEVELOPER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        po.payoutNo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CurrencyFormatter.formatRupiah(po.amount),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
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
                              width: 5.5,
                              height: 5.5,
                              decoration: BoxDecoration(
                                color: statusConfig['textColor'] as Color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              statusConfig['shortLabel'] as String,
                              style: TextStyle(
                                fontSize: 11,
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
                ),
                const SizedBox(height: 12),

                // DETAILS CARD (Liquid Glass Details)
                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'Waktu Pencairan:',
                        po.createdAt != null
                            ? DateFormatter.formatFullDateTime(po.createdAt!)
                            : '-',
                        isDark,
                      ),
                      _buildDetailDivider(isDark),
                      _buildDetailRow(
                        'No. Referensi:',
                        po.referenceNo?.isNotEmpty == true
                            ? po.referenceNo!
                            : '-',
                        isDark,
                        isHighlight: po.referenceNo?.isNotEmpty == true,
                      ),
                      _buildDetailDivider(isDark),
                      _buildDetailRow(
                        'Catatan / Periode:',
                        po.notes?.isNotEmpty == true
                            ? po.notes!
                            : 'Payout Otomatis Hak Developer',
                        isDark,
                      ),
                      if ((po.status == 'rejected' ||
                              po.status == 'failed') &&
                          po.rejectionReason != null &&
                          po.rejectionReason!.isNotEmpty) ...[
                        _buildDetailDivider(isDark),
                        _buildDetailRow(
                          'Alasan Penolakan:',
                          po.rejectionReason!,
                          isDark,
                          isError: true,
                        ),
                      ],
                    ],
                  ),
                ),

                // Information notice if waiting for admin payout
                if (po.status == 'waiting_payout') ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF78350F).withValues(alpha: 0.25)
                          : const Color(0xFFFEF3C7).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFFD97706).withValues(alpha: 0.35)
                            : const Color(0xFFFDE68A),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.hourglass_top_rounded,
                          size: 18,
                          color: isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Menunggu admin jurnal memproses dan mentransfer dana ke rekening Anda.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Actions if waiting confirmation (Admin has transferred, Dev confirms)
                if (canTakeAction) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showRejectDialog(po, isDark);
                          },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF7F1D1D)
                                      .withValues(alpha: 0.2)
                                  : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF991B1B)
                                        .withValues(alpha: 0.45)
                                    : const Color(0xFFFECACA),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Tolak / Belum Masuk',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showConfirmDialog(po, isDark);
                          },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Konfirmasi Diterima',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    bool isHighlight = false,
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark
                  ? AppColors.textMutedDark
                  : AppColors.textMutedLight,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: isHighlight ? 'monospace' : null,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isError
                    ? const Color(0xFFEF4444)
                    : isHighlight
                    ? const Color(0xFF2563EB)
                    : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailDivider(bool isDark) {
    return Divider(
      height: 14,
      thickness: 0.7,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.05),
    );
  }

  Widget _buildPayoutCard(PayoutItem po, bool isDark) {
    final statusConfig = _getStatusConfig(po.status, isDark);
    final canTakeAction = po.status == 'waiting_confirmation';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showPayoutDetailModal(po, isDark),
        child: LiquidGlassCard(
          borderRadius: 18,
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

                  // Payout Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          po.payoutNo,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          po.notes ?? 'Payout otomatis hak developer',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Amount & Status Badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.formatRupiah(po.amount),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.emeraldDarkText
                              : AppColors.emeraldText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
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
                                fontSize: 10,
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

              if (po.createdAt != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tanggal Pencairan',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMutedLight,
                        ),
                      ),
                      Text(
                        DateFormatter.formatDate(po.createdAt!),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Quick Action Bar on Card if Waiting Action
              if (canTakeAction) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showRejectDialog(po, isDark),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF7F1D1D).withValues(alpha: 0.2)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF991B1B).withValues(alpha: 0.45)
                                : const Color(0xFFFECACA),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              size: 13,
                              color: isDark
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFB91C1C),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tolak',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showConfirmDialog(po, isDark),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB)
                                  .withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Konfirmasi',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IosTopToastWidget extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final VoidCallback onDismiss;

  const _IosTopToastWidget({
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.onDismiss,
  });

  @override
  State<_IosTopToastWidget> createState() => _IosTopToastWidgetState();
}

class _IosTopToastWidgetState extends State<_IosTopToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.65),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    ));

    _controller.forward();
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    if (mounted) {
      await _controller.reverse();
    }
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
              _dismiss();
            }
          },
          onTap: _dismiss,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.88)
                          : Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: widget.isDark ? 0.35 : 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: widget.iconColor.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.iconColor.withValues(alpha: 0.28),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              widget.icon,
                              size: 20,
                              color: widget.iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: widget.isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.message,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.3,
                                  color: widget.isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
