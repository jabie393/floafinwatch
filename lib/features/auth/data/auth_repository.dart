import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_endpoints.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(dioProvider),
    storage: ref.watch(secureStorageServiceProvider),
  );
});

class AuthRepository {
  final Dio dio;
  final SecureStorageService storage;

  AuthRepository({
    required this.dio,
    required this.storage,
  });

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        AppEndpoints.login,
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const AppException(message: 'Format respon server tidak valid.');
      }

      final token = data['token'] ?? data['access_token'] ?? data['data']?['token'];
      if (token == null || token.toString().isEmpty) {
        throw const AppException(message: 'Autentikasi gagal: token tidak ditemukan.');
      }

      final userData = data['user'] ?? data['data']?['user'] ?? data['data'];
      if (userData is! Map<String, dynamic>) {
        throw const AppException(message: 'Data user tidak ditemukan dalam respon.');
      }

      final user = UserModel.fromJson(userData);

      // Persist to secure storage
      await storage.saveToken(token.toString());
      await storage.saveUserCache(user.toRawJson());

      return user;
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  Future<UserModel?> restoreSession() async {
    try {
      final token = await storage.getToken();
      if (token == null || token.isEmpty) {
        return null;
      }

      try {
        final response = await dio.get(AppEndpoints.me);
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final userData = data['user'] ?? data['data']?['user'] ?? data['data'] ?? data;
          if (userData is Map<String, dynamic>) {
            final user = UserModel.fromJson(userData);
            await storage.saveUserCache(user.toRawJson());
            return user;
          }
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 401) {
          await logout();
          return null;
        }

        final cached = await storage.getUserCache();
        if (cached != null) {
          try {
            final user = UserModel.fromRawJson(cached);
            if (user.isDeveloper && user.email.isNotEmpty) {
              return user;
            }
          } catch (_) {}
        }

        throw AppException.fromDioError(dioErr);
      }

      final cached = await storage.getUserCache();
      if (cached != null) {
        try {
          final user = UserModel.fromRawJson(cached);
          if (user.isDeveloper && user.email.isNotEmpty) {
            return user;
          }
        } catch (_) {}
      }
      return null;
    } on AppException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await dio.post(AppEndpoints.logout);
    } catch (_) {
      // Ignore network errors on logout to guarantee local wipe
    } finally {
      await storage.clearAll();
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final response = await dio.post(
        AppEndpoints.verifyPin,
        data: {'pin': pin},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 422 || e.response?.statusCode == 400) {
        return false;
      }
      throw AppException.fromDioError(e);
    }
  }

  Future<bool> setPin(String pin) async {
    try {
      final response = await dio.post(
        AppEndpoints.setPin,
        data: {
          'pin': pin,
          'pin_confirmation': pin,
        },
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['success'] == true;
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }
}
