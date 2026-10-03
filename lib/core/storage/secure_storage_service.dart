import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  final FlutterSecureStorage _storage;

  static const String _keyToken = 'auth_access_token';
  static const String _keyUser = 'auth_user_cache';

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _keyToken);
  }

  Future<void> saveUserCache(String userJson) async {
    await _storage.write(key: _keyUser, value: userJson);
  }

  Future<String?> getUserCache() async {
    return await _storage.read(key: _keyUser);
  }

  Future<void> deleteUserCache() async {
    await _storage.delete(key: _keyUser);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
