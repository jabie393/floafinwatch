import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/auth/presentation/auth_notifier.dart';
import 'services/fcm_service.dart';

class LoafinwatchApp extends ConsumerStatefulWidget {
  const LoafinwatchApp({super.key});

  @override
  ConsumerState<LoafinwatchApp> createState() => _LoafinwatchAppState();
}

class _LoafinwatchAppState extends ConsumerState<LoafinwatchApp> {
  StreamSubscription<Uri?>? _widgetSubscription;

  @override
  void initState() {
    super.initState();
    _handleInitialUri();
    _widgetSubscription = HomeWidget.widgetClicked.listen(_handleWidgetLaunch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fcmServiceProvider).initialize(
        onNavigate: (route) {
          final authState = ref.read(authNotifierProvider);
          final isUnlocked = authState.isAuthenticated &&
              authState.user?.isDeveloper == true &&
              authState.isPinUnlocked;
          if (isUnlocked) {
            ref.read(appRouterProvider).go(route);
          } else {
            ref.read(pendingRouteProvider.notifier).setRoute(route);
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _widgetSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleInitialUri() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _handleWidgetLaunch(uri);
  }

  void _handleWidgetLaunch(Uri? uri) {
    if (uri == null) return;
    final uriStr = uri.toString();
    final authState = ref.read(authNotifierProvider);
    final isAuthDev =
        authState.isAuthenticated && authState.user?.isDeveloper == true;

    if (uri.host == 'payouts' ||
        uri.path.contains('payouts') ||
        uriStr.contains('payouts')) {
      if (isAuthDev) {
        ref.read(appRouterProvider).go('/dev/payouts');
      } else {
        ref.read(pendingRouteProvider.notifier).setRoute('/dev/payouts');
      }
    } else if (uri.host == 'dashboard' ||
        uri.path.contains('dashboard') ||
        uriStr.contains('dashboard')) {
      if (isAuthDev) {
        ref.read(appRouterProvider).go('/dev/dashboard');
      } else {
        ref.read(pendingRouteProvider.notifier).setRoute('/dev/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        overscroll: false,
      ),
    );
  }
}
