import 'package:floafinwatch/core/config/app_config.dart';
import 'package:floafinwatch/core/constants/app_colors.dart';
import 'package:floafinwatch/core/theme/theme_notifier.dart';
import 'package:floafinwatch/core/widgets/liquid_glass.dart';
import 'package:floafinwatch/features/auth/presentation/auth_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userName = user?.name ?? 'Developer';
    final initials = userName.trim().split(' ').map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').take(2).join();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: AmbientLiquidBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            children: [
              // Top Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profil & Pengaturan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kelola preferensi tema dan akun developer',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Liquid Glass User Info Card
              LiquidGlass(
                borderRadius: 22,
                blur: 18,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: isDark ? 0.35 : 0.9),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initials.isNotEmpty ? initials : 'RD',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? 'email@domain.com',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.16) : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.35) : AppColors.borderLight,
                                width: 0.85,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: 12,
                                  color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Developer',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
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
              const SizedBox(height: 20),

              // THEME SELECTOR SECTION (Dark Mode, Light Mode, System)
              Text(
                'Tema Tampilan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sesuaikan mode warna dengan preferensi Anda',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
              ),
              const SizedBox(height: 10),

              // Liquid Glass Theme Selector Container
              LiquidGlass(
                borderRadius: 20,
                blur: 18,
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    _ThemeOptionTile(
                      title: 'Otomatis (Ikuti Sistem)',
                      subtitle: 'Menyesuaikan otomatis dengan pengaturan perangkat',
                      icon: Icons.brightness_auto_rounded,
                      isSelected: themeMode == ThemeMode.system,
                      onTap: () {
                        ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                      },
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _ThemeOptionTile(
                      title: 'Mode Gelap (Dark Mode)',
                      subtitle: 'Warna latar gelap, nyaman di mata saat malam',
                      icon: Icons.dark_mode_rounded,
                      isSelected: themeMode == ThemeMode.dark,
                      onTap: () {
                        ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                      },
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _ThemeOptionTile(
                      title: 'Mode Terang (Light Mode)',
                      subtitle: 'Warna latar bersih dan cerah dengan kontras tinggi',
                      icon: Icons.light_mode_rounded,
                      isSelected: themeMode == ThemeMode.light,
                      onTap: () {
                        ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Server & System Details Card
              Text(
                'Informasi Sistem',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 10),
              LiquidGlass(
                borderRadius: 20,
                blur: 18,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _InfoRow(
                      label: 'Status Akun',
                      valueWidget: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF10B981).withValues(alpha: 0.16) : AppColors.emeraldBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? const Color(0xFF10B981).withValues(alpha: 0.35) : AppColors.emeraldBorder,
                            width: 0.85,
                          ),
                        ),
                        child: Text(
                          'Aktif',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.emeraldDarkText : AppColors.emeraldText,
                          ),
                        ),
                      ),
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _InfoRow(
                      label: 'Aplikasi',
                      value: 'F Loafinwatch v1.0.0',
                      isDark: isDark,
                    ),
                    const Divider(height: 16),
                    _InfoRow(
                      label: 'Lingkungan',
                      value: 'CIB Production / Beta',
                      isDark: isDark,
                    ),
                    const Divider(height: 18),
                    _InfoRow(
                      label: 'Base API URL',
                      value: AppConfig.baseUrl,
                      isDark: isDark,
                      isMonospace: true,
                      isStacked: true,
                      onCopy: () {
                        Clipboard.setData(const ClipboardData(text: AppConfig.baseUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Base API URL berhasil disalin',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showLogoutConfirmation(context, isDark, ref),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB91C1C).withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, size: 19, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Keluar dari Akun',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, bool isDark, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return LiquidGlassModalSheet(
          maxHeightRatio: 0.65,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
                        : const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF991B1B).withValues(alpha: 0.5)
                          : const Color(0xFFFECACA),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.logout_rounded,
                      size: 24,
                      color: isDark
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Konfirmasi Logout',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Apakah Anda yakin ingin keluar dari sesi akun aplikasi F Loafinwatch?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Batal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(ctx);
                          ref.read(authNotifierProvider.notifier).logout();
                        },
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB91C1C)
                                    .withValues(alpha: 0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'Ya, Keluar Akun',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _ThemeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Liquid Bubble Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.primary.withValues(alpha: 0.25) : AppColors.primaryLight)
                    : (isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.slateBg),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? AppColors.primary.withValues(alpha: 0.5) : AppColors.primaryLight)
                      : Colors.transparent,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight),
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
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool isDark;
  final bool isMonospace;
  final bool isStacked;
  final VoidCallback? onCopy;

  const _InfoRow({
    required this.label,
    this.value,
    this.valueWidget,
    required this.isDark,
    this.isMonospace = false,
    this.isStacked = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    if (isStacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              if (onCopy != null)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onCopy,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Salin',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 0.9,
              ),
            ),
            child: SelectableText(
              value ?? '',
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: isMonospace ? 'monospace' : null,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(width: 12),
        if (valueWidget != null)
          Flexible(child: valueWidget!)
        else
          Flexible(
            child: Text(
              value ?? '',
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: isMonospace ? 'monospace' : null,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
      ],
    );
  }
}
