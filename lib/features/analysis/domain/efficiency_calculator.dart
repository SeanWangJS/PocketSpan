import '../../../../core/utils/date_utils_helper.dart';
import '../../tags/data/models/tag_model.dart';
import '../../tasks/data/models/task_model.dart';

enum EfficiencyPeriodType { week, month, year }

class EfficiencyTrendPoint {
  final String label;
  final int minutes;
  final bool isPeak;

  const EfficiencyTrendPoint({
    required this.label,
    required this.minutes,
    this.isPeak = false,
  });
}

class TagEffortBreakdown {
  final TagModel tag;
  final int minutes;
  final int taskCount;
  final double ratio;

  const TagEffortBreakdown({
    required this.tag,
    required this.minutes,
    required this.taskCount,
    required this.ratio,
  });
}

class TaskEfficiencyComparison {
  final TaskWithDetails item;
  final int periodEffortMinutes;
  final int totalEffortMinutes;
  final int spanDays;

  const TaskEfficiencyComparison({
    required this.item,
    required this.periodEffortMinutes,
    required this.totalEffortMinutes,
    required this.spanDays,
  });
}

class EfficiencyAnalysisResult {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalEffortMinutes;
  final int prevEffortMinutes;
  final double? effortChangeRate;
  final int completedCount;
  final int activeCount;
  final double? onTimeRate;
  final int avgEffortMinutes;
  final double avgSpanDays;
  final List<EfficiencyTrendPoint> trendPoints;
  final List<TagEffortBreakdown> tagBreakdowns;
  final List<TaskEfficiencyComparison> comparisons;

  const EfficiencyAnalysisResult({
    required this.periodStart,
    required this.periodEnd,
    required this.totalEffortMinutes,
    required this.prevEffortMinutes,
    required this.effortChangeRate,
    required this.completedCount,
    required this.activeCount,
    required this.onTimeRate,
    required this.avgEffortMinutes,
    required this.avgSpanDays,
    required this.trendPoints,
    required this.tagBreakdowns,
    required this.comparisons,
  });
}

/// Calculates weekly, monthly, and yearly personal efficiency metrics.
class EfficiencyCalculator {
  EfficiencyCalculator._();

  static ({DateTime start, DateTime end}) resolvePeriodRange({
    required EfficiencyPeriodType periodType,
    required DateTime anchorDate,
    bool weekStartsOnMonday = true,
  }) {
    final d = DateUtilsHelper.dateOnly(anchorDate);
    switch (periodType) {
      case EfficiencyPeriodType.week:
        final offset = weekStartsOnMonday ? (d.weekday - 1) : (d.weekday % 7);
        final start = d.subtract(Duration(days: offset));
        final end = start.add(const Duration(days: 6));
        return (start: start, end: end);
      case EfficiencyPeriodType.month:
        final start = DateTime(d.year, d.month, 1);
        final end = DateTime(d.year, d.month + 1, 0);
        return (start: start, end: end);
      case EfficiencyPeriodType.year:
        return (
          start: DateTime(d.year, 1, 1),
          end: DateTime(d.year, 12, 31),
        );
    }
  }

  static ({DateTime start, DateTime end}) resolvePreviousRange({
    required EfficiencyPeriodType periodType,
    required DateTime currentStart,
  }) {
    switch (periodType) {
      case EfficiencyPeriodType.week:
        final end = currentStart.subtract(const Duration(days: 1));
        return (start: end.subtract(const Duration(days: 6)), end: end);
      case EfficiencyPeriodType.month:
        final prevMonth = DateTime(currentStart.year, currentStart.month - 1, 1);
        return (
          start: prevMonth,
          end: DateTime(prevMonth.year, prevMonth.month + 1, 0),
        );
      case EfficiencyPeriodType.year:
        final y = currentStart.year - 1;
        return (start: DateTime(y, 1, 1), end: DateTime(y, 12, 31));
    }
  }

