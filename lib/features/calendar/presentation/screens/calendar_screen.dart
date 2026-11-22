import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/widgets/pocket_date_time_pickers.dart';
import '../../../../core/widgets/pocket_sheet_components.dart';
import '../../../tags/data/models/tag_model.dart';
import '../../../tasks/data/models/task_model.dart';
import '../../../tasks/data/repositories/task_repository.dart';
import '../../../tasks/presentation/screens/task_detail_screen.dart';
import '../../../tasks/presentation/widgets/effort_mark_sheet.dart';
import '../../../tasks/presentation/widgets/task_form_sheet.dart';
import '../../domain/calendar_grid_calculator.dart';
import 'day_detail_screen.dart';

/// Primary monthly calendar view inspired by clean Chinese calendar apps,
/// upgraded with dual-track light (duration span) and dark (effort logged) bars.
class CalendarScreen extends StatefulWidget {
  final List<TaskWithDetails> tasks;
  final List<TagModel> tags;
  final TaskRepository taskRepository;
  final bool weekStartsOnMonday;
  final Future<void> Function() onDataChanged;

  const CalendarScreen({
    super.key,
    required this.tasks,
    required this.tags,
    required this.taskRepository,
    required this.weekStartsOnMonday,
    required this.onDataChanged,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const int _initialPage = 1200;

  late final DateTime _baseMonth;
  late DateTime _displayMonth;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _baseMonth = DateTime(now.year, now.month);
    _displayMonth = _baseMonth;
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) {
    return DateTime(_baseMonth.year, _baseMonth.month + (page - _initialPage));
  }

  int _pageForMonth(DateTime month) {
    return _initialPage +
        (month.year - _baseMonth.year) * 12 +
        (month.month - _baseMonth.month);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _displayMonth.year == now.year && _displayMonth.month == now.month;
  }

  void _navigateToMonth(DateTime targetMonth) {
    final targetPage = _pageForMonth(targetMonth);
    final currentPage =
        _pageController.hasClients && _pageController.page != null
            ? _pageController.page!.round()
            : _pageForMonth(_displayMonth);
    if ((targetPage - currentPage).abs() > 6) {
      _pageController.jumpToPage(targetPage);
      setState(() => _displayMonth = targetMonth);
    } else {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _changeMonth(int delta) {
    _navigateToMonth(DateTime(_displayMonth.year, _displayMonth.month + delta));
  }

  Future<void> _pickMonth() async {
    final picked = await showPocketMonthPicker(
      context: context,
      initialDate: _displayMonth,
    );
    if (picked != null) {
      _navigateToMonth(DateTime(picked.year, picked.month));
    }
  }

  void _openDayDetail(DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DayDetailScreen(
          date: date,
          taskRepository: widget.taskRepository,
          availableTags: widget.tags,
          onDataChanged: widget.onDataChanged,
        ),
      ),
    );
  }

  Future<void> _showQuickActionMenu() async {
    final activeTasks = widget.tasks
        .where((t) => t.task.status != TaskStatus.archived)
        .toList();

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return PocketSheetContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PocketSheetHeader(title: '快速记录'),
              const SizedBox(height: 14),
              PocketSoftCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F0FE),
                    child: Icon(Icons.add_task_rounded, color: AppColors.primary),
                  ),
                  title: const Text(
                    '新建事项',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.pop(ctx, 'create'),
                ),
              ),
              if (activeTasks.isNotEmpty) ...[
                const SizedBox(height: 10),
                PocketSoftCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      child: Icon(
                        Icons.timer_outlined,
                        color: AppColors.accentOrange,
                      ),
                    ),
                    title: const Text(
                      '记录工时',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => Navigator.pop(ctx, 'effort'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) return;
    if (choice == 'create') {
      final res = await showModalBottomSheet<TaskFormResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TaskFormSheet(
          availableTags: widget.tags,
          initialDate: DateTime.now(),
        ),
      );
      if (res != null) {
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
    } else if (choice == 'effort') {
      final res = await showModalBottomSheet<EffortMarkResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EffortMarkSheet(
          activeTasks: activeTasks,
          initialDate: DateTime.now(),
        ),
      );
      if (res != null) {
        await widget.taskRepository.addWorkLog(
          taskId: res.taskId,
          workDate: res.workDate,
          durationMinutes: res.durationMinutes,
          memo: res.memo,
          markTaskCompleted: res.markTaskCompleted,
        );
        await widget.onDataChanged();
      }
    }
  }

  void _openSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskSearchSheet(
        tasks: widget.tasks,
        onSelectTask: (taskId) {
          Navigator.of(context).pop();
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
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : Colors.white;
    final gridLine = isDark ? AppColors.darkBorder : const Color(0xFFF0F1F5);
    final weekdayLabels = widget.weekStartsOnMonday
        ? const ['一', '二', '三', '四', '五', '六', '日']
        : const ['日', '一', '二', '三', '四', '五', '六'];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar matching clean calendar design
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: '上一月',
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _pickMonth,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_displayMonth.year}.${_displayMonth.month.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down_rounded, size: 22),
                        ],
                      ),
                    ),
                  ),
                  if (!_isCurrentMonth) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        final now = DateTime.now();
                        _navigateToMonth(DateTime(now.year, now.month));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentOrange.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '今',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentOrange,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: '下一月',
                  ),
                  IconButton(
                    onPressed: _openSearchSheet,
                    icon: const Icon(Icons.search_rounded),
                    tooltip: '搜索事项',
                  ),
                ],
              ),
            ),

            // Weekday header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: List.generate(7, (idx) {
                  final isWeekend = widget.weekStartsOnMonday
                      ? (idx >= 5)
                      : (idx == 0 || idx == 6);
                  return Expanded(
                    child: Center(
                      child: Text(
                        weekdayLabels[idx],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isWeekend
                              ? AppColors.accentOrange
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            Divider(height: 1, color: gridLine),

            // Responsive full-height month grid with horizontal swipe paging
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _displayMonth = _monthForPage(page);
                  });
                },
                itemBuilder: (context, page) {
                  return _buildMonthGrid(_monthForPage(page), gridLine, isDark);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActionMenu,
        backgroundColor: AppColors.accentOrange,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }

  Widget _buildMonthGrid(DateTime monthDate, Color gridLine, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cells = CalendarGridCalculator.buildMonthGrid(
          year: monthDate.year,
          month: monthDate.month,
          tasks: widget.tasks,
          weekStartsOnMonday: widget.weekStartsOnMonday,
        );
        final rowCount = cells.length ~/ 7;
        final cellHeight = constraints.maxHeight / rowCount;
        final maxBars = cellHeight >= 108 ? 4 : 3;

        final adjustedCells = cells
            .map((c) => CalendarDayCellData(
                  date: c.date,
                  isCurrentMonth: c.isCurrentMonth,
                  isToday: c.isToday,
                  lunarText: c.lunarText,
                  isLunarHighlight: c.isLunarHighlight,
                  isoWeekNumber: c.isoWeekNumber,
                  entries: c.entries,
                  maxVisibleBars: maxBars,
                ))
            .toList();

        return Column(
          children: List.generate(rowCount, (rowIdx) {
            final rowCells = adjustedCells.skip(rowIdx * 7).take(7).toList();
            return Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: gridLine, width: 0.7),
                  ),
                ),
                child: Row(
                  children: List.generate(7, (colIdx) {
                    final cell = rowCells[colIdx];
                    return Expanded(
                      child: _CalendarDayCell(
                        cell: cell,
                        gridLine: gridLine,
                        isDark: isDark,
                        onTap: () => _openDayDetail(cell.date),
                      ),
                    );
                  }),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final CalendarDayCellData cell;
  final Color gridLine;
  final bool isDark;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.cell,
    required this.gridLine,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final todayBg = isDark
        ? AppColors.accentOrange.withValues(alpha: 0.12)
        : const Color(0xFFFFF5E9);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cell.isToday ? todayBg : Colors.transparent,
          border: Border(
            right: BorderSide(color: gridLine, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.only(top: 3, bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date number + lunar / week cue
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: cell.isToday
                        ? const BoxDecoration(
                            color: AppColors.accentOrange,
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Text(
                      '${cell.date.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            cell.isToday ? FontWeight.w700 : FontWeight.w500,
                        color: cell.isToday
                            ? Colors.white
                            : (cell.isCurrentMonth
                                ? (isDark
                                    ? Colors.white
                                    : AppColors.textPrimaryLight)
                                : AppColors.textSecondary
                                    .withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      cell.isoWeekNumber != null
                          ? '第${cell.isoWeekNumber}周'
                          : cell.lunarText,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 8.5,
                        color: cell.isLunarHighlight &&
                                cell.isoWeekNumber == null
                            ? AppColors.accentOrange
                            : AppColors.textSecondary.withValues(
                                alpha: cell.isCurrentMonth ? 0.8 : 0.45,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),

            // Week-aligned continuous dual-track task ribbons
            ...() {
              final visible = cell.visibleEntries;
              if (visible.isEmpty) return const <Widget>[];
              final maxSlot = visible
                  .map((e) => e.slotIndex)
                  .reduce((a, b) => a > b ? a : b);
              return List.generate(maxSlot + 1, (slot) {
                final entry = cell.entryAtSlot(slot);
                if (entry == null) {
                  return const SizedBox(height: 15);
                }

                final tag = entry.taskWithDetails.primaryTag;
                final darkColor = AppColors.parseHex(tag.darkColorHex);
                final lightColor = AppColors.parseHex(tag.lightColorHex);
                final isDarkEffort = entry.isDarkEffort;
                final title = entry.taskWithDetails.task.title;
                final isDueOnly =
                    !isDarkEffort && entry.isDueToday && !entry.isSpanActive;
                final showTitle = entry.isSpanStartInRow || isDueOnly;
                final displayTitle = isDueOnly ? '⏰$title' : title;
                final effortBadge = isDarkEffort
                    ? DurationFormatter.formatCompact(entry.effortMinutesToday)
                    : null;

                return Container(
                  height: 13.5,
                  margin: EdgeInsets.only(
                    left: entry.isSpanStartInRow ? 2 : 0,
                    right: entry.isSpanEndInRow ? 2 : 0,
                    bottom: 1.5,
                  ),
                  padding: EdgeInsets.only(
                    left: entry.isSpanStartInRow ? 3 : 1,
                    right: entry.isSpanEndInRow ? 3 : 1,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkEffort
                        ? darkColor
                        : (entry.isSpanActive ? lightColor : Colors.transparent),
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(entry.isSpanStartInRow ? 3.5 : 0),
                      right: Radius.circular(entry.isSpanEndInRow ? 3.5 : 0),
                    ),
                    border: isDueOnly
                        ? Border.all(color: darkColor, width: 0.6)
                        : null,
                  ),
                  child: Row(
                    children: [
                      if (showTitle)
                        Expanded(
                          child: Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              height: 1.15,
                              fontWeight: isDarkEffort
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isDarkEffort ? Colors.white : darkColor,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (effortBadge != null) ...[
                        const SizedBox(width: 2),
                        Text(
                          effortBadge,
                          style: const TextStyle(
                            fontSize: 8.5,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              });
            }(),

            if (cell.overflowCount > 0)
              Text(
                '+${cell.overflowCount}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskSearchSheet extends StatefulWidget {
  final List<TaskWithDetails> tasks;
  final ValueChanged<String> onSelectTask;

  const _TaskSearchSheet({
    required this.tasks,
    required this.onSelectTask,
  });

  @override
  State<_TaskSearchSheet> createState() => _TaskSearchSheetState();
}

class _TaskSearchSheetState extends State<_TaskSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.tasks.where((item) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      return item.task.title.toLowerCase().contains(q) ||
          item.task.note.toLowerCase().contains(q) ||
          item.tags.any((t) => t.name.toLowerCase().contains(q));
    }).toList();

    return PocketSheetContainer(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.68,
        child: Column(
          children: [
            const PocketSheetHeader(title: '搜索事项'),
            const SizedBox(height: 12),
            PocketSoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索事项名称、Tag 或备注...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        '没有匹配的事项',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, idx) {
                        final item = filtered[idx];
                        final pDark =
                            AppColors.parseHex(item.primaryTag.darkColorHex);
                        final pLight =
                            AppColors.parseHex(item.primaryTag.lightColorHex);
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
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${item.tags.map((t) => t.name).join(' · ')} · 累计 ${DurationFormatter.format(item.totalEffortMinutes)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => widget.onSelectTask(item.task.id),
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
