import '../../../../core/utils/date_utils_helper.dart';
import '../../tasks/data/models/task_model.dart';

/// A single task bar rendered inside a calendar day cell.
class CalendarDayTaskEntry {
  final TaskWithDetails taskWithDetails;
  final int effortMinutesToday;
  final bool isSpanActive;
  final bool isDueToday;
  final bool isCompletedToday;

  /// Vertical row slot (0..N) aligned across the 7-day week row.
  final int slotIndex;

  /// True if this cell starts the visible ribbon in the current week row
  /// (either the task's actual start day or the first day of the week row).
  final bool isSpanStartInRow;

  /// True if this cell ends the visible ribbon in the current week row
  /// (either the task's effective end day or the last day of the week row).
  final bool isSpanEndInRow;

  const CalendarDayTaskEntry({
    required this.taskWithDetails,
    required this.effortMinutesToday,
    required this.isSpanActive,
    required this.isDueToday,
    required this.isCompletedToday,
    this.slotIndex = 0,
    this.isSpanStartInRow = true,
    this.isSpanEndInRow = true,
  });

  /// Dark highlight is used whenever effort was logged on this date.
  bool get isDarkEffort => effortMinutesToday > 0;
}

/// Complete computed data for one cell in the monthly calendar grid.
class CalendarDayCellData {
  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final String lunarText;
  final bool isLunarHighlight;
  final int? isoWeekNumber;
  final List<CalendarDayTaskEntry> entries;
  final int maxVisibleBars;

  const CalendarDayCellData({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.lunarText,
    required this.isLunarHighlight,
    this.isoWeekNumber,
    required this.entries,
    this.maxVisibleBars = 3,
  });

  int get _slotLimit =>
      entries.any((e) => e.slotIndex >= maxVisibleBars)
          ? (maxVisibleBars - 1).clamp(1, maxVisibleBars)
          : maxVisibleBars;

  List<CalendarDayTaskEntry> get visibleEntries {
    final limit = _slotLimit;
    return entries.where((e) => e.slotIndex < limit).toList();
  }

  int get overflowCount {
    final limit = _slotLimit;
    return entries.where((e) => e.slotIndex >= limit).length;
  }

  /// Returns the entry occupying [slot], or null if that slot is empty on this day.
  CalendarDayTaskEntry? entryAtSlot(int slot) {
    for (final e in entries) {
      if (e.slotIndex == slot) return e;
    }
    return null;
  }
}

/// Builds a monthly calendar grid with continuous week-aligned dual-track ribbons.
class CalendarGridCalculator {
  CalendarGridCalculator._();

