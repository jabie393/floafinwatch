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
    state = AuthState.authenticated(user);
  }
}
