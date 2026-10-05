import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkState {
  final bool isOnline;
  final bool isChecking;
  final bool wasOffline;

  const NetworkState({
    required this.isOnline,
    this.isChecking = false,
    this.wasOffline = false,
  });

  NetworkState copyWith({
    bool? isOnline,
    bool? isChecking,
    bool? wasOffline,
  }) {
    return NetworkState(
      isOnline: isOnline ?? this.isOnline,
      isChecking: isChecking ?? this.isChecking,
      wasOffline: wasOffline ?? this.wasOffline,
    );
  }
}

class NetworkNotifier extends Notifier<NetworkState> {
  Timer? _timer;

  @override
  NetworkState build() {
    _startMonitoring();
    ref.onDispose(() {
      _timer?.cancel();
    });
    // Check initial connectivity in microtask
    Future.microtask(() => checkConnectivity(silent: true));
    return const NetworkState(isOnline: true);
  }

  void _startMonitoring() {
    _timer?.cancel();
    // Poll every 2.5 seconds for instant reactive offline detection
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      checkConnectivity(silent: true);
    });
  }

  Future<bool> checkConnectivity({bool silent = false}) async {
    if (!silent && !state.isChecking) {
      state = state.copyWith(isChecking: true);
    }

    bool online = false;
    try {
      // Direct raw TCP probe to Cloudflare 1.1.1.1:53
      // Fast, non-blocking, kernel-level rejection when offline (< 30ms)
      final socket = await Socket.connect(
        '1.1.1.1',
        53,
        timeout: const Duration(milliseconds: 1500),
      );
      socket.destroy();
      online = true;
    } catch (_) {
      try {
        // Fallback to Google 8.8.8.8:53
        final socket = await Socket.connect(
          '8.8.8.8',
          53,
          timeout: const Duration(milliseconds: 1500),
        );
        socket.destroy();
        online = true;
      } catch (_) {
        online = false;
      }
    }

    final bool previouslyOffline = !state.isOnline;

    if (online) {
      if (previouslyOffline) {
        // Connection just restored!
        HapticFeedback.lightImpact();
        state = NetworkState(
          isOnline: true,
          isChecking: false,
          wasOffline: true,
        );
      } else {
        state = state.copyWith(isOnline: true, isChecking: false);
      }
    } else {
      state = state.copyWith(isOnline: false, isChecking: false);
    }

    return online;
  }

  void reportNetworkDisconnected() {
    if (state.isOnline) {
      state = state.copyWith(isOnline: false);
    }
  }

  void clearWasOffline() {
    if (state.wasOffline) {
      state = state.copyWith(wasOffline: false);
    }
  }
}

final networkProvider =
    NotifierProvider<NetworkNotifier, NetworkState>(NetworkNotifier.new);
