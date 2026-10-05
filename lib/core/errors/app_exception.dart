import 'package:dio/dio.dart';

class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const AppException({
    required this.message,
    this.statusCode,
    this.details,
  });

  factory AppException.fromDioError(DioException dioError) {
    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException(
          message: 'Koneksi waktu habis. Periksa koneksi internet Anda.',
          statusCode: 408,
        );
      case DioExceptionType.badResponse:
        final statusCode = dioError.response?.statusCode;
        final responseData = dioError.response?.data;
        String message = 'Terjadi kesalahan pada server.';

        if (responseData is Map<String, dynamic>) {
          if (responseData['message'] != null) {
            message = responseData['message'].toString();
          } else if (responseData['error'] != null) {
            message = responseData['error'].toString();
          }
        }

        if (statusCode == 401) {
          return AppException(
            message: message.isNotEmpty ? message : 'Sesi Anda telah berakhir. Silakan login kembali.',
            statusCode: 401,
            details: responseData,
          );
        } else if (statusCode == 403) {
          return AppException(
            message: 'Anda tidak memiliki hak akses untuk tindakan ini.',
            statusCode: 403,
            details: responseData,
          );
        } else if (statusCode == 404) {
          return AppException(
            message: 'Layanan atau data tidak ditemukan.',
            statusCode: 404,
            details: responseData,
          );
        } else if (statusCode == 422) {
          return AppException(
            message: message,
            statusCode: 422,
            details: responseData,
          );
        }

        return AppException(
          message: message,
          statusCode: statusCode,
          details: responseData,
        );

      case DioExceptionType.connectionError:
        return const AppException(
          message: 'Gagal terhubung ke server backend LOA. Pastikan server aktif dan URL benar.',
          statusCode: 503,
        );

      case DioExceptionType.cancel:
        return const AppException(
          message: 'Permintaan dibatalkan.',
        );

      default:
        return AppException(
          message: dioError.message ?? 'Terjadi kesalahan jaringan yang tidak terduga.',
        );
    }
  }

  bool get isNetworkError => statusCode == 408 || statusCode == 503;

  @override
  String toString() => message;
}
