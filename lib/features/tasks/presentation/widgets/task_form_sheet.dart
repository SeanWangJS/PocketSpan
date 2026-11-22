import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/pocket_date_time_pickers.dart';
import '../../../../core/widgets/pocket_sheet_components.dart';
import '../../../tags/data/models/tag_model.dart';
import '../../data/models/task_model.dart';

/// Modal bottom sheet for creating or editing a multi-tag task with optional DDL & reminders.
class TaskFormSheet extends StatefulWidget {
  final List<TagModel> availableTags;
  final DateTime initialDate;
  final TaskWithDetails? existing;

  const TaskFormSheet({
    super.key,
    required this.availableTags,
    required this.initialDate,
    this.existing,
  });

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late String _primaryTagId;
  late Set<String> _selectedTagIds;
  late DateTime _createdDate;
  DateTime? _dueDate;
  late bool _reminderAtDue;
  late int _reminderLeadDays;
  late List<String> _reminderDailyTimes;
  late Set<int> _reminderWeeklyDays;
  late String _reminderWeeklyTime;

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController = TextEditingController(text: existing.task.title);
      _noteController = TextEditingController(text: existing.task.note);
      _primaryTagId = existing.task.primaryTagId;
      _selectedTagIds = existing.tags.map((t) => t.id).toSet();
      _createdDate = existing.task.createdDate;
      _dueDate = existing.task.dueDate;
      _reminderAtDue = existing.task.reminderAtDue;
      _reminderLeadDays = existing.task.reminderLeadDays;
      _reminderDailyTimes = List<String>.from(existing.task.reminderDailyTimes);
      if (_reminderLeadDays > 0 && _reminderDailyTimes.isEmpty) {
        _reminderDailyTimes = ReminderScheduleBuilder.defaultTimesForCount(1);
      }
      _reminderWeeklyDays = existing.task.reminderWeeklyDays.toSet();
      _reminderWeeklyTime = existing.task.reminderWeeklyTime;
    } else {
      _titleController = TextEditingController();
      _noteController = TextEditingController();
      final defaultTagId = widget.availableTags.first.id;
      _primaryTagId = defaultTagId;
      _selectedTagIds = {defaultTagId};
      _createdDate = widget.initialDate;
      _dueDate = null;
      _reminderAtDue = true;
      _reminderLeadDays = 0;
      _reminderDailyTimes = [];
      _reminderWeeklyDays = {};
      _reminderWeeklyTime = '09:30';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  TagModel get _primaryTag => widget.availableTags.firstWhere(
        (t) => t.id == _primaryTagId,
        orElse: () => widget.availableTags.first,
      );

  Future<void> _pickCreatedDate() async {
    final picked = await showPocketDatePicker(
      context: context,
      initialDate: _createdDate,
      title: '开始日期',
    );
    if (picked != null) {
      setState(() => _createdDate = picked);
    }
  }

  Future<void> _pickDueDateTime() async {
    final base = _dueDate ?? _createdDate.add(const Duration(days: 3));
    final pickedDate = await showPocketDatePicker(
      context: context,
      initialDate: base,
      title: '截止日期',
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showPocketTimePicker(
      context: context,
      initialTime: _dueDate != null
          ? TimeOfDay.fromDateTime(_dueDate!)
          : const TimeOfDay(hour: 18, minute: 0),
      title: '截止时间',
    );
    if (!mounted) return;
    final t = pickedTime ?? const TimeOfDay(hour: 18, minute: 0);
    setState(() {
      _dueDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        t.hour,
        t.minute,
      );
    });
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        if (_selectedTagIds.length == 1) return;
        _selectedTagIds.remove(tagId);
        if (_primaryTagId == tagId) {
          _primaryTagId = _selectedTagIds.first;
        }
      } else {
        _selectedTagIds.add(tagId);
      }
    });
  }

  void _setPrimaryTag(String tagId) {
    setState(() {
      _selectedTagIds.add(tagId);
      _primaryTagId = tagId;
    });
  }

  String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTimeOfDay(String hhmm) {
    final parts = hhmm.split(':');
    final h = parts.length == 2 ? (int.tryParse(parts[0]) ?? 9) : 9;
    final m = parts.length == 2 ? (int.tryParse(parts[1]) ?? 30) : 30;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  Future<void> _addDailyTime() async {
    final picked = await showPocketTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      title: '添加提醒时间',
    );
    if (picked == null || !mounted) return;
    final formatted = _formatTimeOfDay(picked);
    setState(() {
      if (!_reminderDailyTimes.contains(formatted)) {
        _reminderDailyTimes = [..._reminderDailyTimes, formatted]..sort();
      }
    });
  }

  Future<void> _editDailyTime(int index) async {
    final picked = await showPocketTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(_reminderDailyTimes[index]),
      title: '修改提醒时间',
    );
    if (picked == null || !mounted) return;
    final formatted = _formatTimeOfDay(picked);
    setState(() {
      final updated = List<String>.from(_reminderDailyTimes);
      updated[index] = formatted;
      _reminderDailyTimes = updated.toSet().toList()..sort();
    });
  }

  Future<void> _pickWeeklyTime() async {
    final picked = await showPocketTimePicker(
      context: context,
      initialTime: _parseTimeOfDay(_reminderWeeklyTime),
      title: '每周提醒时间',
    );
    if (picked == null || !mounted) return;
    setState(() => _reminderWeeklyTime = _formatTimeOfDay(picked));
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final sortedWeeklyDays = _reminderWeeklyDays.toList()..sort();
    final dailyTimes = _dueDate != null && _reminderLeadDays > 0
        ? List<String>.from(_reminderDailyTimes)
        : const <String>[];
    final entries = ReminderScheduleBuilder.buildEntries(
      startDate: _createdDate,
      dueDate: _dueDate,
      atDue: _dueDate != null && _reminderAtDue,
      leadDays: _dueDate != null ? _reminderLeadDays : 0,
      dailyTimes: dailyTimes,
      weeklyDays: sortedWeeklyDays,
      weeklyTime: _reminderWeeklyTime,
    );

    Navigator.of(context).pop(
      TaskFormResult(
        title: title,
        note: _noteController.text.trim(),
        primaryTagId: _primaryTagId,
        tagIds: _selectedTagIds.toList(),
        createdDate: _createdDate,
        dueDate: _dueDate,
        reminderAtDue: _reminderAtDue,
        reminderLeadDays: _reminderLeadDays,
        reminderDailyTimes: dailyTimes,
        reminderWeeklyDays: sortedWeeklyDays,
        reminderWeeklyTime: _reminderWeeklyTime,
        reminderOffsetsMinutes:
            entries.where((e) => e.offsetMinutes >= 0).map((e) => e.offsetMinutes).toList(),
        scheduledReminders: entries,
      ),
    );
  }

  String _formatDateSlash(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.parseHex(_primaryTag.darkColorHex);

    return PocketSheetContainer(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PocketSheetHeader(
              title: widget.existing == null ? '新建事项' : '编辑事项',
              actionLabel: '保存',
              onAction: _submit,
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '标签',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '长按设为主标签',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            PocketTagBadgeGrid(
              tags: widget.availableTags,
              selectedTagIds: _selectedTagIds,
              primaryTagId: _primaryTagId,
              onToggleTag: _toggleTag,
              onSetPrimaryTag: _setPrimaryTag,
            ),
            const SizedBox(height: 16),

            PocketSoftCard(
              label: '事项名称',
              tintColor: tint,
              child: TextField(
                controller: _titleController,
                autofocus: widget.existing == null,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  hintText: '输入待办或日程名称',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 10),

            PocketSoftCard(
              label: '备注',
              tintColor: tint,
              child: TextField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 80,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '未填写备注',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 10),

            PocketActionRow(
              icon: Icons.calendar_today_outlined,
              label: '开始日期',
              value: _formatDateSlash(_createdDate),
              onTap: _pickCreatedDate,
            ),
            const SizedBox(height: 8),

            PocketActionRow(
              icon: Icons.alarm_outlined,
              label: '截止 DDL',
              value: _dueDate == null
                  ? '未设置'
                  : '${_formatDateSlash(_dueDate!)} ${_dueDate!.hour.toString().padLeft(2, '0')}:${_dueDate!.minute.toString().padLeft(2, '0')}',
              onTap: _pickDueDateTime,
              trailing: _dueDate == null
                  ? null
                  : GestureDetector(
                      onTap: () => setState(() => _dueDate = null),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),

            if (_dueDate != null) ...[
              const SizedBox(height: 10),
              PocketSoftCard(
                tintColor: tint,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '准点闹钟',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Switch.adaptive(
                          value: _reminderAtDue,
                          activeTrackColor: AppColors.primary,
                          onChanged: (v) => setState(() => _reminderAtDue = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          '提前提醒',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        _StepperMini(
                          label: _reminderLeadDays == 0
                              ? '不提前'
                              : '提前 $_reminderLeadDays 天',
                          onDecrement: _reminderLeadDays > 0
                              ? () => setState(() => _reminderLeadDays--)
                              : null,
                          onIncrement: _reminderLeadDays < 30
                              ? () => setState(() {
                                    _reminderLeadDays++;
                                    if (_reminderDailyTimes.isEmpty) {
                                      _reminderDailyTimes =
                                          ReminderScheduleBuilder
                                              .defaultTimesForCount(1);
                                    }
                                  })
                              : null,
                        ),
                      ],
                    ),
                    if (_reminderLeadDays > 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text(
                            '每天次数',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          ...List.generate(4, (i) {
                            final count = i + 1;
                            final active = _reminderDailyTimes.length == count;
                            return GestureDetector(
                              onTap: () => setState(() {
                                _reminderDailyTimes = ReminderScheduleBuilder
                                    .defaultTimesForCount(count);
                              }),
                              child: Container(
                                margin: const EdgeInsets.only(left: 6),
                                width: 28,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.primary
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...List.generate(_reminderDailyTimes.length, (idx) {
                            final timeStr = _reminderDailyTimes[idx];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _editDailyTime(idx),
                                    child: Text(
                                      timeStr,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _reminderDailyTimes.removeAt(idx);
                                    }),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: _addDailyTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    '添加',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            PocketSoftCard(
              tintColor: tint,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '每周提醒',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Switch.adaptive(
                        value: _reminderWeeklyDays.isNotEmpty,
                        activeTrackColor: AppColors.primary,
                        onChanged: (enabled) {
                          setState(() {
                            if (enabled) {
                              if (_reminderWeeklyDays.isEmpty) {
                                _reminderWeeklyDays = {DateTime.now().weekday};
                              }
                            } else {
                              _reminderWeeklyDays.clear();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (_reminderWeeklyDays.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (idx) {
                        final weekday = idx + 1;
                        final active = _reminderWeeklyDays.contains(weekday);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (active) {
                                _reminderWeeklyDays.remove(weekday);
                              } else {
                                _reminderWeeklyDays.add(weekday);
                              }
                            });
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _weekdayLabels[idx],
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          '提醒时间',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _pickWeeklyTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _reminderWeeklyTime,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
            PocketPrimaryButton(
              label: widget.existing == null ? '保存事项' : '保存修改',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperMini extends StatelessWidget {
  final String label;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _StepperMini({
    required this.label,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onDecrement,
          icon: const Icon(Icons.remove_circle_outline, size: 19),
          visualDensity: VisualDensity.compact,
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: onIncrement,
          icon: const Icon(Icons.add_circle_outline, size: 19),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class TaskFormResult {
  final String title;
  final String note;
  final String primaryTagId;
  final List<String> tagIds;
  final DateTime createdDate;
  final DateTime? dueDate;
  final bool reminderAtDue;
  final int reminderLeadDays;
  final List<String> reminderDailyTimes;
  final List<int> reminderWeeklyDays;
  final String reminderWeeklyTime;
  final List<int> reminderOffsetsMinutes;
  final List<({int offsetMinutes, DateTime triggerAt})> scheduledReminders;

  const TaskFormResult({
    required this.title,
    required this.note,
    required this.primaryTagId,
    required this.tagIds,
    required this.createdDate,
    required this.dueDate,
    required this.reminderAtDue,
    required this.reminderLeadDays,
    required this.reminderDailyTimes,
    required this.reminderWeeklyDays,
    required this.reminderWeeklyTime,
    required this.reminderOffsetsMinutes,
    required this.scheduledReminders,
  });
}