  static EfficiencyAnalysisResult calculate({
    required List<TaskWithDetails> tasks,
    required EfficiencyPeriodType periodType,
    required DateTime anchorDate,
    bool weekStartsOnMonday = true,
    DateTime? referenceToday,
  }) {
    final today = DateUtilsHelper.dateOnly(referenceToday ?? DateTime.now());
    final current = resolvePeriodRange(
      periodType: periodType,
      anchorDate: anchorDate,
      weekStartsOnMonday: weekStartsOnMonday,
    );
    final prev = resolvePreviousRange(
      periodType: periodType,
      currentStart: current.start,
    );

    int totalMinutes = 0;
    int prevMinutes = 0;
    final tagMinutes = <String, int>{};
    final tagObjects = <String, TagModel>{};
    final tagTaskSets = <String, Set<String>>{};
    final periodEffortByTask = <String, int>{};
    final dailyBucket = <String, int>{};
    final monthlyBucket = <int, int>{};

    int completedCount = 0;
    int activeCount = 0;
    int completedWithDdlCount = 0;
    int onTimeCount = 0;
    int completedEffortSum = 0;
    int completedSpanSum = 0;

    for (final item in tasks) {
      if (item.task.status == TaskStatus.archived) continue;

      final taskStart = DateUtilsHelper.dateOnly(item.task.createdDate);
      final taskEnd = item.effectiveSpanEnd(today);
      final overlapsPeriod =
          !taskEnd.isBefore(current.start) && !taskStart.isAfter(current.end);

      if (item.task.status == TaskStatus.completed &&
          item.task.completedDate != null) {
        final comp = DateUtilsHelper.dateOnly(item.task.completedDate!);
        if (!comp.isBefore(current.start) && !comp.isAfter(current.end)) {
          completedCount++;
          completedEffortSum += item.totalEffortMinutes;
          completedSpanSum += item.spanDays(today);
          if (item.task.dueDate != null) {
            completedWithDdlCount++;
            final dueDay = DateUtilsHelper.dateOnly(item.task.dueDate!);
            if (!comp.isAfter(dueDay)) {
              onTimeCount++;
            }
          }
        }
      } else if (item.task.status == TaskStatus.active && overlapsPeriod) {
        activeCount++;
      }

      for (final log in item.workLogs) {
        final d = DateUtilsHelper.dateOnly(log.workDate);
        if (!d.isBefore(current.start) && !d.isAfter(current.end)) {
          totalMinutes += log.durationMinutes;
          periodEffortByTask[item.task.id] =
              (periodEffortByTask[item.task.id] ?? 0) + log.durationMinutes;

          // Group pie chart by primary tag so ratios sum cleanly to 100%
          final pTag = item.primaryTag;
          tagObjects[pTag.id] = pTag;
          tagMinutes[pTag.id] = (tagMinutes[pTag.id] ?? 0) + log.durationMinutes;
          tagTaskSets.putIfAbsent(pTag.id, () => {}).add(item.task.id);

          final dKey = DateUtilsHelper.toDateKey(d);
          dailyBucket[dKey] = (dailyBucket[dKey] ?? 0) + log.durationMinutes;
          monthlyBucket[d.month] =
              (monthlyBucket[d.month] ?? 0) + log.durationMinutes;
        } else if (!d.isBefore(prev.start) && !d.isAfter(prev.end)) {
          prevMinutes += log.durationMinutes;
        }
      }
    }

    double? changeRate;
    if (prevMinutes > 0) {
      changeRate = ((totalMinutes - prevMinutes) / prevMinutes) * 100.0;
    }

    final onTimeRate = completedWithDdlCount > 0
        ? (onTimeCount / completedWithDdlCount) * 100.0
        : null;
    final avgEffort =
        completedCount > 0 ? (completedEffortSum / completedCount).round() : 0;
    final avgSpan =
        completedCount > 0 ? completedSpanSum / completedCount : 0.0;

    // Build trend points
    final rawPoints = <({String label, int minutes})>[];
    switch (periodType) {
      case EfficiencyPeriodType.week:
        const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
        for (int i = 0; i < 7; i++) {
          final d = current.start.add(Duration(days: i));
          final mins = dailyBucket[DateUtilsHelper.toDateKey(d)] ?? 0;
          rawPoints.add((label: '周${weekdays[d.weekday - 1]}', minutes: mins));
        }
      case EfficiencyPeriodType.month:
        final daysInMonth = current.end.day;
        for (int day = 1; day <= daysInMonth; day++) {
          final d = DateTime(current.start.year, current.start.month, day);
          final mins = dailyBucket[DateUtilsHelper.toDateKey(d)] ?? 0;
          rawPoints.add((label: '$day', minutes: mins));
        }
      case EfficiencyPeriodType.year:
        for (int m = 1; m <= 12; m++) {
          rawPoints.add((label: '$m月', minutes: monthlyBucket[m] ?? 0));
        }
    }

    final maxMins = rawPoints.fold<int>(
      0,
      (best, p) => p.minutes > best ? p.minutes : best,
    );
    final trendPoints = rawPoints
        .map((p) => EfficiencyTrendPoint(
              label: p.label,
              minutes: p.minutes,
              isPeak: maxMins > 0 && p.minutes == maxMins,
            ))
        .toList();

    // Build tag breakdowns
    final tagBreakdowns = tagMinutes.entries.map((e) {
      final ratio = totalMinutes > 0 ? e.value / totalMinutes : 0.0;
      return TagEffortBreakdown(
        tag: tagObjects[e.key]!,
        minutes: e.value,
        taskCount: tagTaskSets[e.key]?.length ?? 0,
        ratio: ratio,
      );
    }).toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

    // Build Span vs Effort comparison items for tasks touched or overlapping this period
    final comparisons = <TaskEfficiencyComparison>[];
    for (final item in tasks) {
      if (item.task.status == TaskStatus.archived) continue;
      final periodEffort = periodEffortByTask[item.task.id] ?? 0;
      final taskStart = DateUtilsHelper.dateOnly(item.task.createdDate);
      final taskEnd = item.effectiveSpanEnd(today);
      final overlaps =
          !taskEnd.isBefore(current.start) && !taskStart.isAfter(current.end);
      if (periodEffort > 0 || overlaps) {
        comparisons.add(TaskEfficiencyComparison(
          item: item,
          periodEffortMinutes: periodEffort,
          totalEffortMinutes: item.totalEffortMinutes,
          spanDays: item.spanDays(today),
        ));
      }
    }
    comparisons.sort((a, b) {
      final effortCmp = b.periodEffortMinutes.compareTo(a.periodEffortMinutes);
      if (effortCmp != 0) return effortCmp;
      return b.spanDays.compareTo(a.spanDays);
    });

    return EfficiencyAnalysisResult(
      periodStart: current.start,
      periodEnd: current.end,
      totalEffortMinutes: totalMinutes,
      prevEffortMinutes: prevMinutes,
      effortChangeRate: changeRate,
      completedCount: completedCount,
      activeCount: activeCount,
      onTimeRate: onTimeRate,
      avgEffortMinutes: avgEffort,
      avgSpanDays: avgSpan,
      trendPoints: trendPoints,
      tagBreakdowns: tagBreakdowns,
      comparisons: comparisons,
    );
  }
}
