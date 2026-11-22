import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/widgets/pocket_sheet_components.dart';
import '../../../tags/data/models/tag_model.dart';
import '../../../tasks/data/models/task_model.dart';
import '../../../tasks/data/repositories/task_repository.dart';
import '../../../tasks/presentation/screens/task_detail_screen.dart';
import '../../domain/efficiency_calculator.dart';
import '../widgets/donut_chart_widget.dart';
import '../widgets/effort_trend_bar_chart.dart';

/// Efficiency analytics screen supporting Week / Month / Year switching,
/// Tag breakdown, Effort Trend chart, and Span-vs-Effort comparison.
class AnalysisScreen extends StatefulWidget {
  final List<TaskWithDetails> tasks;
  final List<TagModel> tags;
  final TaskRepository taskRepository;
  final bool weekStartsOnMonday;
  final Future<void> Function() onDataChanged;

  const AnalysisScreen({
    super.key,
    required this.tasks,
    required this.tags,
    required this.taskRepository,
    required this.weekStartsOnMonday,
    required this.onDataChanged,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  EfficiencyPeriodType _periodType = EfficiencyPeriodType.month;
  DateTime _anchorDate = DateTime.now();

  bool get _isCurrentPeriod {
    final nowRange = EfficiencyCalculator.resolvePeriodRange(
      periodType: _periodType,
      anchorDate: DateTime.now(),
      weekStartsOnMonday: widget.weekStartsOnMonday,
    );
    final selectedRange = EfficiencyCalculator.resolvePeriodRange(
      periodType: _periodType,
      anchorDate: _anchorDate,
      weekStartsOnMonday: widget.weekStartsOnMonday,
    );
    return nowRange.start == selectedRange.start;
  }

  void _stepPeriod(int delta) {
    setState(() {
      switch (_periodType) {
        case EfficiencyPeriodType.week:
          _anchorDate = _anchorDate.add(Duration(days: 7 * delta));
        case EfficiencyPeriodType.month:
          _anchorDate = DateTime(_anchorDate.year, _anchorDate.month + delta, 1);
        case EfficiencyPeriodType.year:
          _anchorDate = DateTime(_anchorDate.year + delta, 1, 1);
      }
    });
  }

  void _resetToCurrent() {
    setState(() => _anchorDate = DateTime.now());
  }

  String _formatPeriodLabel(EfficiencyAnalysisResult res) {
    switch (_periodType) {
      case EfficiencyPeriodType.week:
        return '${res.periodStart.month}.${res.periodStart.day} ~ ${res.periodEnd.month}.${res.periodEnd.day}';
      case EfficiencyPeriodType.month:
        return '${res.periodStart.year}年${res.periodStart.month}月';
      case EfficiencyPeriodType.year:
        return '${res.periodStart.year}年';
    }
  }

  void _openTagDrillDown(TagModel tag) {
    final matching = widget.tasks
        .where((item) =>
            item.task.status != TaskStatus.archived && item.hasTag(tag.id))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return PocketSheetContainer(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PocketSheetHeader(title: '「${tag.name}」关联事项 (${matching.length})'),
                const SizedBox(height: 12),
                Expanded(
                  child: matching.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无关联事项',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          itemCount: matching.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, idx) {
                            final item = matching[idx];
                            final pDark =
                                AppColors.parseHex(item.primaryTag.darkColorHex);
                            final pLight = AppColors.parseHex(
                              item.primaryTag.lightColorHex,
                            );
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: pLight,
                                child: Icon(
                                  iconForTag(item.primaryTag),
                                  size: 16,
                                  color: pDark,
                                ),
                              ),
                              title: Text(
                                item.task.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '跨度 ${item.spanDays()}天 · 累计投入 ${DurationFormatter.format(item.totalEffortMinutes)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.pop(ctx);
                                _openTaskDetail(item.task.id);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openTaskDetail(String taskId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          taskId: taskId,
          taskRepository: widget.taskRepository,
          availableTags: widget.tags,
          onTaskChanged: widget.onDataChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final result = EfficiencyCalculator.calculate(
      tasks: widget.tasks,
      periodType: _periodType,
      anchorDate: _anchorDate,
      weekStartsOnMonday: widget.weekStartsOnMonday,
    );

    final periodLabel = _formatPeriodLabel(result);
    final comparePrefix = switch (_periodType) {
      EfficiencyPeriodType.week => '较上周',
      EfficiencyPeriodType.month => '较上月',
      EfficiencyPeriodType.year => '较去年',
    };

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            // Header + [周] [月] [年] switcher
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '效率统计',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '持续跨度 × 实际工时，量化办事效率',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 32,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E2430)
                        : const Color(0xFFECEFF5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PeriodChip(
                        label: '周',
                        selected: _periodType == EfficiencyPeriodType.week,
                        onTap: () => setState(
                          () => _periodType = EfficiencyPeriodType.week,
                        ),
                      ),
                      _PeriodChip(
                        label: '月',
                        selected: _periodType == EfficiencyPeriodType.month,
                        onTap: () => setState(
                          () => _periodType = EfficiencyPeriodType.month,
                        ),
                      ),
                      _PeriodChip(
                        label: '年',
                        selected: _periodType == EfficiencyPeriodType.year,
                        onTap: () => setState(
                          () => _periodType = EfficiencyPeriodType.year,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 1. Hero Total Effort Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _stepPeriod(-1),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$periodLabel 累计投入',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _stepPeriod(1),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (!_isCurrentPeriod) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _resetToCurrent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              '今',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DurationFormatter.format(result.totalEffortMinutes),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: _ChangeBadge(
                          prefix: comparePrefix,
                          changeRate: result.effortChangeRate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MetricCol(
                        label: '完成事项',
                        value: '${result.completedCount} 项',
                      ),
                      _MetricCol(
                        label: '按期率',
                        value: result.onTimeRate == null
                            ? '--'
                            : '${result.onTimeRate!.toStringAsFixed(0)}%',
                      ),
                      _MetricCol(
                        label: '均工时',
                        value: result.avgEffortMinutes == 0
                            ? '--'
                            : DurationFormatter.format(result.avgEffortMinutes),
                      ),
                      _MetricCol(
                        label: '均跨度',
                        value: result.avgSpanDays == 0
                            ? '--'
                            : '${result.avgSpanDays.toStringAsFixed(1)} 天',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Tag Breakdown Donut Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tag 分类工时分布',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (result.tagBreakdowns.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          '本周期暂无标签工时数据',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        EffortDonutChart(
                          segments: result.tagBreakdowns
                              .map(
                                (b) => EffortDonutSegment(
                                  value: b.minutes.toDouble(),
                                  color: AppColors.parseHex(b.tag.darkColorHex),
                                  label: b.tag.name,
                                ),
                              )
                              .toList(),
                          centerLabel: '总投入',
                          centerValue: DurationFormatter.formatCompact(
                            result.totalEffortMinutes,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            children: result.tagBreakdowns.map((b) {
                              final tDark =
                                  AppColors.parseHex(b.tag.darkColorHex);
                              final pct = (b.ratio * 100).toStringAsFixed(0);
                              return InkWell(
                                onTap: () => _openTagDrillDown(b.tag),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: tDark,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          b.tag.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '$pct% · ${DurationFormatter.format(b.minutes)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Effort Trend Bar Chart Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '工时投入趋势',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  EffortTrendBarChart(points: result.trendPoints),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4. Span vs Effort Dual-Bar Comparison Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '持续跨度 vs 实际工时',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '浅条=跨度 · 深条=投入',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (result.comparisons.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          '本周期暂无关联事项',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ...result.comparisons.take(8).map((c) {
                      final maxSpan = result.comparisons
                          .map((e) => e.spanDays)
                          .reduce((a, b) => a > b ? a : b)
                          .clamp(1, 3650);
                      final maxEffort = result.comparisons
                          .map((e) => e.totalEffortMinutes)
                          .reduce((a, b) => a > b ? a : b)
                          .clamp(1, 1000000);
                      final pDark =
                          AppColors.parseHex(c.item.primaryTag.darkColorHex);
                      final pLight =
                          AppColors.parseHex(c.item.primaryTag.lightColorHex);

                      return InkWell(
                        onTap: () => _openTaskDetail(c.item.task.id),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.item.task.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '跨${c.spanDays}天 · 投${DurationFormatter.format(c.totalEffortMinutes)}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (c.spanDays / maxSpan).clamp(0.06, 1.0),
                                  minHeight: 6,
                                  backgroundColor: isDark
                                      ? const Color(0xFF283040)
                                      : const Color(0xFFF3F4F8),
                                  valueColor: AlwaysStoppedAnimation(pLight),
                                ),
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: c.totalEffortMinutes == 0
                                      ? 0.0
                                      : (c.totalEffortMinutes / maxEffort)
                                          .clamp(0.06, 1.0),
                                  minHeight: 6,
                                  backgroundColor: isDark
                                      ? const Color(0xFF283040)
                                      : const Color(0xFFF3F4F8),
                                  valueColor: AlwaysStoppedAnimation(pDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  final String prefix;
  final double? changeRate;

  const _ChangeBadge({
    required this.prefix,
    required this.changeRate,
  });

  @override
  Widget build(BuildContext context) {
    if (changeRate == null) {
      return Text(
        '$prefix --',
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      );
    }
    final up = changeRate! >= 0;
    final color = up ? AppColors.successGreen : AppColors.warningAmber;
    final arrow = up ? '↑' : '↓';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$prefix $arrow ${changeRate!.abs().toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MetricCol extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCol({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
