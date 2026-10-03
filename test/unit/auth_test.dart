import 'package:floafinwatch/features/auth/domain/auth_state.dart';
import 'package:floafinwatch/features/auth/domain/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthState Lifecycle Tests', () {
    test('initial state has correct flags', () {
      final state = AuthState.initial();
      expect(state.isInitial, isTrue);
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.user, isNull);
    });

    test('loading state has correct flags', () {
      final state = AuthState.loading();
      expect(state.isInitial, isFalse);
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isTrue);
    });

    test('authenticated state sets user and authenticated flag', () {
      const user = UserModel(
        id: 1,
        name: 'Dev User',
        email: 'dev@user.com',
        roles: ['ryu_dev'],
      );
      final state = AuthState.authenticated(user);

      expect(state.isAuthenticated, isTrue);
      expect(state.user, equals(user));
      expect(state.user!.isDeveloper, isTrue);
    });

    test('unauthenticated state clears user and preserves error message', () {
      final state = AuthState.unauthenticated('Invalid credentials');

      expect(state.isAuthenticated, isFalse);
      expect(state.user, isNull);
      expect(state.errorMessage, 'Invalid credentials');
    });
  });
}
