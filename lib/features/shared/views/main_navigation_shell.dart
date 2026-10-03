import 'package:floafinwatch/core/constants/app_colors.dart';
import 'package:floafinwatch/core/widgets/liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainNavigationShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Full screen scrollable content behind floating dock
          Positioned.fill(
            child: navigationShell,
          ),

          // Floating Apple iOS 18 Liquid Glass Dock
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset > 0 ? bottomInset + 4 : 16,
            child: LiquidGlass(
              borderRadius: 40,
              blur: 24,
              opacity: 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: SizedBox(
                height: 58,
                child: Row(
                  children: [
                    Expanded(
                      child: _FloatingNavBarItem(
                        icon: Icons.grid_view_rounded,
                        label: 'Utama',
                        isSelected: navigationShell.currentIndex == 0,
                        onTap: () => _onItemTapped(0),
                        isDark: isDark,
                      ),
                    ),
                    Expanded(
                      child: _FloatingNavBarItem(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Transaksi',
                        isSelected: navigationShell.currentIndex == 1,
                        onTap: () => _onItemTapped(1),
                        isDark: isDark,
                      ),
                    ),
                    Expanded(
                      child: _FloatingNavBarItem(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Payouts',
                        isSelected: navigationShell.currentIndex == 2,
                        onTap: () => _onItemTapped(2),
                        isDark: isDark,
                      ),
                    ),
                    Expanded(
                      child: _FloatingNavBarItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Profile',
                        isSelected: navigationShell.currentIndex == 3,
                        onTap: () => _onItemTapped(3),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _FloatingNavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight;
    final activeTextColor = isDark ? Colors.white : AppColors.primary;
    final itemColor = isSelected ? activeTextColor : inactiveColor;
    final activeBgColor = isDark
        ? const Color(0xFF2563EB)
        : const Color(0xFFE2EDFE).withValues(alpha: 0.95);
    final activeBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.95);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: isSelected
              ? Border.all(
                  color: activeBorderColor,
                  width: 1.0,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.35 : 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: itemColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: itemColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
