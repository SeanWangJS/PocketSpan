import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_span/core/utils/date_utils_helper.dart';
import 'package:pocket_span/features/analysis/domain/efficiency_calculator.dart';
import 'package:pocket_span/features/calendar/domain/calendar_grid_calculator.dart';
import 'package:pocket_span/features/tags/data/models/tag_model.dart';
import 'package:pocket_span/features/tasks/data/models/task_model.dart';

void main() {
  const workTag = TagModel(
    id: 'tag_work',
    name: '工作',
    lightColorHex: '#FCE8E8',
    darkColorHex: '#E55353',
  );
  const lifeTag = TagModel(
    id: 'tag_life',
    name: '生活',
    lightColorHex: '#E6F7EE',
    darkColorHex: '#16A34A',
  );

  test('CalendarGridCalculator renders light span and dark effort bars accurately', () {
    final completedTask = TaskWithDetails(
      task: TaskModel(
        id: 't1',
        title: '东华卓越',
        primaryTagId: 'tag_work',
        status: TaskStatus.completed,
        createdDate: DateTime(2026, 11, 1),
        dueDate: DateTime(2026, 11, 15),
        completedDate: DateTime(2026, 11, 12),
      ),
      primaryTag: workTag,
      tags: [workTag],
      workLogs: [
        WorkLogModel(
          id: 'l1',
          taskId: 't1',
          workDate: DateTime(2026, 11, 5),
          durationMinutes: 300,
          createdAtMillis: 1,
        ),
        WorkLogModel(
          id: 'l2',
          taskId: 't1',
          workDate: DateTime(2026, 11, 7),
          durationMinutes: 180,
          createdAtMillis: 2,
        ),
        WorkLogModel(
          id: 'l3',
          taskId: 't1',
          workDate: DateTime(2026, 11, 12),
          durationMinutes: 480,
          createdAtMillis: 3,
        ),
      ],
    );

    final cells = CalendarGridCalculator.buildMonthGrid(
      year: 2026,
      month: 11,
      tasks: [completedTask],
      referenceToday: DateTime(2026, 11, 20),
    );

    CalendarDayCellData cellFor(int day) => cells.firstWhere(
          (c) => c.isCurrentMonth && c.date.day == day,
        );

    // Day 1: light span & row start -> shows title; Day 2: continuation -> no repeated title
    expect(cellFor(1).entries.length, 1);
    expect(cellFor(1).entries.first.isDarkEffort, isFalse);
    expect(cellFor(1).entries.first.isSpanActive, isTrue);
    expect(cellFor(1).entries.first.isSpanStartInRow, isTrue);
    expect(cellFor(1).entries.first.isSpanEndInRow, isFalse);

    expect(cellFor(2).entries.first.isSpanStartInRow, isFalse);
    expect(cellFor(2).entries.first.isSpanEndInRow, isFalse);
    expect(cellFor(2).entries.first.slotIndex, cellFor(1).entries.first.slotIndex);

    // Day 5, 7, 12: dark effort
    expect(cellFor(5).entries.first.isDarkEffort, isTrue);
    expect(cellFor(5).entries.first.effortMinutesToday, 300);
    expect(cellFor(7).entries.first.isDarkEffort, isTrue);
    expect(cellFor(7).entries.first.effortMinutesToday, 180);
    expect(cellFor(7).entries.first.isSpanEndInRow, isTrue);
    expect(cellFor(8).entries.first.isSpanStartInRow, isTrue); // New week row starts title cleanly
    expect(cellFor(12).entries.first.isDarkEffort, isTrue);
    expect(cellFor(12).entries.first.isCompletedToday, isTrue);
    expect(cellFor(12).entries.first.isSpanEndInRow, isTrue);

    // Day 13: no longer in span; Day 15: DDL marker only
    expect(cellFor(13).entries, isEmpty);
    expect(cellFor(15).entries.length, 1);
    expect(cellFor(15).entries.first.isDueToday, isTrue);
    expect(cellFor(15).entries.first.isSpanActive, isFalse);
  });

  test('CalendarGridCalculator renders future tasks on their scheduled start date', () {
    final futureTask = TaskWithDetails(
      task: TaskModel(
        id: 'f1',
        title: '未来计划',
        primaryTagId: 'tag_life',
        status: TaskStatus.active,
        createdDate: DateTime(2026, 11, 25),
      ),
      primaryTag: lifeTag,
      tags: [lifeTag],
      workLogs: const [],
    );

    final cells = CalendarGridCalculator.buildMonthGrid(
      year: 2026,
      month: 11,
      tasks: [futureTask],
      referenceToday: DateTime(2026, 11, 21),
    );

    final day21 = cells.firstWhere((c) => c.isCurrentMonth && c.date.day == 21);
    final day25 = cells.firstWhere((c) => c.isCurrentMonth && c.date.day == 25);

    expect(day21.entries, isEmpty);
    expect(day25.entries.length, 1);
    expect(day25.entries.first.taskWithDetails.task.title, '未来计划');
    expect(day25.entries.first.isSpanStartInRow, isTrue);
    expect(day25.entries.first.isSpanEndInRow, isTrue);
  });

  test('CalendarGridCalculator stops unfinished light span at today and handles overflow', () {
    final activeTasks = List.generate(5, (i) {
      return TaskWithDetails(
        task: TaskModel(
          id: 'a$i',
          title: '事项$i',
          primaryTagId: 'tag_life',
          status: TaskStatus.active,
          createdDate: DateTime(2026, 11, 2),
          dueDate: DateTime(2026, 11, 25),
        ),
        primaryTag: lifeTag,
        tags: [lifeTag],
        workLogs: const [],
      );
    });

    final cells = CalendarGridCalculator.buildMonthGrid(
      year: 2026,
      month: 11,
      tasks: activeTasks,
      referenceToday: DateTime(2026, 11, 10),
      maxVisibleBars: 3,
    );

    final day10 = cells.firstWhere((c) => c.isCurrentMonth && c.date.day == 10);
    final day11 = cells.firstWhere((c) => c.isCurrentMonth && c.date.day == 11);

    expect(day10.entries.length, 5);
    expect(day10.visibleEntries.length, 2);
    expect(day10.overflowCount, 3);
    expect(day11.entries, isEmpty);
  });

  test('EfficiencyCalculator computes Week/Month/Year effort, on-time rate, and tag ratios', () {
    final tasks = [
      TaskWithDetails(
        task: TaskModel(
          id: 't1',
          title: '工作任务A',
          primaryTagId: 'tag_work',
          status: TaskStatus.completed,
          createdDate: DateTime(2026, 11, 1),
          dueDate: DateTime(2026, 11, 15),
          completedDate: DateTime(2026, 11, 12),
        ),
        primaryTag: workTag,
        tags: [workTag, lifeTag],
        workLogs: [
          WorkLogModel(
            id: 'w1',
            taskId: 't1',
            workDate: DateTime(2026, 11, 5),
            durationMinutes: 120,
            createdAtMillis: 1,
          ),
          WorkLogModel(
            id: 'w2',
            taskId: 't1',
            workDate: DateTime(2026, 10, 28),
            durationMinutes: 60,
            createdAtMillis: 2,
          ),
        ],
      ),
      TaskWithDetails(
        task: TaskModel(
          id: 't2',
          title: '生活采购',
          primaryTagId: 'tag_life',
          status: TaskStatus.active,
          createdDate: DateTime(2026, 11, 4),
        ),
        primaryTag: lifeTag,
        tags: [lifeTag],
        workLogs: [
          WorkLogModel(
            id: 'w3',
            taskId: 't2',
            workDate: DateTime(2026, 11, 6),
            durationMinutes: 60,
            createdAtMillis: 3,
          ),
        ],
      ),
    ];

    final monthRes = EfficiencyCalculator.calculate(
      tasks: tasks,
      periodType: EfficiencyPeriodType.month,
      anchorDate: DateTime(2026, 11, 10),
      referenceToday: DateTime(2026, 11, 20),
    );

    expect(monthRes.totalEffortMinutes, 180);
    expect(monthRes.prevEffortMinutes, 60);
    expect(monthRes.effortChangeRate, closeTo(200.0, 0.01));
    expect(monthRes.completedCount, 1);
    expect(monthRes.onTimeRate, 100.0);
    expect(monthRes.tagBreakdowns.length, 2);
    expect(monthRes.tagBreakdowns.first.tag.id, 'tag_work');
    expect(monthRes.tagBreakdowns.first.ratio, closeTo(2 / 3, 0.01));
    expect(monthRes.trendPoints.length, 30);

    final yearRes = EfficiencyCalculator.calculate(
      tasks: tasks,
      periodType: EfficiencyPeriodType.year,
      anchorDate: DateTime(2026, 11, 10),
      referenceToday: DateTime(2026, 11, 20),
    );
    expect(yearRes.totalEffortMinutes, 240);
    expect(yearRes.trendPoints.length, 12);
    expect(DateUtilsHelper.toDateKey(yearRes.periodStart), '2026-01-01');
  });
}
