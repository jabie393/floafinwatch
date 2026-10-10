import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/widgets/liquid_glass.dart';

class NotificationSettingsModal extends StatefulWidget {
  final bool isDark;

  const NotificationSettingsModal({super.key, required this.isDark});

  /// Menampilkan modal pengaturan notifikasi.
  static Future<void> show(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotificationSettingsModal(isDark: isDark),
    );
  }

  @override
  State<NotificationSettingsModal> createState() => _NotificationSettingsModalState();
}

class _NotificationSettingsModalState extends State<NotificationSettingsModal> {
  final _storage = SecureStorageService();
  bool _isLoading = true;
  bool _isTransactionEnabled = true;
  bool _isPayoutEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final tx = await _storage.isTransactionNotificationEnabled();
    final payout = await _storage.isPayoutNotificationEnabled();
    if (mounted) {
      setState(() {
        _isTransactionEnabled = tx;
        _isPayoutEnabled = payout;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTransaction(bool val) async {
    HapticFeedback.lightImpact();
    setState(() => _isTransactionEnabled = val);
    await _storage.setTransactionNotificationEnabled(val);
  }

  Future<void> _togglePayout(bool val) async {
    HapticFeedback.lightImpact();
    setState(() => _isPayoutEnabled = val);
    await _storage.setPayoutNotificationEnabled(val);
  }

  Future<void> _toggleAll(bool val) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isTransactionEnabled = val;
      _isPayoutEnabled = val;
    });
    await _storage.setTransactionNotificationEnabled(val);
    await _storage.setPayoutNotificationEnabled(val);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final allEnabled = _isTransactionEnabled && _isPayoutEnabled;

    return LiquidGlassModalSheet(
      maxHeightRatio: 0.88,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),

                    // Top Header (Centered, matching Widget F Loafinwatch in Image 2)
                    Center(
                      child: Text(
                        'Notifikasi Aplikasi',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Kustomisasi pemberitahuan push notification realtime',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Master Toggle (Inspirasi blu: "Izinkan semua notifikasi")
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Izinkan Semua Notifikasi',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  'Aktifkan atau nonaktifkan semua notifikasi sekaligus',
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
                          const SizedBox(width: 8),
                          Switch.adaptive(
                            value: allEnabled,
                            onChanged: _toggleAll,
                            activeColor: const Color(0xFF0284C7),
                            activeTrackColor: isDark
                                ? const Color(0xFF0284C7).withValues(alpha: 0.45)
                                : const Color(0xFFBAE6FD),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Subtitle Section
                    Text(
                      'PILIHAN JENIS NOTIFIKASI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Toggle 1: Transaksi
                    _NotificationSettingTile(
                      isDark: isDark,
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xFF10B981),
                      iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.14),
                      title: 'Transaksi Finansial',
                      subtitle: 'Pemberitahuan saat ada transaksi berhasil masuk dan hak developer bertambah',
                      value: _isTransactionEnabled,
                      onChanged: _toggleTransaction,
                    ),
                    const SizedBox(height: 12),

                    // Toggle 2: Payout
                    _NotificationSettingTile(
                      isDark: isDark,
                      icon: Icons.payments_rounded,
                      iconColor: const Color(0xFF0284C7),
                      iconBgColor: const Color(0xFF0284C7).withValues(alpha: 0.14),
                      title: 'Pencairan Dana (Payout)',
                      subtitle: 'Pemberitahuan antrean pencairan dana, pembayaran QRIS, & status siap dikonfirmasi',
                      value: _isPayoutEnabled,
                      onChanged: _togglePayout,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }
}

class _NotificationSettingTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationSettingTile({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF0284C7),
            activeTrackColor: isDark
                ? const Color(0xFF0284C7).withValues(alpha: 0.45)
                : const Color(0xFFBAE6FD),
          ),
        ],
      ),
    );
  }
}
