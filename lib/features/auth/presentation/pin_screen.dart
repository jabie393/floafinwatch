import 'package:floafinwatch/core/widgets/liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/network_service.dart';
import '../../shared/views/ios_offline_banner.dart';
import 'auth_notifier.dart';

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 6;
  final List<String> _enteredPin = [];

  // Local authentication instance & biometric availability
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canUseBiometrics = false;

  // Setup mode variables (jika akun belum memiliki PIN)
  bool _isSetupMode = false;
  int _setupStep = 1; // 1: Buat PIN Baru, 2: Konfirmasi PIN Baru
  String _firstPin = '';

  // State status
  bool _isLoading = false;
  bool _isSuccess = false;
  bool _isError = false;
  String? _statusMessage;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -14.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -14.0, end: 14.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 14.0, end: -10.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 10.0, end: -5.0), weight: 1.5),
          TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 1.5),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authNotifierProvider).user;
      if (user != null && !user.hasPin) {
        setState(() {
          _isSetupMode = true;
          _setupStep = 1;
          _canUseBiometrics = false;
        });
      } else {
        _checkBiometrics();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final user = ref.read(authNotifierProvider).user;
    final hasPin = user?.hasPin ?? false;

    // Jika belum memiliki PIN atau sedang dalam setup mode, biometrik tidak boleh aktif
    if (!hasPin || _isSetupMode) {
      if (mounted) setState(() => _canUseBiometrics = false);
      return;
    }

    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      final List<BiometricType> availableBiometrics = await _localAuth
          .getAvailableBiometrics();

      final bool canUse =
          (canCheckBiometrics || isDeviceSupported) &&
          availableBiometrics.isNotEmpty;

      if (!mounted) return;
      setState(() {
        _canUseBiometrics = canUse;
      });

      // Otomatis munculkan prompt biometric jika tersedia dan online
      if (canUse && !_isLoading && !_isSuccess) {
        final isOnline = ref.read(networkProvider).isOnline;
        if (isOnline) {
          _authenticateWithBiometrics();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _canUseBiometrics = false);
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isLoading || _isSuccess || _isSetupMode || !_canUseBiometrics) return;

    // 1. Cek koneksi internet terlebih dahulu. Jika offline, blokir login biometrik!
    final isOnline = await ref.read(networkProvider.notifier).checkConnectivity(silent: true);
    if (!isOnline) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _isError = false; // Bar PIN tidak merah
        _statusMessage = 'Internet terputus';
      });

      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted && _statusMessage == 'Internet terputus') {
        setState(() => _statusMessage = null);
      }
      return;
    }

    try {
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: '\u200B',
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Sidik Jari F Loafinwatch',
            signInHint: '',
            cancelButton: 'Batal',
          ),
        ],
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (!mounted) return;

      if (authenticated) {
        // 2. Cek kembali konektivitas internet setelah dialog ditutup
        final stillOnline = await ref.read(networkProvider.notifier).checkConnectivity(silent: true);
        if (!stillOnline) {
          HapticFeedback.lightImpact();
          _shakeController.forward(from: 0.0);
          setState(() {
            _isLoading = false;
            _isSuccess = false;
            _isError = false; // Bar PIN tidak merah
            _statusMessage = 'Internet terputus';
          });

          await Future.delayed(const Duration(milliseconds: 1800));
          if (mounted && _statusMessage == 'Internet terputus') {
            setState(() => _statusMessage = null);
          }
          return;
        }

        HapticFeedback.mediumImpact();
        setState(() {
          _isLoading = false;
          _isSuccess = true;
          _isError = false;
          _statusMessage = 'Biometrik terverifikasi';
        });

        ref.read(authNotifierProvider.notifier).unlockPin();

        await Future.delayed(const Duration(milliseconds: 650));
        if (!mounted) return;
        context.go('/dev/dashboard');
      }
    } catch (_) {
      // User membatalkan dialog biometrik
    }
  }

  void _onDigitPressed(String digit) {
    if (_isLoading || _isSuccess || _enteredPin.length >= _pinLength) return;

    HapticFeedback.lightImpact();

    setState(() {
      _isError = false;
      _statusMessage = null;
      _enteredPin.add(digit);
    });

    if (_enteredPin.length == _pinLength) {
      final pin = _enteredPin.join();
      if (_isSetupMode) {
        _handleSetupPin(pin);
      } else {
        _handleVerifyPin(pin);
      }
    }
  }

  void _onBackspacePressed() {
    if (_isLoading || _isSuccess || _enteredPin.isEmpty) return;

    HapticFeedback.selectionClick();
    setState(() {
      _isError = false;
      _statusMessage = null;
      _enteredPin.removeLast();
    });
  }

  Future<void> _handleVerifyPin(String pin) async {
    setState(() => _isLoading = true);

    // 1. Cek koneksi internet sebelum verifikasi PIN
    final isOnline = await ref.read(networkProvider.notifier).checkConnectivity(silent: true);
    if (!isOnline) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _isError = false; // Bar PIN tidak merah saat offline
        _statusMessage = 'Internet terputus';
      });

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _enteredPin.clear();
        });
      }
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted && _statusMessage == 'Internet terputus') {
        setState(() => _statusMessage = null);
      }
      return;
    }

    final status = await ref
        .read(authNotifierProvider.notifier)
        .verifyPin(pin);

    if (!mounted) return;

    if (status == PinVerificationStatus.success) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _isError = false;
        _statusMessage = 'PIN benar';
      });

      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      context.go('/dev/dashboard');
    } else if (status == PinVerificationStatus.offline) {
      HapticFeedback.lightImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _isError = false; // Bar PIN tidak merah saat offline
        _statusMessage = 'Internet terputus';
      });

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _enteredPin.clear();
        });
      }
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted && _statusMessage == 'Internet terputus') {
        setState(() => _statusMessage = null);
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _isError = true;
        _statusMessage = 'PIN salah, coba lagi';
      });

      _shakeController.forward(from: 0.0);

      await Future.delayed(const Duration(milliseconds: 450));
      if (mounted) {
        setState(() {
          _enteredPin.clear();
          _isError = false; // Reset status titik PIN agar kembali normal setelah animasi merah
        });
      }
    }
  }

  Future<void> _handleSetupPin(String pin) async {
    if (_setupStep == 1) {
      // Step 1: simpan pin pertama lalu minta konfirmasi
      HapticFeedback.lightImpact();
      _firstPin = pin;
      setState(() {
        _enteredPin.clear();
        _setupStep = 2;
        _statusMessage = 'Masukkan kembali PIN untuk konfirmasi';
      });
    } else {
      // Step 2: verifikasi kecocokan
      if (pin == _firstPin) {
        setState(() => _isLoading = true);
        final success = await ref
            .read(authNotifierProvider.notifier)
            .setPin(pin);
        if (!mounted) return;

        if (success) {
          HapticFeedback.mediumImpact();
          setState(() {
            _isLoading = false;
            _isSuccess = true;
            _statusMessage = 'PIN berhasil dibuat!';
          });

          await Future.delayed(const Duration(milliseconds: 700));
          if (!mounted) return;
          context.go('/dev/dashboard');
        } else {
          _triggerSetupError(
            'Gagal menyimpan PIN ke server. Silakan coba lagi.',
          );
        }
      } else {
        // Konfirmasi gagal -> ulangi dari awal
        _triggerSetupError(
          'PIN tidak cocok! Silakan masukkan PIN baru dari awal.',
        );
      }
    }
  }

  void _triggerSetupError(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _isLoading = false;
      _isError = true;
      _statusMessage = message;
      _setupStep = 1;
      _firstPin = '';
    });

    _shakeController.forward(from: 0.0);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _enteredPin.clear();
          _isError = false; // Reset status titik PIN agar kembali normal setelah animasi merah
        });
      }
    });
  }

  void _showHelpModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.70 : 0.45),
      builder: (ctx) {
        return LiquidGlassModalSheet(
          maxHeightRatio: 0.88,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header badge & title
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7)
                            .withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF0284C7)
                              .withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF0284C7),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bantuan & Panduan PIN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Keamanan Akses F Loafinwatch',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Card 1: Fungsi PIN
                _buildInfoGlassCard(
                  isDark: isDark,
                  icon: Icons.lock_outline_rounded,
                  iconColor: const Color(0xFF0284C7),
                  title: 'Fungsi PIN Keamanan',
                  description: 'PIN 6 digit berfungsi sebagai kunci otentikasi utama untuk mengamankan data transaksi keuangan, riwayat payout, dan akses dashboard developer Anda.',
                ),
                const SizedBox(height: 12),

                // Card 2: Jika Belum Memiliki PIN
                _buildInfoGlassCard(
                  isDark: isDark,
                  icon: Icons.app_registration_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Jika Belum Memiliki PIN',
                  description: 'Bagi akun baru yang belum memiliki PIN, sistem otomatis mengarahkan Anda membuat PIN 6 digit baru dengan 2 kali konfirmasi langsung di layar ini.',
                ),
                const SizedBox(height: 12),

                // Card 3: Atur Ulang Melalui Website LOA
                _buildInfoGlassCard(
                  isDark: isDark,
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF6366F1),
                  title: 'Atur Ulang Melalui Website LOA',
                  description: 'PIN dapat diubah atau diatur ulang kapan saja melalui website resmi LOA CIB (loa.jurnalcib.com) pada menu Edit Profile akun Anda.',
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showForgotPinModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.70 : 0.45),
      builder: (ctx) {
        return LiquidGlassModalSheet(
          maxHeightRatio: 0.88,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header badge & title
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B)
                            .withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: Color(0xFFF59E0B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lupa PIN Keamanan?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Panduan Mengatur Ulang PIN Akun',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Explanation Liquid Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.65),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.12 : 0.75,
                      ),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jika Anda lupa PIN, silakan atur ulang dengan langkah berikut:',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF1E293B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildStepItem(
                        number: '1',
                        text: 'Login ke website LOA CIB menggunakan akun Anda yang ingin diubah PIN-nya.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _buildStepItem(
                        number: '2',
                        text: 'Buka menu Profile (Edit Profile) di website.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _buildStepItem(
                        number: '3',
                        text: 'Masukkan 6 digit angka baru pada kolom New PIN lalu simpan perubahan.',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Primary Button: Buka Website LOA (loa.jurnalcib.com)
                ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse('https://loa.jurnalcib.com');
                    try {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {
                      await launchUrl(uri);
                    }
                  },
                  icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                  label: const Text(
                    'Buka Website',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoGlassCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.75),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required String number,
    required String text,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7)
                .withValues(alpha: isDark ? 0.25 : 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF0284C7).withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(authNotifierProvider).user;

    // Subtitle & Header text
    String greetingText =
        'Selamat Datang Kembali, ${user?.name.isNotEmpty == true ? user!.name : 'Developer'}';
    String promptText = 'Masukkan PIN kamu';

    if (_isSetupMode) {
      greetingText = _setupStep == 1
          ? 'Akun Belum Memiliki PIN'
          : 'Konfirmasi PIN';
      promptText = _setupStep == 1
          ? 'Silakan masukkan 6 digit PIN baru'
          : 'Masukkan kembali PIN yang baru dibuat';
    }

    if (_statusMessage != null) {
      promptText = _statusMessage!;
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Liquid Glass Mesh
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [
                          Color(0xFF050B14),
                          Color(0xFF0F1E33),
                          Color(0xFF070F1E),
                        ]
                      : const [
                          Color(0xFFE2F0FE),
                          Color(0xFFF0F7FF),
                          Color(0xFFE6EEF8),
                        ],
                ),
              ),
            ),
          ),

          // Subtle ambient glow orbs
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0EA5E9)
                    .withValues(alpha: isDark ? 0.15 : 0.25),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8)
                    .withValues(alpha: isDark ? 0.12 : 0.2),
              ),
            ),
          ),

          // Safe area main content with responsive layout to prevent overflow in floating window / landscape mode
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = constraints.maxHeight;
                final isCompact = maxHeight < 720;
                final isUltraCompact = maxHeight < 580;

                final double logoSize = isUltraCompact
                    ? 46.0
                    : (isCompact ? 58.0 : 76.0);
                final double logoIconSize = isUltraCompact
                    ? 26.0
                    : (isCompact ? 34.0 : 46.0);
                final double appTitleSize = isUltraCompact
                    ? 17.0
                    : (isCompact ? 19.0 : 22.0);
                final double greetingSize = isUltraCompact
                    ? 12.0
                    : (isCompact ? 13.5 : 15.0);
                final double promptSize = isUltraCompact
                    ? 12.0
                    : (isCompact ? 13.0 : 14.0);

                final double dotSize = isUltraCompact
                    ? 11.0
                    : (isCompact ? 12.5 : 14.0);
                final double dotMargin = isUltraCompact ? 4.0 : 6.0;
                final double pillVPadding = isUltraCompact
                    ? 7.0
                    : (isCompact ? 9.0 : 12.0);
                final double pillHPadding = isUltraCompact ? 16.0 : 22.0;

                final double keySize = isUltraCompact
                    ? 50.0
                    : (isCompact ? 60.0 : 74.0);
                final double keyFontSize = isUltraCompact
                    ? 20.0
                    : (isCompact ? 23.0 : 27.0);
                final double keyIconSize = isUltraCompact
                    ? 21.0
                    : (isCompact ? 24.0 : 28.0);
                final double keyRowSpacing = isUltraCompact
                    ? 8.0
                    : (isCompact ? 12.0 : 16.0);

                final double vSpacing = isUltraCompact
                    ? 6.0
                    : (isCompact ? 10.0 : 14.0);

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // Top help button
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 8.0,
                            ),
                            child: Align(
                              alignment: Alignment.topRight,
                              child: InkWell(
                                onTap: () => _showHelpModal(context, isDark),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: isDark ? 0.08 : 0.55,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: isDark ? 0.15 : 0.7,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.help_outline_rounded,
                                        size: 16,
                                        color: const Color(0xFF0284C7)
                                            .withValues(alpha: 0.9),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Bantuan',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0284C7)
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const Spacer(flex: 1),

                          // App Icon Glass Squircle
                          Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: isDark ? 0.12 : 0.65,
                              ),
                              borderRadius: BorderRadius.circular(
                                isUltraCompact ? 16 : 24,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: isDark ? 0.2 : 0.8,
                                ),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                width: logoIconSize,
                                height: logoIconSize,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: const Color(0xFF0284C7),
                                  size: logoIconSize * 0.9,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: vSpacing),

                          // App Title RichText
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: appTitleSize,
                                fontWeight: FontWeight.bold,
                                color:
                                    theme.textTheme.titleLarge?.color ??
                                    (isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A)),
                              ),
                              children: const [
                                TextSpan(
                                  text: 'F ',
                                  style: TextStyle(
                                    color: Color(0xFF0284C7),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                TextSpan(text: 'Loafinwatch'),
                              ],
                            ),
                          ),

                          SizedBox(height: vSpacing),

                          // Greeting text
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28.0,
                            ),
                            child: Text(
                              greetingText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: greetingSize,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),

                          SizedBox(height: vSpacing * 1.2),

                          // Pill Container with 6 Dots Indicator
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shakeAnimation.value, 0),
                                child: child,
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: pillHPadding,
                                vertical: pillVPadding,
                              ),
                                decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: isDark ? 0.10 : 0.60,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: (_isError && _enteredPin.isNotEmpty)
                                      ? const Color(0xFFEF4444)
                                            .withValues(alpha: 0.6)
                                      : _isSuccess
                                      ? const Color(0xFF0EA5E9)
                                            .withValues(alpha: 0.8)
                                      : Colors.white.withValues(
                                          alpha: isDark ? 0.2 : 0.8,
                                        ),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(_pinLength, (index) {
                                  final isFilled = index < _enteredPin.length;
                                  return Container(
                                    margin: EdgeInsets.symmetric(
                                      horizontal: dotMargin,
                                    ),
                                    width: dotSize,
                                    height: dotSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: (_isError && _enteredPin.isNotEmpty)
                                          ? const Color(0xFFEF4444)
                                          : isFilled
                                          ? const Color(0xFF0EA5E9)
                                          : (isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.2,
                                                  )
                                                : const Color(0xFFCBD5E1)),
                                      boxShadow: isFilled && !_isError
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF0EA5E9)
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),

                          SizedBox(height: vSpacing),

                          // Prompt / Feedback Message
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28.0,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Row(
                                key: ValueKey<String>(
                                  promptText +
                                      (_isError
                                          ? 'err'
                                          : (_statusMessage != null && _statusMessage!.contains('terputus')
                                              ? 'warn'
                                              : 'ok')),
                                ),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isSuccess) ...[
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Color(0xFF0284C7),
                                    ),
                                    const SizedBox(width: 4),
                                  ] else if (_statusMessage != null && _statusMessage!.contains('terputus')) ...[
                                    const Icon(
                                      Icons.wifi_off_rounded,
                                      size: 16,
                                      color: Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 6),
                                  ] else if (_isError) ...[
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      size: 16,
                                      color: Color(0xFFEF4444),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      promptText,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: promptSize,
                                        fontWeight:
                                            _isError ||
                                                (_statusMessage != null && _statusMessage!.contains('terputus')) ||
                                                _isSuccess
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _isError
                                            ? const Color(0xFFEF4444)
                                            : (_statusMessage != null && _statusMessage!.contains('terputus'))
                                            ? const Color(0xFFF59E0B)
                                            : _isSuccess
                                            ? const Color(0xFF0284C7)
                                            : (isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(flex: 1),

                          // Liquid Glass Keypad Grid
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isUltraCompact ? 20.0 : 36.0,
                            ),
                            child: Column(
                              children: [
                                _buildKeypadRow(
                                  ['1', '2', '3'],
                                  isDark,
                                  keySize,
                                  keyFontSize,
                                ),
                                SizedBox(height: keyRowSpacing),
                                _buildKeypadRow(
                                  ['4', '5', '6'],
                                  isDark,
                                  keySize,
                                  keyFontSize,
                                ),
                                SizedBox(height: keyRowSpacing),
                                _buildKeypadRow(
                                  ['7', '8', '9'],
                                  isDark,
                                  keySize,
                                  keyFontSize,
                                ),
                                SizedBox(height: keyRowSpacing),
                                _buildBottomRow(
                                  isDark,
                                  keySize,
                                  keyFontSize,
                                  keyIconSize,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(
                            height: isUltraCompact
                                ? 10.0
                                : (isCompact ? 16.0 : 24.0),
                          ),

                          // Footer Links: Ganti Akun & Lupa PIN
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 36.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    ref
                                        .read(authNotifierProvider.notifier)
                                        .logout();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    'Ganti Akun',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _showForgotPinModal(context, isDark),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: const Text(
                                    'Lupa PIN?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: isUltraCompact ? 8.0 : 14.0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Floating iOS Dynamic Island Offline Warning Banner (Kapsul Notifikasi)
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 0,
            right: 0,
            child: const IosOfflineBanner(),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(
    List<String> digits,
    bool isDark,
    double size,
    double fontSize,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((digit) => _buildKeypadButton(digit, isDark, size, fontSize))
          .toList(),
    );
  }

  Widget _buildBottomRow(
    bool isDark,
    double size,
    double fontSize,
    double iconSize,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Biometric / Fingerprint Key
        if (_canUseBiometrics && !_isSetupMode)
          _buildActionButton(
            icon: Icons.fingerprint_rounded,
            color: const Color(0xFF0284C7),
            isDark: isDark,
            size: size,
            iconSize: iconSize,
            onTap: _authenticateWithBiometrics,
          )
        else
          SizedBox(width: size, height: size),

        // '0' Key
        _buildKeypadButton('0', isDark, size, fontSize),

        // Backspace Key
        _buildActionButton(
          icon: Icons.backspace_outlined,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          isDark: isDark,
          size: size,
          iconSize: iconSize,
          onTap: _onBackspacePressed,
        ),
      ],
    );
  }

  Widget _buildKeypadButton(
    String digit,
    bool isDark,
    double size,
    double fontSize,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onDigitPressed(digit),
        borderRadius: BorderRadius.circular(size / 2),
        splashColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
        highlightColor: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.65),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.85),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required bool isDark,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        splashColor: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
        highlightColor: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.55),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.75),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, color: color, size: iconSize),
          ),
        ),
      ),
    );
  }
}
