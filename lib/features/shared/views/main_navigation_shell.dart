import 'package:floafinwatch/core/constants/app_colors.dart';
import 'package:floafinwatch/core/network/reverb_service.dart';
import 'package:floafinwatch/core/widgets/liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'ios_offline_banner.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget>? children;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
    this.children,
  });

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    if (widget.children != null && widget.children!.isNotEmpty) {
      _pageController = PageController(
        initialPage: widget.navigationShell.currentIndex,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reverbServiceProvider).init();
    });
  }

  @override
  void didUpdateWidget(MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex !=
        oldWidget.navigationShell.currentIndex) {
      if (_pageController != null &&
          _pageController!.hasClients &&
          _pageController!.page?.round() !=
              widget.navigationShell.currentIndex) {
        _pageController!.animateToPage(
          widget.navigationShell.currentIndex,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index != widget.navigationShell.currentIndex) {
      HapticFeedback.selectionClick();
      widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );
      if (_pageController != null && _pageController!.hasClients) {
        _pageController!.animateToPage(
          index,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reverbServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    Widget bodyContent;
    if (widget.children != null &&
        widget.children!.isNotEmpty &&
        _pageController != null) {
      bodyContent = PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          if (index != widget.navigationShell.currentIndex) {
            HapticFeedback.selectionClick();
            widget.navigationShell.goBranch(index, initialLocation: false);
          }
        },
        children: widget.children!
            .map((child) => _KeepAliveBranch(child: child))
            .toList(),
      );
    } else {
      bodyContent = widget.navigationShell;
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Full screen scrollable content behind floating dock
          Positioned.fill(child: bodyContent),

          // Floating Apple iOS 18 Liquid Glass Dock
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset > 0 ? bottomInset + 4 : 16,
            child: LiquidGlass(
              borderRadius: 40,
              blur: 24,
              opacity: 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: SizedBox(
                height: 56,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / 4;

                    return AnimatedBuilder(
                      animation: _pageController ?? AlwaysStoppedAnimation(0),
                      builder: (context, _) {
                        double pageProgress = widget
                            .navigationShell
                            .currentIndex
                            .toDouble();
                        if (_pageController != null &&
                            _pageController!.hasClients &&
                            _pageController!.position.haveDimensions) {
                          pageProgress = _pageController!.page ?? pageProgress;
                        }

                        // Position follows exact finger swipe or tab switch
                        final pillLeft = pageProgress * itemWidth;

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // iOS Fluid Sliding Active Pill Indicator
                            Positioned(
                              left: pillLeft,
                              top: 2,
                              bottom: 2,
                              width: itemWidth,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isDark
                                      ? const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFF3B82F6),
                                            Color(0xFF2563EB),
                                          ],
                                        )
                                      : LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            const Color(0xFFEFF6FF),
                                            const Color(0xFFDBEAFE)
                                                .withValues(alpha: 0.95),
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.28)
                                        : Colors.white.withValues(alpha: 0.95),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2563EB,
                                      ).withValues(alpha: isDark ? 0.32 : 0.16),
                                      blurRadius: 6,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 1.5),
                                    ),
                                    if (!isDark)
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.03,
                                        ),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Navigation Items Row
                            Row(
                              children: [
                                Expanded(
                                  child: _FloatingNavBarItem(
                                    icon: Icons.grid_view_outlined,
                                    activeIcon: Icons.grid_view_rounded,
                                    label: 'Dashboard',
                                    progress: (1.0 - (pageProgress - 0).abs())
                                        .clamp(0.0, 1.0),
                                    onTap: () => _onItemTapped(0),
                                    isDark: isDark,
                                  ),
                                ),
                                Expanded(
                                  child: _FloatingNavBarItem(
                                    icon: Icons.swap_horiz_rounded,
                                    activeIcon: Icons.swap_horiz_rounded,
                                    label: 'Transaksi',
                                    progress: (1.0 - (pageProgress - 1).abs())
                                        .clamp(0.0, 1.0),
                                    onTap: () => _onItemTapped(1),
                                    isDark: isDark,
                                  ),
                                ),
                                Expanded(
                                  child: _FloatingNavBarItem(
                                    icon: Icons.account_balance_wallet_outlined,
                                    activeIcon:
                                        Icons.account_balance_wallet_rounded,
                                    label: 'Payouts',
                                    progress: (1.0 - (pageProgress - 2).abs())
                                        .clamp(0.0, 1.0),
                                    onTap: () => _onItemTapped(2),
                                    isDark: isDark,
                                  ),
                                ),
                                Expanded(
                                  child: _FloatingNavBarItem(
                                    icon: Icons.person_outline_rounded,
                                    activeIcon: Icons.person_rounded,
                                    label: 'Profil',
                                    progress: (1.0 - (pageProgress - 3).abs())
                                        .clamp(0.0, 1.0),
                                    onTap: () => _onItemTapped(3),
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          // Floating iOS Dynamic Island Offline Warning Banner
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
}

class _FloatingNavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final double progress; // 0.0 (inactive) to 1.0 (active)
  final VoidCallback onTap;
  final bool isDark;

  const _FloatingNavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.progress,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDark
        ? AppColors.textMutedDark
        : AppColors.textSecondaryLight;
    final activeTextColor = isDark ? Colors.white : AppColors.primary;
    final itemColor =
        Color.lerp(inactiveColor, activeTextColor, progress) ?? inactiveColor;
    final isSelected = progress >= 0.5;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(
              scale: 1.0 + (0.08 * progress),
              child: Icon(
                isSelected ? activeIcon : icon,
                size: 21,
                color: itemColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: itemColor,
                letterSpacing: -0.1,
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

class _KeepAliveBranch extends StatefulWidget {
  final Widget child;
  const _KeepAliveBranch({required this.child});

  @override
  State<_KeepAliveBranch> createState() => _KeepAliveBranchState();
}

class _KeepAliveBranchState extends State<_KeepAliveBranch>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
