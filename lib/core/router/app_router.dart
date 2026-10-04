import 'package:floafinwatch/features/auth/domain/auth_state.dart';
import 'package:floafinwatch/features/auth/presentation/auth_notifier.dart';
import 'package:floafinwatch/features/auth/presentation/login_screen.dart';
import 'package:floafinwatch/features/developer/dashboard/presentation/developer_dashboard_screen.dart';
import 'package:floafinwatch/features/developer/payouts/payouts_screen.dart';
import 'package:floafinwatch/features/developer/transactions/transactions_screen.dart';
import 'package:floafinwatch/features/profile/profile_screen.dart';
import 'package:floafinwatch/features/shared/views/main_navigation_shell.dart';
import 'package:floafinwatch/features/shared/views/splash_screen.dart';
import 'package:floafinwatch/features/shared/views/unauthorized_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';
      final isUnauthorized = state.matchedLocation == '/unauthorized';

      // 1. Still determining initial session state
      if (authState.isInitial || (authState.isLoading && authState.user == null)) {
        return isSplash ? null : '/splash';
      }

      // 2. Not logged in
      if (!authState.isAuthenticated) {
        return isLoggingIn ? null : '/login';
      }

      // 3. Logged in, check role authorization
      final user = authState.user!;
      if (!user.isDeveloper) {
        return isUnauthorized ? null : '/unauthorized';
      }

      // 4. Authenticated developer trying to visit splash or login
      if (isSplash || isLoggingIn || isUnauthorized) {
        return '/dev/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute(
        navigatorContainerBuilder: (context, navigationShell, children) {
          return MainNavigationShell(
            navigationShell: navigationShell,
            children: children,
          );
        },
        builder: (context, state, navigationShell) {
          return navigationShell;
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dev/dashboard',
                builder: (context, state) => const DeveloperDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dev/transactions',
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dev/payouts',
                builder: (context, state) => const PayoutsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/unauthorized',
        builder: (context, state) => const UnauthorizedScreen(),
      ),
    ],
  );
});

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, _) {
      notifyListeners();
    });
  }
}