  static List<CalendarDayCellData> buildMonthGrid({
    required int year,
    required int month,
    required List<TaskWithDetails> tasks,
    bool weekStartsOnMonday = false,
    DateTime? referenceToday,
    int maxVisibleBars = 3,
  }) {
    final today = DateUtilsHelper.dateOnly(referenceToday ?? DateTime.now());
    final firstOfMonth = DateTime(year, month, 1);
    final lastOfMonth = DateTime(year, month + 1, 0);

    final firstWeekdayIndex = weekStartsOnMonday
        ? (firstOfMonth.weekday - 1)
        : (firstOfMonth.weekday % 7);
    final gridStart = firstOfMonth.subtract(Duration(days: firstWeekdayIndex));

    final totalDaysNeeded = firstWeekdayIndex + lastOfMonth.day;
    final rowCount = (totalDaysNeeded / 7).ceil().clamp(5, 6);
    final activeTasks =
        tasks.where((t) => t.task.status != TaskStatus.archived).toList();

    final cells = <CalendarDayCellData>[];

    for (int row = 0; row < rowCount; row++) {
      final rowDates = List.generate(
        7,
        (col) => DateUtilsHelper.dateOnly(
          gridStart.add(Duration(days: row * 7 + col)),
        ),
      );
      final rowStart = rowDates.first;
      final rowEnd = rowDates.last;

      // Determine which tasks appear in this week row and their column range
      final rowTaskSpans = <({
        TaskWithDetails item,
        int startCol,
        int endCol,
      })>[];

      for (final item in activeTasks) {
        final taskStart = DateUtilsHelper.dateOnly(item.task.createdDate);
        final taskEnd = item.effectiveSpanEnd(today);
        final overlapsRow =
            !taskEnd.isBefore(rowStart) && !taskStart.isAfter(rowEnd);

        // Also check if task has a due date or work log in this week outside span
        final dueDate = item.task.dueDate == null
            ? null
            : DateUtilsHelper.dateOnly(item.task.dueDate!);
        final hasDueInRow = dueDate != null &&
            !dueDate.isBefore(rowStart) &&
            !dueDate.isAfter(rowEnd);

        if (!overlapsRow && !hasDueInRow) continue;

        final activeCols = <int>[];
        for (int col = 0; col < 7; col++) {
          final d = rowDates[col];
          final inSpan = !d.isBefore(taskStart) && !d.isAfter(taskEnd);
          final effort = item.effortMinutesOn(d);
          final isDue = dueDate != null && d == dueDate;
          if (inSpan || effort > 0 || isDue) {
            activeCols.add(col);
          }
        }
        if (activeCols.isNotEmpty) {
          rowTaskSpans.add((
            item: item,
            startCol: activeCols.first,
            endCol: activeCols.last,
          ));
        }
      }

      // Sort by startCol, then longer spans first, then creation date
      rowTaskSpans.sort((a, b) {
        final colCmp = a.startCol.compareTo(b.startCol);
        if (colCmp != 0) return colCmp;
        final lenCmp = (b.endCol - b.startCol).compareTo(a.endCol - a.startCol);
        if (lenCmp != 0) return lenCmp;
        return a.item.task.createdDate.compareTo(b.item.task.createdDate);
      });

      // Greedy slot assignment across the 7 columns of this week row
      final occupied = List.generate(7, (_) => <int>{});
      final assignedSlots = <String, int>{};

      for (final span in rowTaskSpans) {
        int slot = 0;
        while (true) {
          var free = true;
          for (int c = span.startCol; c <= span.endCol; c++) {
            if (occupied[c].contains(slot)) {
              free = false;
              break;
            }
          }
          if (free) break;
          slot++;
        }
        for (int c = span.startCol; c <= span.endCol; c++) {
          occupied[c].add(slot);
        }
        assignedSlots[span.item.task.id] = slot;
      }

      // Build day cells for this row
      for (int col = 0; col < 7; col++) {
        final date = rowDates[col];
        final dateKey = DateUtilsHelper.toDateKey(date);
        final lunar = DateUtilsHelper.lunarLabel(date);

        final entries = <CalendarDayTaskEntry>[];
        for (final span in rowTaskSpans) {
          if (col < span.startCol || col > span.endCol) continue;

          final item = span.item;
          final taskStart = DateUtilsHelper.dateOnly(item.task.createdDate);
          final taskEnd = item.effectiveSpanEnd(today);
          final inSpan = !date.isBefore(taskStart) && !date.isAfter(taskEnd);
          final effortToday = item.effortMinutesOn(date);
          final isDueToday = item.task.dueDate != null &&
              DateUtilsHelper.toDateKey(item.task.dueDate!) == dateKey;
          final isCompletedToday = item.task.status == TaskStatus.completed &&
              item.task.completedDate != null &&
              DateUtilsHelper.toDateKey(item.task.completedDate!) == dateKey;

          if (!inSpan && effortToday == 0 && !isDueToday) continue;

          final prevDate = col > 0 ? rowDates[col - 1] : null;
          final nextDate = col < 6 ? rowDates[col + 1] : null;
          final prevInSpan = prevDate != null &&
              !prevDate.isBefore(taskStart) &&
              !prevDate.isAfter(taskEnd);
          final nextInSpan = nextDate != null &&
              !nextDate.isBefore(taskStart) &&
              !nextDate.isAfter(taskEnd);

          entries.add(CalendarDayTaskEntry(
            taskWithDetails: item,
            effortMinutesToday: effortToday,
            isSpanActive: inSpan,
            isDueToday: isDueToday,
            isCompletedToday: isCompletedToday,
            slotIndex: assignedSlots[item.task.id] ?? 0,
            isSpanStartInRow: !inSpan || !prevInSpan,
            isSpanEndInRow: !inSpan || !nextInSpan,
          ));
        }

        entries.sort((a, b) => a.slotIndex.compareTo(b.slotIndex));

        cells.add(CalendarDayCellData(
          date: date,
          isCurrentMonth: date.month == month && date.year == year,
          isToday:
              DateUtilsHelper.toDateKey(date) == DateUtilsHelper.toDateKey(today),
          lunarText: lunar.text,
          isLunarHighlight: lunar.isHighlight,
          isoWeekNumber: col == 0 ? DateUtilsHelper.isoWeekNumber(date) : null,
          entries: entries,
          maxVisibleBars: maxVisibleBars,
        ));
      }
    }

    return cells;
  }
}
