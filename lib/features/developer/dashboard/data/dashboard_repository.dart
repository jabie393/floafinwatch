import 'package:dio/dio.dart';
import 'package:floafinwatch/core/constants/app_endpoints.dart';
import 'package:floafinwatch/core/errors/app_exception.dart';
import 'package:floafinwatch/core/network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../payouts/domain/payout_model.dart';
import '../../transactions/domain/transaction_model.dart';
import '../domain/dashboard_model.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(dio: ref.watch(dioProvider));
});

class DashboardRepository {
  final Dio dio;

  DashboardRepository({required this.dio});

  Future<DeveloperDashboardData> fetchDashboardData({String period = '30d'}) async {
    try {
      final response = await dio.get(
        AppEndpoints.developerDashboard,
        queryParameters: {'period': period},
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AppException(message: 'Format data dashboard tidak valid.');
      }

      final payload = data['data'] is Map<String, dynamic> ? data['data'] : data;
      return DeveloperDashboardData.fromJson(payload as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  Future<PaginatedTransactionsResponse> fetchTransactionsPaginated({
    int page = 1,
    int perPage = 50,
    String period = 'all',
    int? year,
    int? month,
    String? type,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
        'period': period,
      };
      if (year != null) {
        queryParams['year'] = year;
      }
      if (month != null) {
        queryParams['month'] = month;
      }
      if (type != null && type.isNotEmpty && type != 'all') {
        queryParams['type'] = type;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await dio.get(
        AppEndpoints.developerTransactions,
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const PaginatedTransactionsResponse(items: []);
      }

      return PaginatedTransactionsResponse.fromJson(data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  Future<List<TransactionItem>> fetchTransactions({int page = 1}) async {
    final res = await fetchTransactionsPaginated(page: page);
    return res.items;
  }

  Future<List<PayoutItem>> fetchPayouts({int page = 1}) async {
    try {
      final response = await dio.get(
        AppEndpoints.developerPayouts,
        queryParameters: {'page': page},
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) return [];

      final rawList = data['data'] is Map<String, dynamic>
          ? data['data']['data']
          : data['data'];

      if (rawList is List) {
        return rawList.map((e) => PayoutItem.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }
}
