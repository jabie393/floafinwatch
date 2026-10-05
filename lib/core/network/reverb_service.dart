import 'dart:async';
import 'dart:developer' as dev;
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
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

class ReverbService {
  final Ref _ref;
  PusherChannelsClient? _client;
  PublicChannel? _channel;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _lifecycleSubscription;
  bool _isInitialized = false;

  ReverbService(this._ref);

  Future<void> init() async {
    if (_isInitialized) return;

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
            'Reverb connection error: $exception. Retrying...',
            error: exception,
            stackTrace: trace,
            name: 'ReverbService',
          );
          refresh();
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
    }
  }

  void _triggerRealtimeSync(dynamic rawData) {
    debugPrint('⚡ [Reverb Realtime] Event received -> Auto-syncing Dashboard, Transactions & Payouts!');
    dev.log(
      'Triggering auto-sync from Reverb event: $rawData',
      name: 'ReverbService',
    );
    try {
      HapticFeedback.lightImpact();
      _ref.read(dashboardNotifierProvider.notifier).loadData(isRefresh: true);
      _ref.read(realtimeSyncTriggerProvider.notifier).trigger();
      _ref.invalidate(transactionsProvider);
      _ref.invalidate(payoutsProvider);
    } catch (e) {
      dev.log('Error triggering realtime sync: $e', name: 'ReverbService');
    }
  }

  void dispose() {
    try {
      _eventSubscription?.cancel();
      _lifecycleSubscription?.cancel();
      _channel?.unsubscribe();
      _client?.disconnect();
      _client?.dispose();
    } catch (e) {
      dev.log('Error disposing ReverbService: $e', name: 'ReverbService');
    }
    _isInitialized = false;
  }
}
