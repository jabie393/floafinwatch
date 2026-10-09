import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../services/app_settings_service.dart';

class AutostartGuideModal extends StatefulWidget {
  final bool isDark;

  const AutostartGuideModal({super.key, required this.isDark});

  /// Menampilkan modal panduan izin.
  /// Mengembalikan true jika semua izin sudah aktif.
  static Future<bool> show(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AutostartGuideModal(isDark: isDark),
    );

    return result ?? false;
  }

  @override
  State<AutostartGuideModal> createState() => _AutostartGuideModalState();
}

class _AutostartGuideModalState extends State<AutostartGuideModal>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isAutostart = false;
  bool _isBattery = false;
  bool _isXiaomi = true;
  int _currentStep = 1; // 1 = Autostart, 2 = Battery Saver, 3 = All Granted
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus(isInitial: true);

    // Polling periodik tiap 1.5 detik selama modal aktif
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted) {
        _checkStatus();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User baru saja kembali ke aplikasi dari pengaturan Android
      _checkStatus();
    }
  }

  Future<void> _checkStatus({bool isInitial = false}) async {
    final res = await AppSettingsService.checkStatus();
    if (!mounted) return;

    final prevAutostart = _isAutostart;
    final prevBattery = _isBattery;

    final newAutostart = res.isAutostart;
    final newBattery = res.isIgnoringBattery;

    int nextStep = _currentStep;

    if (newAutostart && newBattery) {
      nextStep = 3; // Selesai semua
    } else if (!newAutostart) {
      nextStep = 1; // Perlu Autostart
    } else {
      nextStep = 2; // Autostart sudah aktif, tinggal baterai
    }

    // Beri haptic jika terjadi kemajuan izin
    if (!isInitial) {
      if (!prevAutostart && newAutostart) {
        HapticFeedback.heavyImpact();
      } else if (!prevBattery && newBattery) {
        HapticFeedback.heavyImpact();
      }
    }

    setState(() {
      _isLoading = false;
      _isAutostart = newAutostart;
      _isBattery = newBattery;
      _isXiaomi = res.isXiaomi;
      _currentStep = nextStep;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return LiquidGlassModalSheet(
      maxHeightRatio: 0.92,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: _isLoading
            ? const SizedBox(
                height: 250,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _buildCurrentStepWidget(isDark),
              ),
      ),
    );
  }

  Widget _buildCurrentStepWidget(bool isDark) {
    if (_currentStep == 3) {
      return _buildSuccessStep(isDark);
    } else if (_currentStep == 2) {
      return _buildBatteryStep(isDark);
    } else {
      return _buildAutostartStep(isDark);
    }
  }

  // ==========================================
  // STEP 1: Mulai Otomatis (Autostart)
  // ==========================================
  Widget _buildAutostartStep(bool isDark) {
    return Column(
      key: const ValueKey('step_autostart'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildProgressBar(current: 1, total: 2),
        const SizedBox(height: 14),

        // Step Badge
        _buildBadgePill(
          icon: Icons.power_settings_new_rounded,
          text: 'LANGKAH 1 DARI 2',
          gradientColors: [const Color(0xFF0284C7), const Color(0xFF2563EB)],
        ),
        const SizedBox(height: 12),

        // Title
        Text(
          'Aktifkan Mulai Otomatis',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Agar widget tetap update saat aplikasi ditutup/dibuang, izinkan "Mulai Otomatis" untuk F Loafinwatch.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 20),

        // Visual Simulator Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF141E2F).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.touch_app_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Petunjuk di Pengaturan:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          _isXiaomi
                              ? 'Cari "F Loafinwatch" di daftar, lalu aktifkan sakelarnya.'
                              : 'Buka menu Baterai / Latar Belakang dan izinkan Autostart.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Mock switch preview (Blue system palette)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            width: 26,
                            height: 26,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.widgets_rounded,
                                  size: 24,
                                  color: AppColors.primary,
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'F Loafinwatch',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const Text(
                              'Geser sakelar ke kanan (ON) ►',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF0284C7),
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Color(0xFF0284C7),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'ON',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Real-time Detection Status
        _buildDetectionStatusPill(
          statusText: 'Mendeteksi otomatis saat izin diberikan...',
          icon: Icons.sync_rounded,
        ),
        const SizedBox(height: 20),

        // Action Button: Buka Pengaturan Autostart
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            HapticFeedback.mediumImpact();
            await AppSettingsService.openAutostartSettings();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Buka Pengaturan Mulai Otomatis',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ==========================================
  // STEP 2: Penghemat Baterai -> Tidak Ada Pembatasan
  // ==========================================
  Widget _buildBatteryStep(bool isDark) {
    return Column(
      key: const ValueKey('step_battery'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildProgressBar(current: 2, total: 2),
        const SizedBox(height: 14),

        // Step Badge (Blue system palette)
        _buildBadgePill(
          icon: Icons.battery_charging_full_rounded,
          text: 'LANGKAH 2 DARI 2',
          gradientColors: [const Color(0xFF0284C7), const Color(0xFF2563EB)],
        ),
        const SizedBox(height: 12),

        // Title
        Text(
          'Penghemat Baterai: Tanpa Pembatasan',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Mulai Otomatis sudah aktif! Terakhir, setel baterai ke "Tidak Ada Pembatasan" agar sinkronisasi tidak dicekal.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 20),

        // Visual Selector Preview Card (Blue system palette)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF141E2F).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Opsi 1: Tidak Ada Pembatasan (Benar - Blue palette)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF0284C7),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.radio_button_checked_rounded,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tidak Ada Pembatasan (No Restrictions)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                          Text(
                            'Penghemat baterai tidak akan membatasi aktivitas widget di layar depan.',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PILIH INI',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Opsi 2: Hemat Baterai (Salah / Default)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_button_unchecked_rounded,
                      color: Colors.grey.shade500,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Hemat Baterai (Disarankan) ✕ (Memblokir widget saat app ditutup)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Detection Status Pill
        _buildDetectionStatusPill(
          statusText: 'Mendeteksi otomatis saat izin diberikan...',
          icon: Icons.sync_rounded,
        ),
        const SizedBox(height: 20),

        // Action Button: Setel Tidak Ada Pembatasan
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            HapticFeedback.mediumImpact();
            await AppSettingsService.requestIgnoreBatteryOptimizations();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text(
                  'Setel "Tidak Ada Pembatasan"',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ==========================================
  // STEP 3: SEMUA SUDAH AKTIF (SUKSES)
  // ==========================================
  Widget _buildSuccessStep(bool isDark) {
    return Column(
      key: const ValueKey('step_success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        // Big Glowing Animated Success Icon (Blue system palette)
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.45),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.check_rounded, color: Colors.white, size: 48),
          ),
        ),
        const SizedBox(height: 20),

        // Title
        Text(
          'Semua Izin Telah Aktif!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Luar biasa! F Loafinwatch kini memiliki izin penuh untuk terus memperbarui ketiga widget di layar depan secara real-time.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 22),

        // Status List Box (Blue system palette)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF141E2F).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF0284C7).withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            children: [
              _buildSuccessCheckItem(
                title: 'Mulai Otomatis (Autostart)',
                subtitle: 'Aktif di latar belakang',
                isDark: isDark,
              ),
              const Divider(height: 18),
              _buildSuccessCheckItem(
                title: 'Penghemat Baterai',
                subtitle: 'Tidak Ada Pembatasan (No Restrictions)',
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSuccessCheckItem({
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Color(0xFF0284C7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF0284C7).withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: const Text(
            'AKTIF ✓',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF38BDF8),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Helper Components
  // ==========================================
  Widget _buildProgressBar({required int current, required int total}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildProgressStepNode(
          step: 1,
          isCurrent: current == 1,
          isDone: current > 1,
        ),
        Container(
          width: 50,
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: current >= 2
                ? const Color(0xFF0284C7)
                : Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        _buildProgressStepNode(
          step: 2,
          isCurrent: current == 2,
          isDone: current > 2,
        ),
      ],
    );
  }

  Widget _buildProgressStepNode({
    required int step,
    required bool isCurrent,
    required bool isDone,
  }) {
    Color bg = Colors.grey.withValues(alpha: 0.25);
    Color textCol = Colors.grey;

    if (isDone) {
      bg = const Color(0xFF0284C7);
      textCol = Colors.white;
    } else if (isCurrent) {
      bg = const Color(0xFF0284C7);
      textCol = Colors.white;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : Text(
                '$step',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: textCol,
                ),
              ),
      ),
    );
  }

  Widget _buildBadgePill({
    required IconData icon,
    required String text,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionStatusPill({
    required String statusText,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0284C7),
            ),
          ),
        ],
      ),
    );
  }
}
