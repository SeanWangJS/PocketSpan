import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils_helper.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../tags/data/models/tag_model.dart';
import '../../../tasks/data/models/task_model.dart';
import '../../../tasks/data/repositories/task_repository.dart';
import '../../../tasks/presentation/screens/task_detail_screen.dart';
import '../../../tasks/presentation/widgets/effort_mark_sheet.dart';
import '../../../tasks/presentation/widgets/task_form_sheet.dart';

/// Day Detail Page opened whenever the user taps any date cell in the calendar.
/// Displays both effort-logged items (dark highlight) and ongoing span items (light span).
class DayDetailScreen extends StatefulWidget {
  final DateTime date;
  final TaskRepository taskRepository;
  final List<TagModel> availableTags;
  final Future<void> Function() onDataChanged;

  const DayDetailScreen({
    super.key,
    required this.date,
    required this.taskRepository,
    required this.availableTags,
    required this.onDataChanged,
  });

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  List<TaskWithDetails> _allTasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.taskRepository.getAllTasksWithDetails();
    if (!mounted) return;
    setState(() {
      _allTasks = list;
      _loading = false;
    });
  }

  Future<void> _refreshAll() async {
    await _load();
    await widget.onDataChanged();
  }

  Future<void> _createTaskForDay() async {
    final res = await showModalBottomSheet<TaskFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskFormSheet(
        availableTags: widget.availableTags,
        initialDate: widget.date,
      ),
    );
    if (res == null) return;
    await widget.taskRepository.createTask(
      title: res.title,
      note: res.note,
      primaryTagId: res.primaryTagId,
      tagIds: res.tagIds,
      createdDate: res.createdDate,
      dueDate: res.dueDate,
      reminderAtDue: res.reminderAtDue,
      reminderLeadDays: res.reminderLeadDays,
      reminderDailyTimes: res.reminderDailyTimes,
      reminderWeeklyDays: res.reminderWeeklyDays,
      reminderWeeklyTime: res.reminderWeeklyTime,
      reminderOffsetsMinutes: res.reminderOffsetsMinutes,
      scheduledReminders: res.scheduledReminders,
    );
    await _refreshAll();
  }

  Future<void> _logEffort({TaskWithDetails? preselected}) async {
    final activeOrAll = _allTasks
        .where((t) => t.task.status != TaskStatus.archived)
        .toList();
    if (activeOrAll.isEmpty) return;

    final res = await showModalBottomSheet<EffortMarkResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EffortMarkSheet(
        activeTasks: activeOrAll,
        preselectedTask: preselected,
        initialDate: widget.date,
      ),
    );
    if (res == null) return;
    await widget.taskRepository.addWorkLog(
      taskId: res.taskId,
      workDate: res.workDate,
      durationMinutes: res.durationMinutes,
      memo: res.memo,
      markTaskCompleted: res.markTaskCompleted,
    );
    await _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final dateOnly = DateUtilsHelper.dateOnly(widget.date);
    final today = DateUtilsHelper.dateOnly(DateTime.now());
    final lunar = DateUtilsHelper.lunarLabel(dateOnly);

    final dayEffortItems = <TaskWithDetails>[];
    final daySpanOnlyItems = <TaskWithDetails>[];
    final dayDueItems = <TaskWithDetails>[];
    int totalDayMinutes = 0;

    for (final item in _allTasks) {
      if (item.task.status == TaskStatus.archived) continue;
      final effortToday = item.effortMinutesOn(dateOnly);
      final start = DateUtilsHelper.dateOnly(item.task.createdDate);
      final end = item.effectiveSpanEnd(today);
      final inSpan = !dateOnly.isBefore(start) && !dateOnly.isAfter(end);
      final isDueToday = item.task.dueDate != null &&
          DateUtilsHelper.toDateKey(item.task.dueDate!) ==
              DateUtilsHelper.toDateKey(dateOnly);

      if (effortToday > 0) {
        totalDayMinutes += effortToday;
        dayEffortItems.add(item);
      } else if (inSpan) {
        daySpanOnlyItems.add(item);
      } else if (isDueToday) {
        dayDueItems.add(item);
      }
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${dateOnly.year}年${dateOnly.month}月${dateOnly.day}日',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              '农历 ${lunar.text} · 当日投入 ${DurationFormatter.format(totalDayMinutes)}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _createTaskForDay,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新建事项'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (dayEffortItems.isEmpty &&
                  daySpanOnlyItems.isEmpty &&
                  dayDueItems.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.event_available_outlined,
                        size: 52,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '这一天还没有事项记录',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _createTaskForDay,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('新建当日事项'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    if (dayEffortItems.isNotEmpty) ...[
                      const _SectionTitle('当日投入工时（深色高亮）'),
                      ...dayEffortItems.map(
                        (item) => _DayTaskCard(
                          item: item,
                          date: dateOnly,
                          isDarkEffort: true,
                          cardColor: card,
                          borderColor: border,
                          onTap: () => _openTaskDetail(item.task.id),
                          onMarkEffort: () => _logEffort(preselected: item),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (daySpanOnlyItems.isNotEmpty) ...[
                      const _SectionTitle('持续进行中（浅色跨度）'),
                      ...daySpanOnlyItems.map(
                        (item) => _DayTaskCard(
                          item: item,
                          date: dateOnly,
                          isDarkEffort: false,
                          cardColor: card,
                          borderColor: border,
                          onTap: () => _openTaskDetail(item.task.id),
                          onMarkEffort: () => _logEffort(preselected: item),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (dayDueItems.isNotEmpty) ...[
                      const _SectionTitle('当日截止 DDL'),
                      ...dayDueItems.map(
                        (item) => _DayTaskCard(
                          item: item,
                          date: dateOnly,
                          isDarkEffort: false,
                          cardColor: card,
                          borderColor: border,
                          onTap: () => _openTaskDetail(item.task.id),
                          onMarkEffort: () => _logEffort(preselected: item),
                        ),
                      ),
                    ],
                  ],
                ),
      floatingActionButton: _allTasks.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _logEffort(),
              backgroundColor: AppColors.accentOrange,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.timer_outlined),
              label: const Text('当日记工时'),
            ),
    );
  }

  void _openTaskDetail(String taskId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          taskId: taskId,
          taskRepository: widget.taskRepository,
          availableTags: widget.availableTags,
          onTaskChanged: _refreshAll,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _DayTaskCard extends StatelessWidget {
  final TaskWithDetails item;
  final DateTime date;
  final bool isDarkEffort;
  final Color cardColor;
  final Color borderColor;
  final VoidCallback onTap;
  final VoidCallback onMarkEffort;

  const _DayTaskCard({
    required this.item,
    required this.date,
    required this.isDarkEffort,
    required this.cardColor,
    required this.borderColor,
    required this.onTap,
    required this.onMarkEffort,
  });

  @override
  Widget build(BuildContext context) {
    final pDark = AppColors.parseHex(item.primaryTag.darkColorHex);
    final pLight = AppColors.parseHex(item.primaryTag.lightColorHex);
    final effortToday = item.effortMinutesOn(date);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDarkEffort ? pDark.withValues(alpha: 0.45) : borderColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 44,
              decoration: BoxDecoration(
                color: isDarkEffort ? pDark : pLight,
                borderRadius: BorderRadius.circular(3),
                border: isDarkEffort ? null : Border.all(color: pDark, width: 0.8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.task.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ...item.tags.map((t) {
                        final td = AppColors.parseHex(t.darkColorHex);
                        final tl = AppColors.parseHex(t.lightColorHex);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tl,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t.name,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: td,
                            ),
                          ),
                        );
                      }),
                      Text(
                        '累计 ${DurationFormatter.format(item.totalEffortMinutes)} · 跨度 ${item.spanDays()}天',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isDarkEffort)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: pDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  DurationFormatter.format(effortToday),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              )
            else
              OutlinedButton(
                onPressed: onMarkEffort,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('+ 记工时', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
