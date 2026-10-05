import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:floafinwatch/services/widget_service.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_model.dart';

final selectedPeriodProvider = NotifierProvider<PeriodNotifier, String>(PeriodNotifier.new);

class PeriodNotifier extends Notifier<String> {
  @override
  String build() => '7d';

  void setPeriod(String period) {
    state = period;
  }
}

final isChartLoadingProvider = NotifierProvider<ChartLoadingNotifier, bool>(ChartLoadingNotifier.new);

class ChartLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoading(bool loading) {
    state = loading;
  }
}

final dashboardNotifierProvider =
    NotifierProvider<DashboardNotifier, AsyncValue<DeveloperDashboardData>>(DashboardNotifier.new);

class DashboardNotifier extends Notifier<AsyncValue<DeveloperDashboardData>> {
  late final DashboardRepository _repository;
  late final WidgetService _widgetService;
  DeveloperDashboardData? _cachedData;

  @override
  AsyncValue<DeveloperDashboardData> build() {
    _repository = ref.watch(dashboardRepositoryProvider);
    _widgetService = ref.watch(widgetServiceProvider);
    Future.microtask(() => loadData());
    return const AsyncValue.loading();
  }

  Future<void> loadData({bool isRefresh = false}) async {
    // Only set full loading state if we have never loaded data yet
    if (_cachedData == null && !isRefresh) {
      state = const AsyncValue.loading();
    }

    final period = ref.read(selectedPeriodProvider);
    try {
      final data = await _repository.fetchDashboardData(period: period);
      _cachedData = data;
      await _widgetService.updateWidgetSnapshot(data);
      state = AsyncValue.data(data);
    } catch (e, st) {
      if (_cachedData != null) {
        // If data was previously loaded, keep showing existing data
        state = AsyncValue.data(_cachedData!);
      } else {
        // Only show error screen if no data has ever been loaded
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> changePeriod(String newPeriod) async {
    final currentPeriod = ref.read(selectedPeriodProvider);
    final isAlreadyLoading = ref.read(isChartLoadingProvider);
    if (currentPeriod == newPeriod && !isAlreadyLoading) return;

    ref.read(selectedPeriodProvider.notifier).setPeriod(newPeriod);
    ref.read(isChartLoadingProvider.notifier).setLoading(true);

    try {
      final data = await _repository.fetchDashboardData(period: newPeriod);
      _cachedData = data;
      await _widgetService.updateWidgetSnapshot(data);
      state = AsyncValue.data(data);
    } catch (e, st) {
      if (_cachedData != null) {
        state = AsyncValue.data(_cachedData!);
      } else {
        state = AsyncValue.error(e, st);
      }
    } finally {
      ref.read(isChartLoadingProvider.notifier).setLoading(false);
    }
  }

  Future<void> refresh() async {
    await loadData(isRefresh: true);
  }
}
