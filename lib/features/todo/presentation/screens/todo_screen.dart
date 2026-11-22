import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/widgets/pocket_sheet_components.dart';
import '../../../tags/data/models/tag_model.dart';
import '../../../tasks/data/models/task_model.dart';
import '../../../tasks/data/repositories/task_repository.dart';
import '../../../tasks/presentation/screens/task_detail_screen.dart';
import '../../../tasks/presentation/widgets/task_form_sheet.dart';

enum _TodoFilterTab { active, urgent, completed }

/// Task management tab with Active / Urgent(DDL) / Completed filters and multi-tag filtering.
class TodoScreen extends StatefulWidget {
  final List<TaskWithDetails> tasks;
  final List<TagModel> tags;
  final TaskRepository taskRepository;
  final Future<void> Function() onDataChanged;

  const TodoScreen({
    super.key,
    required this.tasks,
    required this.tags,
    required this.taskRepository,
    required this.onDataChanged,
  });

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  _TodoFilterTab _filterTab = _TodoFilterTab.active;
  String? _selectedTagId;

  bool _isUrgentOrOverdue(TaskWithDetails item) {
    if (item.task.status != TaskStatus.active || item.task.dueDate == null) {
      return false;
    }
    final diff = item.task.dueDate!.difference(DateTime.now());
    return diff.inHours <= 48;
  }

  List<TaskWithDetails> get _filteredTasks {
    return widget.tasks.where((item) {
      if (_selectedTagId != null && !item.hasTag(_selectedTagId!)) {
        return false;
      }
      switch (_filterTab) {
        case _TodoFilterTab.active:
          return item.task.status == TaskStatus.active;
        case _TodoFilterTab.urgent:
          return _isUrgentOrOverdue(item);
        case _TodoFilterTab.completed:
          return item.task.status == TaskStatus.completed;
      }
    }).toList();
  }

  Future<void> _createTask() async {
    final res = await showModalBottomSheet<TaskFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskFormSheet(
        availableTags: widget.tags,
        initialDate: DateTime.now(),
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
    await widget.onDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final items = _filteredTasks;
    final urgentCount = widget.tasks.where(_isUrgentOrOverdue).length;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '待办',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _createTask,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('新建'),
                  ),
                ],
              ),
            ),

            // Clean segmented status bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFECEFF6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatusSegment(
                        label: '进行中',
                        selected: _filterTab == _TodoFilterTab.active,
                        onTap: () =>
                            setState(() => _filterTab = _TodoFilterTab.active),
                      ),
                    ),
                    Expanded(
                      child: _StatusSegment(
                        label: urgentCount > 0 ? '临期 $urgentCount' : '临期',
                        selected: _filterTab == _TodoFilterTab.urgent,
                        highlightWarning: urgentCount > 0,
                        onTap: () =>
                            setState(() => _filterTab = _TodoFilterTab.urgent),
                      ),
                    ),
                    Expanded(
                      child: _StatusSegment(
                        label: '已完成',
                        selected: _filterTab == _TodoFilterTab.completed,
                        onTap: () => setState(
                            () => _filterTab = _TodoFilterTab.completed),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Minimal borderless tag filter strip
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _TagFilterText(
                    label: '全部',
                    selected: _selectedTagId == null,
                    onTap: () => setState(() => _selectedTagId = null),
                  ),
                  ...widget.tags.map((tag) {
                    final selected = _selectedTagId == tag.id;
                    return _TagFilterText(
                      label: tag.name,
                      dotColor: AppColors.parseHex(tag.darkColorHex),
                      selected: selected,
                      onTap: () => setState(
                        () => _selectedTagId = selected ? null : tag.id,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Task list
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无事项',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (_, idx) {
                        final item = items[idx];
                        final pDark =
                            AppColors.parseHex(item.primaryTag.darkColorHex);
                        final pLight =
                            AppColors.parseHex(item.primaryTag.lightColorHex);
                        final tagText = item.tags.map((t) => t.name).join('/');
                        final dateStr =
                            '${item.task.createdDate.month}/${item.task.createdDate.day}';
                        final metaParts = <String>[
                          tagText,
                          dateStr,
                          if (item.totalEffortMinutes > 0)
                            DurationFormatter.format(item.totalEffortMinutes),
                        ];

                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TaskDetailScreen(
                                  taskId: item.task.id,
                                  taskRepository: widget.taskRepository,
                                  availableTags: widget.tags,
                                  onTaskChanged: widget.onDataChanged,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: pLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    iconForTag(item.primaryTag),
                                    size: 18,
                                    color: pDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.task.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        metaParts.join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final bool highlightWarning;
  final VoidCallback onTap;

  const _StatusSegment({
    required this.label,
    required this.selected,
    this.highlightWarning = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.darkCard : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? (highlightWarning ? AppColors.warningAmber : AppColors.primary)
                : (highlightWarning
                    ? AppColors.warningAmber
                    : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _TagFilterText extends StatelessWidget {
  final String label;
  final Color? dotColor;
  final bool selected;
  final VoidCallback onTap;

  const _TagFilterText({
    required this.label,
    this.dotColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.06))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? (isDark ? Colors.white : AppColors.textPrimaryLight)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
