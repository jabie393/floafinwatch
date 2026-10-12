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

import 'services/widget_service.dart';
import 'core/storage/secure_storage_service.dart';

class LoafinwatchApp extends ConsumerStatefulWidget {
  const LoafinwatchApp({super.key});

  @override
  ConsumerState<LoafinwatchApp> createState() => _LoafinwatchAppState();
}

class _LoafinwatchAppState extends ConsumerState<LoafinwatchApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handleInitialUri();
    _widgetSubscription = HomeWidget.widgetClicked.listen(_handleWidgetLaunch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final isDark = View.of(context).platformDispatcher.platformBrightness == Brightness.dark;
        HomeWidget.saveWidgetData<bool>('is_system_dark', isDark);
        final themeMode = ref.read(themeModeProvider);
        final shouldBeDark = switch (themeMode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system => isDark,
        };
        HomeWidget.saveWidgetData<bool>('is_dark_theme', shouldBeDark);
        ref.read(secureStorageServiceProvider).saveString('last_resolved_is_dark', shouldBeDark.toString());
      }
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
    WidgetsBinding.instance.removeObserver(this);
    _widgetSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (mounted) {
      final isDark = View.of(context).platformDispatcher.platformBrightness == Brightness.dark;
      HomeWidget.saveWidgetData<bool>('is_system_dark', isDark);
      final themeMode = ref.read(themeModeProvider);
      if (themeMode == ThemeMode.system) {
        HomeWidget.saveWidgetData<bool>('is_dark_theme', isDark);
        ref.read(secureStorageServiceProvider).saveString('last_resolved_is_dark', isDark.toString());
        ref.read(widgetServiceProvider).reRenderWidgets();
      }
    }
  }

  Future<void> _handleInitialUri() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _handleWidgetLaunch(uri);
  }

  void _handleWidgetLaunch(Uri? uri) {
    if (uri == null) return;
    final uriStr = uri.toString();
    final authState = ref.read(authNotifierProvider);
    final isUnlocked = authState.isAuthenticated &&
        authState.user?.isDeveloper == true &&
        authState.isPinUnlocked;

    final String targetRoute;
    if (uri.host == 'payouts' ||
        uri.path.contains('payouts') ||
        uriStr.contains('payouts')) {
      targetRoute = '/dev/payouts';
    } else if (uri.host == 'transactions' ||
        uri.path.contains('transactions') ||
        uriStr.contains('transactions')) {
      targetRoute = '/dev/transactions';
    } else if (uri.host == 'dashboard' ||
        uri.path.contains('dashboard') ||
        uriStr.contains('dashboard')) {
      targetRoute = '/dev/dashboard';
    } else {
      targetRoute = '/dev/dashboard';
    }

    if (isUnlocked) {
      ref.read(appRouterProvider).go(targetRoute);
    } else {
      ref.read(pendingRouteProvider.notifier).setRoute(targetRoute);
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
