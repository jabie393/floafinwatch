import 'user_model.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  offline,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;
  final bool isPinUnlocked;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.isPinUnlocked = false,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;
  bool get isInitial => status == AuthStatus.initial;
  bool get isOffline => status == AuthStatus.offline;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    bool? isPinUnlocked,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      isPinUnlocked: isPinUnlocked ?? this.isPinUnlocked,
    );
  }

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);

  factory AuthState.authenticated(UserModel user, {bool isPinUnlocked = false}) => AuthState(
        status: AuthStatus.authenticated,
        user: user,
        isPinUnlocked: isPinUnlocked,
      );

  factory AuthState.unauthenticated([String? message]) => AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: message,
        isPinUnlocked: false,
      );

  factory AuthState.offline([String? message]) => AuthState(
        status: AuthStatus.offline,
        errorMessage: message,
        isPinUnlocked: false,
      );
}
