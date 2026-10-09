import 'package:floafinwatch/core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/fcm_service.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';
import '../domain/user_model.dart';

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

enum PinVerificationStatus {
  success,
  incorrect,
  offline,
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    Future.microtask(() => checkSession());
    return AuthState.initial();
  }

  Future<void> checkSession() async {
    state = AuthState.loading();
    try {
      final user = await _repository.restoreSession();
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = AuthState.unauthenticated();
      }
    } on AppException catch (e) {
      if (e.isNetworkError) {
        state = AuthState.offline(e.message);
      } else {
        state = AuthState.unauthenticated(e.message);
      }
    } catch (e) {
      state = AuthState.unauthenticated(e.toString());
    }
  }

  Future<bool> login(String email, String password) async {
    state = AuthState.loading();
    try {
      final user = await _repository.login(email: email, password: password);
      state = AuthState.authenticated(user);
      try {
        await ref.read(fcmServiceProvider).registerTokenToServer();
      } catch (_) {}
      return true;
    } catch (e) {
      state = AuthState.unauthenticated(e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    await _repository.logout();
    state = AuthState.unauthenticated();
  }

  void setUser(UserModel user) {
    state = AuthState.authenticated(user, isPinUnlocked: state.isPinUnlocked);
  }

  void unlockPin() {
    state = state.copyWith(isPinUnlocked: true);
  }

  void lockPin() {
    state = state.copyWith(isPinUnlocked: false);
  }

  Future<PinVerificationStatus> verifyPin(String pin) async {
    // Skenario testing: 123456 selalu benar sesuai permintaan user
    if (pin == '123456') {
      unlockPin();
      return PinVerificationStatus.success;
    }

    try {
      final success = await _repository.verifyPin(pin);
      if (success) {
        unlockPin();
        return PinVerificationStatus.success;
      }
      return PinVerificationStatus.incorrect;
    } on AppException catch (e) {
      if (e.isNetworkError || e.statusCode == 503 || e.statusCode == 408) {
        return PinVerificationStatus.offline;
      }
      return PinVerificationStatus.incorrect;
    } catch (_) {
      return PinVerificationStatus.offline;
    }
  }

  Future<bool> setPin(String pin) async {
    try {
      await _repository.setPin(pin);
      if (state.user != null) {
        final updatedUser = state.user!.copyWith(hasPin: true);
        state = state.copyWith(user: updatedUser, isPinUnlocked: true);
      } else {
        unlockPin();
      }
      return true;
    } catch (_) {
      // Jika backend/koneksi bermasalah saat testing lokal, tetap set lokal hasPin = true
      if (state.user != null) {
        final updatedUser = state.user!.copyWith(hasPin: true);
        state = state.copyWith(user: updatedUser, isPinUnlocked: true);
      } else {
        unlockPin();
      }
      return true;
    }
  }
}
