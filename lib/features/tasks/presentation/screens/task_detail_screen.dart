import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_utils_helper.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/widgets/pocket_sheet_components.dart';
import '../../../tags/data/models/tag_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import '../widgets/effort_mark_sheet.dart';
import '../widgets/task_form_sheet.dart';

/// Full lifecycle detail view for a single task, showing span vs. effort metrics
/// and the chronological timeline of all work log marks.
class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  final TaskRepository taskRepository;
  final List<TagModel> availableTags;
  final Future<void> Function()? onTaskChanged;

  const TaskDetailScreen({
    super.key,
    required this.taskId,
    required this.taskRepository,
    required this.availableTags,
    this.onTaskChanged,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TaskWithDetails? _details;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.taskRepository.getTaskWithDetails(widget.taskId);
    if (!mounted) return;
    setState(() {
      _details = data;
      _loading = false;
    });
  }

  Future<void> _notifyChanged() async {
    await _load();
    await widget.onTaskChanged?.call();
  }

  Future<void> _addEffortMark() async {
    final d = _details;
    if (d == null) return;
    final res = await showModalBottomSheet<EffortMarkResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EffortMarkSheet(
        activeTasks: [d],
        preselectedTask: d,
        initialDate: DateTime.now(),
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
    await _notifyChanged();
  }

  Future<void> _editTask() async {
    final d = _details;
    if (d == null) return;
    final res = await showModalBottomSheet<TaskFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskFormSheet(
        availableTags: widget.availableTags,
        initialDate: d.task.createdDate,
        existing: d,
      ),
    );
    if (res == null) return;
    final updated = d.task.copyWith(
      title: res.title,
      note: res.note,
      primaryTagId: res.primaryTagId,
      createdDate: res.createdDate,
      dueDate: res.dueDate,
      clearDueDate: res.dueDate == null,
      reminderAtDue: res.reminderAtDue,
      reminderLeadDays: res.reminderLeadDays,
      reminderDailyTimes: res.reminderDailyTimes,
      reminderWeeklyDays: res.reminderWeeklyDays,
      reminderWeeklyTime: res.reminderWeeklyTime,
    );
    await widget.taskRepository.updateTask(
      task: updated,
      tagIds: res.tagIds,
      reminderOffsetsMinutes: res.reminderOffsetsMinutes,
      scheduledReminders: res.scheduledReminders,
    );
    await _notifyChanged();
  }

  Future<void> _toggleComplete() async {
    final d = _details;
    if (d == null) return;
    final next = d.task.status == TaskStatus.completed
        ? TaskStatus.active
        : TaskStatus.completed;
    await widget.taskRepository.setTaskStatus(
      taskId: d.task.id,
      status: next,
      completedDate: next == TaskStatus.completed ? DateTime.now() : null,
    );
    await _notifyChanged();
  }

  Future<void> _deleteTask() async {
    final confirmed = await showPocketConfirmDialog(
      context: context,
      title: '删除事项',
      message: '确定删除该事项及其所有工时记录吗？此操作不可恢复。',
      confirmLabel: '删除',
    );
    if (!confirmed) return;
    await widget.taskRepository.deleteTask(widget.taskId);
    await widget.onTaskChanged?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: const Text('事项详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final d = _details;
    if (d == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: const Text('事项详情')),
        body: const Center(child: Text('事项不存在或已删除')),
      );
    }

    final primaryDark = AppColors.parseHex(d.primaryTag.darkColorHex);
    final primaryLight = AppColors.parseHex(d.primaryTag.lightColorHex);
    final isCompleted = d.task.status == TaskStatus.completed;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('事项详情', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _editTask,
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑',
          ),
          IconButton(
            onPressed: _deleteTask,
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.successGreen.withValues(alpha: 0.14)
                            : primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCompleted ? '已完成' : '进行中',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isCompleted
                              ? AppColors.successGreen
                              : primaryDark,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _toggleComplete,
                      icon: Icon(
                        isCompleted
                            ? Icons.replay_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                      label: Text(isCompleted ? '重新激活' : '标记完成'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  d.task.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (d.task.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    d.task.note,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: d.tags.map((tag) {
                    final isPrimary = tag.id == d.primaryTag.id;
                    final tDark = AppColors.parseHex(tag.darkColorHex);
                    final tLight = AppColors.parseHex(tag.lightColorHex);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPrimary ? tDark : tLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isPrimary ? '${tag.name} (主)' : tag.name,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isPrimary ? Colors.white : tDark,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _EfficiencyStat(
                      label: '跨度',
                      value: '${d.spanDays()} 天',
                      color: primaryDark,
                    ),
                    _EfficiencyStat(
                      label: '总工时',
                      value: DurationFormatter.format(d.totalEffortMinutes),
                      color: AppColors.primary,
                    ),
                    _EfficiencyStat(
                      label: '延迟',
                      value: d.startDelayDays == null
                          ? '未投入'
                          : '${d.startDelayDays} 天',
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '立项：${DateUtilsHelper.toDateKey(d.task.createdDate)}'
                  '${d.task.dueDate != null ? '  ·  DDL：${DateUtilsHelper.toDateKey(d.task.dueDate!)}' : ''}'
                  '${d.task.completedDate != null ? '  ·  完成：${DateUtilsHelper.toDateKey(d.task.completedDate!)}' : ''}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '投入记录 (${d.workLogs.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton.icon(
                onPressed: _addEffortMark,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('记工时'),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (d.workLogs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: const Center(
                child: Text(
                  '暂未记录投入工时，点击右上角“记工时”',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            ...d.workLogs.map((log) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: primaryDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        DurationFormatter.format(log.durationMinutes),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateUtilsHelper.toDateKey(log.workDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          if (log.memo.isNotEmpty)
                            Text(
                              log.memo,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () async {
                        await widget.taskRepository.deleteWorkLog(log.id);
                        await _notifyChanged();
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEffortMark,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.timer_outlined),
        label: const Text('记工时'),
      ),
    );
  }
}

class _EfficiencyStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _EfficiencyStat({
    required this.label,
    required this.value,
    required this.color,
  });

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
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
