import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../domain/efficiency_calculator.dart';

/// Soft pastel bar chart displaying daily or monthly effort minutes across a period.
class EffortTrendBarChart extends StatelessWidget {
  final List<EfficiencyTrendPoint> points;
  final double height;

  const EffortTrendBarChart({
    super.key,
    required this.points,
    this.height = 156,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxMinutes = points.fold<int>(
      0,
      (best, p) => p.minutes > best ? p.minutes : best,
    );

    if (points.isEmpty || maxMinutes == 0) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            '本周期暂无投入工时记录',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(points.length, (idx) {
          final p = points[idx];
          final ratio = maxMinutes > 0 ? p.minutes / maxMinutes : 0.0;
          final showLabel = points.length <= 12 ||
              idx == 0 ||
              idx == points.length - 1 ||
              (idx + 1) % 5 == 0;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: points.length > 20 ? 1.0 : 3.5,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (p.isPeak)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        DurationFormatter.formatCompact(p.minutes),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 3),
                  Flexible(
                    child: LayoutBuilder(
                      builder: (_, barConstraints) {
                        final maxBarH = math.max(8.0, barConstraints.maxHeight);
                        final barH = p.minutes > 0
                            ? math.max(5.0, maxBarH * ratio)
                            : 3.0;
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: barH,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: p.minutes == 0
                                  ? (isDark
                                      ? const Color(0xFF283040)
                                      : const Color(0xFFF0F2F7))
                                  : (p.isPeak
                                      ? AppColors.primary
                                      : AppColors.primary.withValues(
                                          alpha: isDark ? 0.55 : 0.42,
                                        )),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 14,
                    child: showLabel
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              p.label,
                              style: TextStyle(
                                fontSize: 10,
                                color: p.isPeak
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: p.isPeak
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
