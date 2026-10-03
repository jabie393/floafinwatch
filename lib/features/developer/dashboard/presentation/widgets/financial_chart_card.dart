import 'package:fl_chart/fl_chart.dart';
import 'package:floafinwatch/core/constants/app_colors.dart';
import 'package:floafinwatch/core/utils/currency_formatter.dart';
import 'package:floafinwatch/core/widgets/liquid_glass.dart';
import 'package:floafinwatch/features/developer/dashboard/domain/dashboard_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard_notifier.dart';

class FinancialChartCard extends ConsumerWidget {
  final FinancialChartData chartData;

  const FinancialChartCard({
    super.key,
    required this.chartData,
  });

  String _formatYAxis(double value) {
    if (value <= 0) return '';
    final rounded = value.round();
    if (rounded >= 1000000000) {
      final val = rounded / 1000000000;
      final s = (val == val.roundToDouble()) ? '${val.toInt()}' : val.toStringAsFixed(1);
      return 'Rp $s M';
    } else if (rounded >= 1000000) {
      final val = rounded / 1000000;
      final s = (val == val.roundToDouble()) ? '${val.toInt()}' : val.toStringAsFixed(1);
      return 'Rp $s Jt';
    } else if (rounded >= 1000) {
      final val = rounded / 1000;
      final s = (val == val.roundToDouble()) ? '${val.toInt()}' : val.toStringAsFixed(1);
      return 'Rp $s Rb';
    }
    return 'Rp $rounded';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedPeriod = ref.watch(selectedPeriodProvider);

    final spots = <FlSpot>[];
    for (int i = 0; i < chartData.values.length; i++) {
      spots.add(FlSpot(i.toDouble(), chartData.values[i]));
    }

    final double maxY = chartData.values.isEmpty
        ? 100000.0
        : chartData.values.reduce((a, b) => a > b ? a : b) * 1.2;

    return LiquidGlass(
      borderRadius: 24,
      blur: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Title
          Text(
            'Tren Pencairan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Riwayat dana hak dev dicairkan',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
          const SizedBox(height: 14),

          // Liquid Glass Period Filter Chips (ala Apple Focus pill)
          Row(
            children: [
              _PeriodChip(
                label: '7 Hari',
                value: '7d',
                isSelected: selectedPeriod == '7d',
                onSelected: (val) {
                  ref.read(selectedPeriodProvider.notifier).setPeriod('7d');
                  ref.read(dashboardNotifierProvider.notifier).loadData();
                },
              ),
              const SizedBox(width: 8),
              _PeriodChip(
                label: '30 Hari',
                value: '30d',
                isSelected: selectedPeriod == '30d',
                onSelected: (val) {
                  ref.read(selectedPeriodProvider.notifier).setPeriod('30d');
                  ref.read(dashboardNotifierProvider.notifier).loadData();
                },
              ),
              const SizedBox(width: 8),
              _PeriodChip(
                label: 'Bulan Ini',
                value: 'month',
                isSelected: selectedPeriod == 'month',
                onSelected: (val) {
                  ref.read(selectedPeriodProvider.notifier).setPeriod('month');
                  ref.read(dashboardNotifierProvider.notifier).loadData();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart canvas
          SizedBox(
            height: 200,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada data pada periode ini',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (touchedSpot) => isDark
                              ? const Color(0xFF0F172A).withValues(alpha: 0.95)
                              : const Color(0xFF1E293B),
                          tooltipBorderRadius: BorderRadius.circular(10),
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          tooltipBorder: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.25),
                            width: 0.85,
                          ),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.x.toInt();
                              final dateLabel = (index >= 0 && index < chartData.labels.length)
                                  ? chartData.labels[index]
                                  : '';
                              return LineTooltipItem(
                                dateLabel.isNotEmpty ? '$dateLabel\n' : '',
                                TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                children: [
                                  TextSpan(
                                    text: CurrencyFormatter.formatRupiah(spot.y),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                        ),
                        getTouchedSpotIndicator: (barData, spotIndexes) {
                          return spotIndexes.map((index) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                strokeWidth: 1.5,
                                dashArray: [4, 4],
                              ),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 6,
                                    color: AppColors.primary,
                                    strokeWidth: 2.5,
                                    strokeColor: Colors.white,
                                  );
                                },
                              ),
                            );
                          }).toList();
                        },
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: (maxY / 4).clamp(1.0, double.infinity),
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: isDark
                              ? AppColors.borderDark.withValues(alpha: 0.5)
                              : AppColors.borderLight,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 58,
                            interval: (maxY / 4).clamp(1.0, double.infinity),
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  _formatYAxis(value),
                                  maxLines: 1,
                                  softWrap: false,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? AppColors.textMutedDark
                                        : AppColors.textMutedLight,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            interval: (chartData.labels.length / 5).clamp(1.0, 10.0),
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < chartData.labels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    chartData.labels[index],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? AppColors.textMutedDark
                                          : AppColors.textMutedLight,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (chartData.labels.length - 1).toDouble().clamp(0.0, double.infinity),
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color: AppColors.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.28),
                                AppColors.primary.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final ValueChanged<String> onSelected;

  const _PeriodChip({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LiquidGlassPill(
      isSelected: isSelected,
      onTap: () => onSelected(value),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? (isDark ? Colors.white : AppColors.primary)
              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
      ),
    );
  }
}
