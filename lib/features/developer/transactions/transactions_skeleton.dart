import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class TransactionsListSkeleton extends StatelessWidget {
  final bool isDark;
  final int count;

  const TransactionsListSkeleton({
    super.key,
    required this.isDark,
    this.count = 6,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? const Color(0xFF1E2D44) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF2C3E5B) : const Color(0xFFF1F5F9);

    final cardBg = isDark
        ? const Color(0xFF121D2F).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.85);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cardBorder, width: 1),
              ),
              child: Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circle Avatar Icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Payer & Service info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 130,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 85,
                            height: 11,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Amount & Hak Dev Label
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 80,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 45,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: count,
        ),
      ),
    );
  }
}
