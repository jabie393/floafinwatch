import 'dart:async';
import 'package:floafinwatch/core/constants/app_colors.dart';
import 'package:floafinwatch/core/utils/currency_formatter.dart';
import 'package:floafinwatch/core/utils/date_formatter.dart';
import 'package:floafinwatch/core/widgets/liquid_glass.dart';
import 'package:floafinwatch/features/developer/dashboard/data/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/transaction_model.dart';

final transactionsProvider = FutureProvider<List<TransactionItem>>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchTransactions();
});

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<TransactionItem> _transactions = [];
  int _currentPage = 1;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  int _totalTransactions = 0;

  String _selectedPeriod = 'all'; // 'all', 'today', '7d', 'month', 'prev_month', '30d', 'month_year'
  int? _selectedYear;
  int? _selectedMonth;

  String _selectedType = 'all'; // 'all', 'submission', 'bulk_submission', 'doi_addon', 'ganti_pdf'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTransactions(reset: true);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (max - current <= 250) {
      if (_hasMore && !_isLoadingMore && !_isLoading) {
        _fetchTransactions(reset: false);
      }
    }
  }

  Future<void> _fetchTransactions({bool reset = false, bool isRefresh = false}) async {
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

      final res = await repo.fetchTransactionsPaginated(
        page: pageToLoad,
        period: _selectedPeriod,
        year: _selectedYear,
        month: _selectedMonth,
        type: _selectedType,
        search: _searchQuery,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _transactions = res.items;
        } else {
          _transactions.addAll(res.items);
        }
        _currentPage = res.currentPage;
        _hasMore = res.hasMore;
        _totalTransactions = res.total;
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (reset) {
          _errorMessage = e.toString();
        }
      });
    }
  }

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchTransactions(reset: true);
    });
  }

  List<TransactionItem> get _filteredTransactions {
    final query = _searchQuery.trim().toLowerCase();
    return _transactions.where((tx) {
      // 1. Search Query Filter
      if (query.isNotEmpty) {
        final orderId = tx.orderId.toLowerCase();
        final invoice = tx.orderNumber.toLowerCase();
        final payer = tx.payerName.toLowerCase();
        final service = tx.serviceName.toLowerCase();
        final journal = tx.journalName.toLowerCase();
        final matches = orderId.contains(query) ||
            invoice.contains(query) ||
            payer.contains(query) ||
            service.contains(query) ||
            journal.contains(query);
        if (!matches) return false;
      }

      // 2. Type Filter
      if (_selectedType != 'all') {
        if (_selectedType == 'bulk_submission') {
          final isBulk = tx.isBulk ||
              tx.type.toLowerCase().contains('bulk') ||
              tx.serviceName.toLowerCase().contains('kolektif');
          if (!isBulk) return false;
        } else if (_selectedType == 'doi_addon') {
          final isDoi = tx.type.toLowerCase().contains('doi') ||
              tx.serviceName.toLowerCase().contains('doi');
          if (!isDoi) return false;
        } else if (_selectedType == 'ganti_pdf' || _selectedType == 'replace_pdf') {
          final isGantiPdf = tx.type.toLowerCase().contains('pdf') ||
              tx.serviceName.toLowerCase().contains('pdf');
          if (!isGantiPdf) return false;
        } else if (_selectedType == 'submission') {
          final isSub = tx.type.toLowerCase().contains('submission') ||
              tx.serviceName.toLowerCase().contains('naskah') ||
              tx.serviceName.toLowerCase().contains('publikasi');
          if (!isSub) return false;
        } else if (tx.type != _selectedType) {
          return false;
        }
      }

      // 3. Period Filter
      if (_selectedPeriod != 'all') {
        final rawDate = tx.paidAt ?? tx.createdAt;
        if (rawDate == null) return false;
        final date = rawDate.toLocal();
        final now = DateTime.now();

        if (_selectedPeriod == 'year' && _selectedYear != null) {
          if (date.year != _selectedYear) return false;
        } else if (_selectedPeriod == 'month_year' && _selectedYear != null && _selectedMonth != null) {
          if (date.year != _selectedYear || date.month != _selectedMonth) return false;
        } else if (_selectedPeriod == 'today') {
          if (date.year != now.year || date.month != now.month || date.day != now.day) return false;
        } else if (_selectedPeriod == '7d') {
          final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
          if (date.isBefore(sevenDaysAgo)) return false;
        } else if (_selectedPeriod == 'month') {
          if (date.year != now.year || date.month != now.month) return false;
        } else if (_selectedPeriod == 'prev_month') {
          final prevYear = now.month == 1 ? now.year - 1 : now.year;
          final prevMonth = now.month == 1 ? 12 : now.month - 1;
          if (date.year != prevYear || date.month != prevMonth) return false;
        } else if (_selectedPeriod == '30d') {
          final thirtyDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
          if (date.isBefore(thirtyDaysAgo)) return false;
        }
      }

      return true;
    }).toList();
  }


  int get _displayTotalTransactions {
    if (_searchQuery.trim().isNotEmpty) {
      if (_totalTransactions > 0 && _filteredTransactions.length == _transactions.length) {
        return _totalTransactions;
      }
      return _filteredTransactions.length;
    }
    return _totalTransactions > 0 ? _totalTransactions : _filteredTransactions.length;
  }


  void _onPeriodChanged(String period) {
    if (_selectedPeriod == period && _selectedYear == null && _selectedMonth == null) return;
    setState(() {
      _selectedPeriod = period;
      _selectedYear = null;
      _selectedMonth = null;
    });
    _fetchTransactions(reset: true);
  }

  void _onMonthYearChanged(int year, int month) {
    setState(() {
      _selectedPeriod = 'month_year';
      _selectedYear = year;
      _selectedMonth = month;
    });
    _fetchTransactions(reset: true);
  }

  void _onYearChanged(int year) {
    setState(() {
      _selectedPeriod = 'year';
      _selectedYear = year;
      _selectedMonth = null;
    });
    _fetchTransactions(reset: true);
  }

  void _onTypeChanged(String type) {
    if (_selectedType == type) return;
    setState(() => _selectedType = type);
    _fetchTransactions(reset: true);
  }

  String _getPeriodLabel() {
    if (_selectedPeriod == 'year' && _selectedYear != null) {
      return 'Tahun $_selectedYear';
    }
    if (_selectedPeriod == 'month_year' && _selectedYear != null && _selectedMonth != null) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final mIndex = (_selectedMonth! - 1).clamp(0, 11);
      return '${months[mIndex]} $_selectedYear';
    }
    switch (_selectedPeriod) {
      case 'today':
        return 'Hari Ini';
      case '7d':
        return '7 Hari';
      case 'month':
        return 'Bulan Ini';
      case 'prev_month':
        return 'Bulan Lalu';
      case '30d':
        return '30 Hari';
      case 'all':
      default:
        return 'Semua';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayedTransactions = _filteredTransactions;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: AmbientLiquidBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
              await _fetchTransactions(reset: true, isRefresh: true);
            },
            color: AppColors.primary,
            child: CustomScrollView(
              controller: _scrollController,
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
                                'Riwayat Transaksi Hak Dev',
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
                                'Penerimaan hak bagi hasil developer dari LOA',
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
                      ],
                    ),
                  ),
                ),

                // Controls & Metric Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2 Liquid Glass Metric Cards (Total Transaksi & Periode)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _MetricMiniCard(
                                  title: 'Total Transaksi',
                                  value: '$_displayTotalTransactions Transaksi',
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricMiniCard(
                                  title: 'Periode',
                                  value: _getPeriodLabel(),
                                  isDark: isDark,
                                  trailingIcon: Icons.tune_rounded,
                                  isActive: (_selectedPeriod != 'all' || _selectedYear != null || _selectedMonth != null || _selectedType != 'all'),
                                  onTap: () => _showFilterSheet(context, isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quick Filter Chips Bar (LiquidGlassPill Style matching Payouts)
                        SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              if (_selectedPeriod == 'year' && _selectedYear != null) ...[
                                _buildQuickChip('Tahun $_selectedYear', true, () => _showFilterSheet(context, isDark), isDark),
                                const SizedBox(width: 8),
                              ] else if (_selectedPeriod == 'month_year' && _selectedYear != null && _selectedMonth != null) ...[
                                _buildQuickChip(_getPeriodLabel(), true, () => _showFilterSheet(context, isDark), isDark),
                                const SizedBox(width: 8),
                              ],
                              _buildQuickChip('Semua', _selectedPeriod == 'all' && _selectedType == 'all', () {
                                setState(() {
                                  _selectedPeriod = 'all';
                                  _selectedYear = null;
                                  _selectedMonth = null;
                                  _selectedType = 'all';
                                });
                                _fetchTransactions(reset: true);
                              }, isDark),
                              const SizedBox(width: 8),
                              _buildQuickChip('Hari Ini', _selectedPeriod == 'today', () => _onPeriodChanged('today'), isDark),
                              const SizedBox(width: 8),
                              _buildQuickChip('7 Hari', _selectedPeriod == '7d', () => _onPeriodChanged('7d'), isDark),
                              const SizedBox(width: 8),
                              _buildQuickChip('Bulan Ini', _selectedPeriod == 'month', () => _onPeriodChanged('month'), isDark),
                              const SizedBox(width: 8),
                              _buildQuickChip('Bulan Lalu', _selectedPeriod == 'prev_month', () => _onPeriodChanged('prev_month'), isDark),
                              const SizedBox(width: 8),
                              _buildQuickChip('Tahun Ini', _selectedPeriod == 'year' && _selectedYear == DateTime.now().year, () => _onYearChanged(DateTime.now().year), isDark),
                              const SizedBox(width: 8),
                              _buildQuickChip('30 Hari', _selectedPeriod == '30d', () => _onPeriodChanged('30d'), isDark),
                              const SizedBox(width: 8),
                              _buildQuickChip('Kolektif', _selectedType == 'bulk_submission', () => _onTypeChanged(_selectedType == 'bulk_submission' ? 'all' : 'bulk_submission'), isDark),
                              const SizedBox(width: 8),
                              _buildQuickChip('DOI', _selectedType == 'doi_addon', () => _onTypeChanged(_selectedType == 'doi_addon' ? 'all' : 'doi_addon'), isDark),
                              const SizedBox(width: 8),
                              _buildQuickChip('Ganti PDF', _selectedType == 'replace_pdf' || _selectedType == 'ganti_pdf', () => _onTypeChanged((_selectedType == 'replace_pdf' || _selectedType == 'ganti_pdf') ? 'all' : 'replace_pdf'), isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Liquid Glass Search Bar with Perfectly Symmetrical Vertical Centering
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
                              hintText: 'Cari transaksi, invoice, pembayar...',
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
                                      icon: const Icon(Icons.close_rounded, size: 16),
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
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),

                // Transactions List or States
                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
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
                              'Gagal memuat transaksi: $_errorMessage',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _fetchTransactions(reset: true),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (displayedTransactions.isEmpty)
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
                                    : AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_rounded,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Transaksi Tidak Ditemukan'
                                  : 'Belum Ada Transaksi',
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
                                  ? 'Tidak ada transaksi yang sesuai kata kunci "$_searchQuery".'
                                  : 'Tidak ada transaksi untuk filter periode yang dipilih.',
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
                                  _selectedType = 'all';
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                                _fetchTransactions(reset: true);
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Reset Filter'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index < displayedTransactions.length) {
                            final tx = displayedTransactions[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildTransactionCard(tx, isDark),
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
                                  onPressed: () => _fetchTransactions(reset: false),
                                  icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                                  label: const Text('Muat Lebih Banyak', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                ),
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'Menampilkan ${displayedTransactions.length} transaksi',
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
                        },
                        childCount: displayedTransactions.length + 1,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, bool isSelected, VoidCallback onTap, bool isDark) {
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
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
      ),
    );
  }

  Widget _buildModalFilterChip(String label, String value, String currentValue, ValueChanged<String> onSelected, bool isDark) {
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
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, bool isDark) {
    final currentYear = DateTime.now().year;
    int tempYear = _selectedYear ?? currentYear;

    const monthShortNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                            'Filter Transaksi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          if (_selectedPeriod != 'all' || _selectedType != 'all' || _selectedYear != null)
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedPeriod = 'all';
                                  _selectedYear = null;
                                  _selectedMonth = null;
                                  _selectedType = 'all';
                                });
                                _fetchTransactions(reset: true);
                              },
                              child: const Text('Reset', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 1. Preset Cepat
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
                          _buildModalFilterChip('Semua Waktu', 'all', _selectedPeriod == 'month_year' ? '' : _selectedPeriod, (val) {
                            Navigator.pop(ctx);
                            _onPeriodChanged(val);
                          }, isDark),
                          _buildModalFilterChip('Hari Ini', 'today', _selectedPeriod == 'month_year' ? '' : _selectedPeriod, (val) {
                            Navigator.pop(ctx);
                            _onPeriodChanged(val);
                          }, isDark),
                          _buildModalFilterChip('7 Hari Terakhir', '7d', _selectedPeriod == 'month_year' ? '' : _selectedPeriod, (val) {
                            Navigator.pop(ctx);
                            _onPeriodChanged(val);
                          }, isDark),
                          _buildModalFilterChip('Bulan Ini', 'month', _selectedPeriod == 'month_year' ? '' : _selectedPeriod, (val) {
                            Navigator.pop(ctx);
                            _onPeriodChanged(val);
                          }, isDark),
                          _buildModalFilterChip('Bulan Lalu', 'prev_month', _selectedPeriod == 'month_year' ? '' : _selectedPeriod, (val) {
                            Navigator.pop(ctx);
                            _onPeriodChanged(val);
                          }, isDark),
                          _buildModalFilterChip('30 Hari Terakhir', '30d', _selectedPeriod == 'month_year' ? '' : _selectedPeriod, (val) {
                            Navigator.pop(ctx);
                            _onPeriodChanged(val);
                          }, isDark),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 2. Kalender Bulan & Tahun (Real Calendar Style Picker)
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
                                    Icon(
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
                                        color: Colors.black.withValues(alpha: 0.04),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          child: Icon(
                                            Icons.chevron_right_rounded,
                                            size: 20,
                                            color: tempYear < DateTime.now().year + 1
                                                ? (isDark
                                                    ? AppColors.textPrimaryDark
                                                    : AppColors.textPrimaryLight)
                                                : (isDark ? Colors.white24 : Colors.black26),
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
                                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: (_selectedPeriod == 'year' && _selectedYear == tempYear)
                                      ? AppColors.primary
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.white),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (_selectedPeriod == 'year' && _selectedYear == tempYear)
                                        ? AppColors.primary
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : Colors.black.withValues(alpha: 0.08)),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.date_range_rounded,
                                      size: 15,
                                      color: (_selectedPeriod == 'year' && _selectedYear == tempYear)
                                          ? Colors.white
                                          : AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Filter Sepanjang Tahun $tempYear (Semua Bulan)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: (_selectedPeriod == 'year' && _selectedYear == tempYear)
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: (_selectedPeriod == 'year' && _selectedYear == tempYear)
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
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 2.1,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: 12,
                              itemBuilder: (context, idx) {
                                final monthNum = idx + 1;
                                final isSelected = _selectedPeriod == 'month_year' &&
                                    _selectedYear == tempYear &&
                                    _selectedMonth == monthNum;
                                final isCurrentMonth = tempYear == DateTime.now().year &&
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
                                              ? Colors.white.withValues(alpha: 0.05)
                                              : Colors.white),
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isCurrentMonth
                                                ? AppColors.primary.withValues(alpha: 0.5)
                                                : (isDark
                                                    ? Colors.white.withValues(alpha: 0.08)
                                                    : Colors.black.withValues(alpha: 0.08))),
                                        width: isCurrentMonth ? 1.2 : 0.9,
                                      ),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            monthShortNames[idx],
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.white
                                                  : (isDark
                                                      ? AppColors.textPrimaryDark
                                                      : AppColors.textPrimaryLight),
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
                      const SizedBox(height: 18),

                      // 3. Jenis Layanan Filter
                      Text(
                        'Jenis Layanan',
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
                          _buildModalFilterChip('Semua Layanan', 'all', _selectedType, (val) {
                            Navigator.pop(ctx);
                            _onTypeChanged(val);
                          }, isDark),
                          _buildModalFilterChip('Publikasi Naskah', 'submission', _selectedType, (val) {
                            Navigator.pop(ctx);
                            _onTypeChanged(val);
                          }, isDark),
                          _buildModalFilterChip('Publikasi Kolektif', 'bulk_submission', _selectedType, (val) {
                            Navigator.pop(ctx);
                            _onTypeChanged(val);
                          }, isDark),
                          _buildModalFilterChip('Tambah DOI', 'doi_addon', _selectedType, (val) {
                            Navigator.pop(ctx);
                            _onTypeChanged(val);
                          }, isDark),
                          _buildModalFilterChip('Ganti PDF', 'replace_pdf', (_selectedType == 'ganti_pdf' ? 'replace_pdf' : _selectedType), (val) {
                            Navigator.pop(ctx);
                            _onTypeChanged(val);
                          }, isDark),
                        ],
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

  Widget _buildTransactionCard(TransactionItem tx, bool isDark) {
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
      child: LiquidGlassCard(
        borderRadius: 18,
        padding: const EdgeInsets.all(14),
        onTap: () => _showTransactionDetail(context, tx, isDark),
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
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.15 : 0.8,
                      ),
                      width: 1.2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_downward_rounded,
                      size: 18,
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
                        tx.payerName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (tx.serviceName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          tx.serviceName,
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
                      ],
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emeraldText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hak Dev',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.emeraldDarkText
                            : AppColors.emeraldText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.6),
                  width: 0.85,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_rounded,
                        size: 13,
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tx.orderNumber,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormatter.formatDateTime(tx.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetail(
    BuildContext context,
    TransactionItem tx,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LiquidGlassModalSheet(
        maxHeightRatio: 0.88,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detail Transaksi Hak Dev',
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
                _buildDetailRow(
                  'Order ID',
                  tx.orderId.isNotEmpty ? tx.orderId : 'ORD-#${tx.id}',
                  isDark,
                  isMonospace: true,
                ),
                const Divider(height: 16),
                _buildDetailRow(
                  'No. Invoice',
                  tx.orderNumber,
                  isDark,
                  isMonospace: true,
                ),
                const Divider(height: 16),
                _buildDetailRow('Layanan', tx.serviceName, isDark),
                const Divider(height: 16),
                _buildDetailRow('Pembayar', tx.payerName, isDark),
                const Divider(height: 16),
                if (tx.journalName.isNotEmpty &&
                    tx.journalName != 'LOA Journal') ...[
                  _buildDetailRow('Jurnal', tx.journalName, isDark),
                  const Divider(height: 16),
                ],
                _buildDetailRow(
                  'Total Transaksi',
                  CurrencyFormatter.formatRupiah(tx.amount),
                  isDark,
                  isMonospace: true,
                ),
                const Divider(height: 16),
                _buildDetailRow(
                  'Hak Developer',
                  CurrencyFormatter.formatRupiah(tx.devNetShare),
                  isDark,
                  isMonospace: true,
                  valueColor: AppColors.emeraldText,
                ),
                const Divider(height: 16),
                _buildDetailRow(
                  'Waktu Bayar',
                  DateFormatter.formatDateTime(tx.createdAt),
                  isDark,
                ),
                const Divider(height: 16),
                _buildDetailRow(
                  'Status',
                  'Lunas',
                  isDark,
                  valueColor: AppColors.emeraldText,
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    bool isDark, {
    bool isMonospace = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: isMonospace ? 'monospace' : null,
              color:
                  valueColor ??
                  (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final bool isDark;
  final IconData? trailingIcon;
  final bool isActive;
  final VoidCallback? onTap;

  const _MetricMiniCard({
    required this.title,
    required this.value,
    required this.isDark,
    this.trailingIcon,
    this.isActive = false,
    this.onTap,
  });

  Widget _buildValueWidget(BuildContext context) {
    if (value.startsWith('Rp')) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Rp ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.emeraldDarkText : AppColors.emeraldText,
              ),
            ),
            TextSpan(
              text: value.replaceFirst('Rp ', '').replaceFirst('Rp', '').trim(),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isDark ? AppColors.emeraldDarkText : AppColors.emeraldText,
              ),
            ),
          ],
        ),
      );
    }

    final regex = RegExp(r'^(\d+)\s+(.+)$');
    final match = regex.firstMatch(value);

    if (match != null) {
      final count = match.group(1)!;
      final unit = match.group(2)!;
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: count,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            TextSpan(
              text: ' $unit',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      value,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: isActive
            ? AppColors.primary
            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null)
                Icon(
                  trailingIcon,
                  size: 14,
                  color: isActive
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
                ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: _buildValueWidget(context),
          ),
        ],
      ),
    );
  }
}
