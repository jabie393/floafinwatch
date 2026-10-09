import 'dart:async';
import 'dart:developer' as dev;
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import 'network_service.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/developer/dashboard/presentation/dashboard_notifier.dart';
import '../../features/developer/payouts/payouts_screen.dart';
import '../../features/developer/transactions/transactions_screen.dart';

class RealtimeSyncTriggerNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() {
    state++;
  }
}

final realtimeSyncTriggerProvider =
    NotifierProvider<RealtimeSyncTriggerNotifier, int>(RealtimeSyncTriggerNotifier.new);

final reverbServiceProvider = Provider<ReverbService>((ref) {
  final service = ReverbService(ref);
  service.init();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class ReverbService with WidgetsBindingObserver {
  final Ref _ref;
  PusherChannelsClient? _client;
  PublicChannel? _channel;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _lifecycleSubscription;
  ProviderSubscription<NetworkState>? _networkSubscription;
  Timer? _reconnectDebounce;
  bool _isInitialized = false;
  bool _isConnecting = false;

  ReverbService(this._ref);

  Future<void> init() async {
    if (_isInitialized || _isConnecting) return;
    _isConnecting = true;

    try {
      final host = AppConfig.resolvedReverbHost;
      final port = AppConfig.reverbPort;
      final scheme = AppConfig.reverbScheme;

      dev.log(
        'Connecting to Reverb at $host:$port ($scheme)...',
        name: 'ReverbService',
      );

      final options = PusherChannelsOptions.fromHost(
        scheme: scheme == 'https' ? 'wss' : 'ws',
        host: host,
        port: port,
        key: AppConfig.reverbAppKey,
        shouldSupplyMetadataQueries: true,
        metadata: PusherChannelsOptionsMetadata.byDefault(),
      );

      _client = PusherChannelsClient.websocket(
        options: options,
        connectionErrorHandler: (exception, trace, refresh) {
          dev.log(
            'Reverb connection error: $exception. Scheduling reconnect...',
            error: exception,
            stackTrace: trace,
            name: 'ReverbService',
          );
          _scheduleReconnect();
        },
      );

      _lifecycleSubscription = _client!.lifecycleStream.listen((event) {
        dev.log('Reverb lifecycle event: $event', name: 'ReverbService');
      });

      await _client!.connect();

      _channel = _client!.publicChannel('dev-financial');
      _channel!.subscribe();

      _eventSubscription = _channel!.bindToAll().listen((event) {
        dev.log(
          'Reverb event received: name=${event.name} data=${event.data}',
          name: 'ReverbService',
        );
        if (!event.name.startsWith('pusher:')) {
          _triggerRealtimeSync(event.data);
        }
      });

      _isInitialized = true;

      // Register observers only once
      _setupNetworkObserver();
      WidgetsBinding.instance.removeObserver(this);
      WidgetsBinding.instance.addObserver(this);

      dev.log(
        'ReverbService initialized and subscribed to dev-financial',
        name: 'ReverbService',
      );
    } catch (e, stack) {
      dev.log(
        'ReverbService init error: $e',
        error: e,
        stackTrace: stack,
        name: 'ReverbService',
      );
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _setupNetworkObserver() {
    _networkSubscription?.close();
    _networkSubscription = _ref.listen<NetworkState>(networkProvider, (prev, next) {
      if (prev != null && !prev.isOnline && next.isOnline) {
        dev.log(
          'Network connection restored -> Auto reconnecting Reverb WebSockets...',
          name: 'ReverbService',
        );
        reconnect();
        // Also sync any data missed while offline
        _triggerRealtimeSync(null);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      dev.log(
        'App resumed from background -> Ensuring Reverb connection is alive...',
        name: 'ReverbService',
      );
      reconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectDebounce?.cancel();
    _reconnectDebounce = Timer(const Duration(seconds: 3), () {
      if (_ref.read(networkProvider).isOnline) {
        reconnect();
      }
    });
  }

  Future<void> reconnect() async {
    dev.log('Reconnecting ReverbService...', name: 'ReverbService');
    _cleanupSocket();
    await Future.delayed(const Duration(milliseconds: 200));
    await init();
  }

  void _triggerRealtimeSync(dynamic rawData) {
    debugPrint('⚡ [Reverb Realtime] Event received -> Auto-syncing Dashboard, Transactions & Payouts!');
    dev.log(
      'Triggering auto-sync from Reverb event: $rawData',
      name: 'ReverbService',
    );
    try {
      HapticFeedback.lightImpact();
      _ref.read(authNotifierProvider.notifier).refreshProfile();
      _ref.read(dashboardNotifierProvider.notifier).loadData(isRefresh: true);
      _ref.read(realtimeSyncTriggerProvider.notifier).trigger();
      _ref.invalidate(transactionsProvider);
      _ref.invalidate(payoutsProvider);
    } catch (e) {
      dev.log('Error triggering realtime sync: $e', name: 'ReverbService');
    }
  }

  void _cleanupSocket() {
    try {
      _eventSubscription?.cancel();
      _eventSubscription = null;
      _lifecycleSubscription?.cancel();
      _lifecycleSubscription = null;
      _channel?.unsubscribe();
      _channel = null;
      _client?.disconnect();
      _client?.dispose();
      _client = null;
    } catch (e) {
      dev.log('Error cleaning up socket: $e', name: 'ReverbService');
    }
    _isInitialized = false;
  }

  void dispose() {
    _reconnectDebounce?.cancel();
    _networkSubscription?.close();
    _networkSubscription = null;
    WidgetsBinding.instance.removeObserver(this);
    _cleanupSocket();
    dev.log('ReverbService disposed', name: 'ReverbService');
  }
}
