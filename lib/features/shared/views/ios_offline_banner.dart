import 'dart:async';
import 'package:floafinwatch/core/network/network_service.dart';
import 'package:floafinwatch/core/network/reverb_service.dart';
import 'package:floafinwatch/features/developer/dashboard/presentation/dashboard_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IosOfflineBanner extends ConsumerStatefulWidget {
  const IosOfflineBanner({super.key});

  @override
  ConsumerState<IosOfflineBanner> createState() => _IosOfflineBannerState();
}

class _IosOfflineBannerState extends ConsumerState<IosOfflineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;
  bool _showingRestored = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 280),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onNetworkChanged(NetworkState? prev, NetworkState next) {
    if (!next.isOnline) {
      _dismissTimer?.cancel();
      _showingRestored = false;
      _controller.forward();
    } else if (prev != null && !prev.isOnline && next.isOnline) {
      // Just reconnected!
      setState(() => _showingRestored = true);
      _controller.forward();

      // Silent background refresh & reconnect Reverb
      ref.read(dashboardNotifierProvider.notifier).loadData(isRefresh: true);
      ref.read(reverbServiceProvider).init();

      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(milliseconds: 2400), () {
        if (mounted) {
          _controller.reverse().then((_) {
            if (mounted) {
              setState(() => _showingRestored = false);
              ref.read(networkProvider.notifier).clearWasOffline();
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NetworkState>(networkProvider, _onNetworkChanged);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isOffline = !ref.watch(networkProvider).isOnline;
    final isVisible = isOffline || _showingRestored;

    if (isOffline && !_showingRestored) {
      if (_controller.status != AnimationStatus.forward &&
          _controller.status != AnimationStatus.completed) {
        _controller.forward();
      }
    }

    if (!isVisible && _controller.isDismissed) {
      return const SizedBox.shrink();
    }

    final isSuccess = _showingRestored;

    return IgnorePointer(
      ignoring: true,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
            decoration: BoxDecoration(
              color: isSuccess
                  ? const Color(0xFF064E3B).withValues(alpha: 0.92)
                  : (isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.92)
                      : const Color(0xFF0F172A).withValues(alpha: 0.90)),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSuccess
                    ? const Color(0xFF10B981).withValues(alpha: 0.45)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Indicator Dot / Icon
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSuccess
                        ? const Color(0xFF34D399)
                        : const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSuccess ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  size: 15,
                  color: isSuccess
                      ? const Color(0xFF34D399)
                      : const Color(0xFFFBBF24),
                ),
                const SizedBox(width: 7),
                Text(
                  isSuccess
                      ? 'Terhubung Kembali'
                      : 'Koneksi Terputus • Menghubungkan...',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
