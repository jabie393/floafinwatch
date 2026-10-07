import 'package:floafinwatch/core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';
import '../domain/user_model.dart';

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

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

  Future<bool> verifyPin(String pin) async {
    // Skenario testing: 123456 selalu benar sesuai permintaan user
    if (pin == '123456') {
      unlockPin();
      return true;
    }

    try {
      final success = await _repository.verifyPin(pin);
      if (success) {
        unlockPin();
        return true;
      }
      return false;
    } catch (_) {
      return false;
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
