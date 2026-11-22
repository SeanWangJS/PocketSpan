import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/widgets/pocket_date_time_pickers.dart';
import '../../../../core/widgets/pocket_sheet_components.dart';
import '../../data/models/task_model.dart';

/// Modal bottom sheet for logging minute-level effort (`WorkLog`) against a task.
class EffortMarkSheet extends StatefulWidget {
  final List<TaskWithDetails> activeTasks;
  final TaskWithDetails? preselectedTask;
  final DateTime initialDate;

  const EffortMarkSheet({
    super.key,
    required this.activeTasks,
    this.preselectedTask,
    required this.initialDate,
  });

  @override
  State<EffortMarkSheet> createState() => _EffortMarkSheetState();
}

class _EffortMarkSheetState extends State<EffortMarkSheet> {
  late String? _selectedTaskId;
  late DateTime _workDate;
  int _hours = 1;
  int _minutes = 0;
  bool _markCompleted = false;
  final _memoController = TextEditingController();

  static const _quickPresets = [15, 30, 60, 120, 240, 480];

  @override
  void initState() {
    super.initState();
    _selectedTaskId = widget.preselectedTask?.task.id ??
        (widget.activeTasks.isNotEmpty
            ? widget.activeTasks.first.task.id
            : null);
    _workDate = widget.initialDate;
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  int get _totalMinutes => _hours * 60 + _minutes;

  TaskWithDetails? get _selectedTask {
    if (widget.preselectedTask != null) return widget.preselectedTask;
    for (final t in widget.activeTasks) {
      if (t.task.id == _selectedTaskId) return t;
    }
    return null;
  }

  Future<void> _pickWorkDate() async {
    final picked = await showPocketDatePicker(
      context: context,
      initialDate: _workDate,
      title: '记录日期',
    );
    if (picked != null) {
      setState(() => _workDate = picked);
    }
  }

  void _applyPreset(int mins) {
    setState(() {
      _hours = mins ~/ 60;
      _minutes = mins % 60;
    });
  }

  void _submit() {
    final taskId = _selectedTaskId;
    if (taskId == null || _totalMinutes <= 0) return;

    Navigator.of(context).pop(
      EffortMarkResult(
        taskId: taskId,
        workDate: _workDate,
        durationMinutes: _totalMinutes,
        memo: _memoController.text.trim(),
        markTaskCompleted: _markCompleted,
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
    final currentTask = _selectedTask;
    final tint = currentTask != null
        ? AppColors.parseHex(currentTask.primaryTag.darkColorHex)
        : AppColors.primary;
    final canSubmit = _totalMinutes > 0 && _selectedTaskId != null;

    return PocketSheetContainer(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PocketSheetHeader(
              title: '记录工时',
              actionLabel: '保存',
              onAction: canSubmit ? _submit : null,
            ),
            const SizedBox(height: 14),

            if (widget.preselectedTask != null) ...[
              PocketSoftCard(
                tintColor: tint,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.parseHex(
                          widget.preselectedTask!.primaryTag.lightColorHex,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        iconForTag(widget.preselectedTask!.primaryTag),
                        size: 16,
                        color: tint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.preselectedTask!.task.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (widget.activeTasks.isNotEmpty) ...[
              PocketSoftCard(
                label: '对应事项',
                tintColor: tint,
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTaskId,
                    isExpanded: true,
                    items: widget.activeTasks
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.task.id,
                            child: Text(
                              '${item.primaryTag.name} · ${item.task.title}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedTaskId = val),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Hero duration card (matching PocketBudget's big numeric card)
            PocketSoftCard(
              label: '投入时长',
              tintColor: tint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DurationFormatter.format(_totalMinutes),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: tint,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _quickPresets.map((mins) {
                      final selected = _totalMinutes == mins;
                      return ChoiceChip(
                        label: Text(
                          DurationFormatter.format(mins),
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: selected,
                        onSelected: (_) => _applyPreset(mins),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StepperBox(
                          label: '小时',
                          value: _hours,
                          onDecrement: _hours > 0
                              ? () => setState(() => _hours--)
                              : null,
                          onIncrement: _hours < 24
                              ? () => setState(() => _hours++)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StepperBox(
                          label: '分钟',
                          value: _minutes,
                          onDecrement: _minutes > 0
                              ? () => setState(
                                    () => _minutes =
                                        (_minutes - 5).clamp(0, 59),
                                  )
                              : null,
                          onIncrement: () => setState(() {
                            if (_minutes + 5 >= 60) {
                              _hours = (_hours + 1).clamp(0, 24);
                              _minutes = (_minutes + 5) % 60;
                            } else {
                              _minutes += 5;
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            PocketSoftCard(
              label: '备注',
              tintColor: tint,
              child: TextField(
                controller: _memoController,
                maxLength: 50,
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
              label: '日期',
              value: _formatDateSlash(_workDate),
              onTap: _pickWorkDate,
            ),
            const SizedBox(height: 6),

            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text(
                '同时标记为已完成',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              value: _markCompleted,
              onChanged: (val) => setState(() => _markCompleted = val),
            ),
            const SizedBox(height: 8),

            PocketPrimaryButton(
              label: '保存记录',
              onPressed: canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperBox extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _StepperBox({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle_outline, size: 19),
            visualDensity: VisualDensity.compact,
          ),
          Column(
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline, size: 19),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class EffortMarkResult {
  final String taskId;
  final DateTime workDate;
  final int durationMinutes;
  final String memo;
  final bool markTaskCompleted;

  const EffortMarkResult({
    required this.taskId,
    required this.workDate,
    required this.durationMinutes,
    required this.memo,
    required this.markTaskCompleted,
  });
}
