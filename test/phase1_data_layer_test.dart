import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_span/core/database/app_database.dart';
import 'package:pocket_span/core/database/data_backup_service.dart';
import 'package:pocket_span/core/utils/date_utils_helper.dart';
import 'package:pocket_span/core/utils/duration_formatter.dart';
import 'package:pocket_span/features/tags/data/repositories/tag_repository.dart';
import 'package:pocket_span/features/tasks/data/models/task_model.dart';
import 'package:pocket_span/features/tasks/data/repositories/task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDb;
  late TagRepository tagRepo;
  late TaskRepository taskRepo;

  setUp(() async {
    appDb = AppDatabase(customPath: inMemoryDatabasePath);
    tagRepo = TagRepository(appDb);
    taskRepo = TaskRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
  });

  test('seeds 4 default dual-color tags and supports custom tag CRUD', () async {
    final initial = await tagRepo.getAllTags();
    expect(initial.length, 4);
    expect(initial.map((e) => e.name), containsAll(['工作', '生活', '学习', '个人']));

    final custom = await tagRepo.createTag(
      name: '科研',
      lightColorHex: '#F3E8FF',
      darkColorHex: '#8B5CF6',
    );
    final afterAdd = await tagRepo.getAllTags();
    expect(afterAdd.length, 5);
    expect(afterAdd.last.name, '科研');

    await tagRepo.deleteTag(custom.id);
    final afterDelete = await tagRepo.getAllTags();
    expect(afterDelete.length, 4);
  });

  test('models customer scenario: Nov 1 mark, Nov 5/7/12 effort marks, and completion', () async {
    final task = await taskRepo.createTask(
      title: '东华卓越项目',
      note: '按客户需求梳理完整周期',
      primaryTagId: 'tag_work',
      tagIds: ['tag_work', 'tag_study'],
      createdDate: DateTime(2026, 11, 1),
      dueDate: DateTime(2026, 11, 15, 18, 0),
      reminderOffsetsMinutes: [0, 60, 1440],
    );

    await taskRepo.addWorkLog(
      taskId: task.id,
      workDate: DateTime(2026, 11, 5),
      durationMinutes: 5 * 60,
      memo: '需求对齐与方案设计',
    );
    await taskRepo.addWorkLog(
      taskId: task.id,
      workDate: DateTime(2026, 11, 7),
      durationMinutes: 3 * 60,
      memo: '核心模块编码',
    );
    await taskRepo.addWorkLog(
      taskId: task.id,
      workDate: DateTime(2026, 11, 12),
      durationMinutes: 8 * 60,
      memo: '联调验收上线',
      markTaskCompleted: true,
    );

    final details = await taskRepo.getTaskWithDetails(task.id);
    expect(details, isNotNull);
    expect(details!.primaryTag.id, 'tag_work');
    expect(details.tags.length, 2);
    expect(details.tags.first.id, 'tag_work');
    expect(details.task.status, TaskStatus.completed);
    expect(details.task.completedDate, DateTime(2026, 11, 12));
    expect(details.totalEffortMinutes, 16 * 60);
    expect(details.spanDays(), 12);
    expect(details.startDelayDays, 4);
    expect(details.effortMinutesOn(DateTime(2026, 11, 5)), 300);
    expect(details.effortMinutesOn(DateTime(2026, 11, 6)), 0);
    expect(details.reminders.length, 3);
  });

  test('unfinished task span strictly stops at today even when due date is in the future', () async {
    final task = await taskRepo.createTask(
      title: '未完成任务',
      primaryTagId: 'tag_life',
      createdDate: DateTime(2026, 11, 1),
      dueDate: DateTime(2026, 11, 28),
    );

    final details = await taskRepo.getTaskWithDetails(task.id);
    final simulatedToday = DateTime(2026, 11, 10);
    expect(details!.effectiveSpanEnd(simulatedToday), simulatedToday);
    expect(details.spanDays(simulatedToday), 10);
  });

  test('prevents deleting a tag used as primary tag and cascades task deletion', () async {
    final task = await taskRepo.createTask(
      title: '测试级联删除',
      primaryTagId: 'tag_work',
      createdDate: DateTime(2026, 11, 20),
    );
    await taskRepo.addWorkLog(
      taskId: task.id,
      workDate: DateTime(2026, 11, 20),
      durationMinutes: 85,
    );

    await expectLater(
      tagRepo.deleteTag('tag_work'),
      throwsA(isA<StateError>()),
    );

    await taskRepo.deleteTask(task.id);
    final afterDelete = await taskRepo.getTaskWithDetails(task.id);
    expect(afterDelete, isNull);
  });

  test('formats minute-level durations and lunar labels cleanly', () {
    expect(DurationFormatter.format(0), '0m');
    expect(DurationFormatter.format(45), '45m');
    expect(DurationFormatter.format(60), '1h');
    expect(DurationFormatter.format(95), '1h 35m');
    expect(DurationFormatter.formatCompact(90), '1.5h');

    final lunar = DateUtilsHelper.lunarLabel(DateTime(2026, 11, 20));
    expect(lunar.text, isNotEmpty);
  });

  test('ReminderScheduleBuilder generates minute-exact offsets for lead days and custom daily times', () async {
    final now = DateTime(2026, 11, 20, 8, 0);
    final due = DateTime(2026, 11, 22, 18, 15);
    final offsets = ReminderScheduleBuilder.buildOffsets(
      dueDate: due,
      atDue: true,
      leadDays: 2,
      dailyTimes: const ['09:30', '20:45'],
      now: now,
    );

    // Nov 20: 09:30, 20:45; Nov 21: 09:30, 20:45; Nov 22: 09:30 (20:45 > 18:15 excluded) + DDL 18:15
    expect(offsets.length, 6);
    expect(offsets.last, 0);
    expect(
      due.subtract(Duration(minutes: offsets.first)),
      DateTime(2026, 11, 20, 9, 30),
    );

    final created = await taskRepo.createTask(
      title: 'DDL 闹钟测试',
      primaryTagId: 'tag_work',
      createdDate: DateTime(2026, 11, 20),
      dueDate: due,
      reminderAtDue: true,
      reminderLeadDays: 2,
      reminderDailyTimes: const ['09:30', '20:45'],
      reminderOffsetsMinutes: offsets,
    );

    final loaded = await taskRepo.getTaskWithDetails(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.task.reminderAtDue, isTrue);
    expect(loaded.task.reminderLeadDays, 2);
    expect(loaded.task.reminderDailyTimes, ['09:30', '20:45']);
    expect(loaded.reminders.length, 6);
  });

  test('DataBackupService exports versioned JSON containing all tables and preferences', () async {
    SharedPreferences.setMockInitialValues({
      'week_starts_on_monday': true,
      'theme_mode': 'dark',
    });
    final created = await taskRepo.createTask(
      title: '备份测试事项',
      primaryTagId: 'tag_work',
      createdDate: DateTime(2026, 11, 22),
    );
    await taskRepo.addWorkLog(
      taskId: created.id,
      workDate: DateTime(2026, 11, 22),
      durationMinutes: 60,
    );

    final backup = await DataBackupService.buildBackup(appDb);
    expect(backup.schemaVersion, DataBackupService.backupSchemaVersion);
    expect(backup.dbVersion, AppDatabase.schemaVersion);
    expect(backup.taskCount, 1);
    expect(backup.workLogCount, 1);

    final decoded = jsonDecode(backup.jsonString) as Map<String, dynamic>;
    expect(decoded['app'], 'PocketSpan');
    expect(decoded['schemaVersion'], 1);
    expect(decoded['dbVersion'], AppDatabase.schemaVersion);
    expect(decoded['preferences']['weekStartsOnMonday'], isTrue);
    expect(decoded['preferences']['themeMode'], 'dark');
    expect((decoded['data']['tags'] as List).length, 4);
    expect((decoded['data']['tasks'] as List).length, 1);
    expect((decoded['data']['work_logs'] as List).length, 1);
  });

  test('ReminderScheduleBuilder supports standalone weekly reminders and deduplicates with DDL lead days', () async {
    // 2026-11-23 is Monday
    final now = DateTime(2026, 11, 23, 8, 0);
    final standalone = ReminderScheduleBuilder.buildEntries(
      startDate: DateTime(2026, 11, 23),
      dueDate: null,
      atDue: false,
      leadDays: 0,
      dailyTimes: const [],
      weeklyDays: const [DateTime.monday, DateTime.wednesday],
      weeklyTime: '09:30',
      now: now,
    );

    expect(standalone.isNotEmpty, isTrue);
    expect(standalone.first.triggerAt, DateTime(2026, 11, 23, 9, 30));
    expect(standalone.first.offsetMinutes, -1);
    expect(standalone[1].triggerAt, DateTime(2026, 11, 25, 9, 30));

    final created = await taskRepo.createTask(
      title: '每周例行复盘',
      primaryTagId: 'tag_work',
      createdDate: DateTime(2026, 11, 23),
      reminderWeeklyDays: const [DateTime.monday, DateTime.wednesday],
      reminderWeeklyTime: '09:30',
      scheduledReminders: standalone,
    );
    final loaded = await taskRepo.getTaskWithDetails(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.task.dueDate, isNull);
    expect(loaded.task.reminderWeeklyDays, [1, 3]);
    expect(loaded.task.reminderWeeklyTime, '09:30');
    expect(loaded.reminders.length, standalone.length);

    // Combined with DDL & lead days: Nov 25 09:30 overlaps weekly & daily, should deduplicate
    final combined = ReminderScheduleBuilder.buildEntries(
      startDate: DateTime(2026, 11, 23),
      dueDate: DateTime(2026, 11, 26, 18, 0),
      atDue: true,
      leadDays: 1,
      dailyTimes: const ['09:30'],
      weeklyDays: const [DateTime.monday, DateTime.wednesday],
      weeklyTime: '09:30',
      now: now,
    );
    // Nov 23 09:30 (weekly), Nov 25 09:30 (deduped), Nov 26 09:30 (lead), Nov 26 18:00 (due) = 4
    expect(combined.length, 4);
  });
}
