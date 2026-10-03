import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:floafinwatch/services/widget_service.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_model.dart';

final selectedPeriodProvider = NotifierProvider<PeriodNotifier, String>(PeriodNotifier.new);

class PeriodNotifier extends Notifier<String> {
  @override
  String build() => '30d';

  void setPeriod(String period) {
    state = period;
  }
}

final dashboardNotifierProvider =
    NotifierProvider<DashboardNotifier, AsyncValue<DeveloperDashboardData>>(DashboardNotifier.new);

class DashboardNotifier extends Notifier<AsyncValue<DeveloperDashboardData>> {
  late final DashboardRepository _repository;
  late final WidgetService _widgetService;

  @override
  AsyncValue<DeveloperDashboardData> build() {
    _repository = ref.watch(dashboardRepositoryProvider);
    _widgetService = ref.watch(widgetServiceProvider);
    Future.microtask(() => loadData());
    return const AsyncValue.loading();
  }

  Future<void> loadData({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = const AsyncValue.loading();
    }

    final period = ref.read(selectedPeriodProvider);
    try {
      final data = await _repository.fetchDashboardData(period: period);
      await _widgetService.updateWidgetSnapshot(data);
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await loadData(isRefresh: true);
  }
}
