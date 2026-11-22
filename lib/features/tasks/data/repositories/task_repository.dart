import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/date_utils_helper.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../tags/data/models/tag_model.dart';
import '../models/task_model.dart';

/// Repository for tasks, multi-tag links, minute-level work logs, and reminders.
class TaskRepository {
  final AppDatabase _database;

  TaskRepository(this._database);

  Future<List<TaskWithDetails>> getAllTasksWithDetails() async {
    final db = await _database.database;
    final tagRows = await db.query('tags', orderBy: 'sort_order ASC');
    final tagMap = <String, TagModel>{
      for (final row in tagRows) (row['id'] as String): TagModel.fromMap(row),
    };

    final taskRows = await db.query(
      'tasks',
      orderBy: 'created_date DESC, rowid DESC',
    );
    if (taskRows.isEmpty) return [];

    final taskTagRows = await db.query('task_tags');
    final workLogRows = await db.query(
      'work_logs',
      orderBy: 'work_date DESC, created_at DESC',
    );
    final reminderRows = await db.query(
      'reminders',
      orderBy: 'trigger_at ASC',
    );

    final tagsByTask = <String, List<TagModel>>{};
    for (final row in taskTagRows) {
      final taskId = row['task_id'] as String;
      final tagId = row['tag_id'] as String;
      final tag = tagMap[tagId];
      if (tag != null) {
        tagsByTask.putIfAbsent(taskId, () => []).add(tag);
      }
    }

    final logsByTask = <String, List<WorkLogModel>>{};
    for (final row in workLogRows) {
      final log = WorkLogModel.fromMap(row);
      logsByTask.putIfAbsent(log.taskId, () => []).add(log);
    }

    final remindersByTask = <String, List<ReminderModel>>{};
    for (final row in reminderRows) {
      final r = ReminderModel.fromMap(row);
      remindersByTask.putIfAbsent(r.taskId, () => []).add(r);
    }

    final fallbackTag = tagMap.values.first;
    final results = <TaskWithDetails>[];

    for (final row in taskRows) {
      final task = TaskModel.fromMap(row);
      final primaryTag = tagMap[task.primaryTagId] ?? fallbackTag;
      final attachedTags = tagsByTask[task.id] ?? [primaryTag];
      if (!attachedTags.any((t) => t.id == primaryTag.id)) {
        attachedTags.insert(0, primaryTag);
      } else {
        // Ensure primary tag comes first for consistent UI display
        attachedTags.sort((a, b) {
          if (a.id == primaryTag.id) return -1;
          if (b.id == primaryTag.id) return 1;
          return a.sortOrder.compareTo(b.sortOrder);
        });
      }

      results.add(TaskWithDetails(
        task: task,
        primaryTag: primaryTag,
        tags: attachedTags,
        workLogs: logsByTask[task.id] ?? const [],
        reminders: remindersByTask[task.id] ?? const [],
      ));
    }

    return results;
  }

  Future<TaskWithDetails?> getTaskWithDetails(String taskId) async {
    final all = await getAllTasksWithDetails();
    for (final item in all) {
      if (item.task.id == taskId) return item;
    }
    return null;
  }

  Future<TaskModel> createTask({
    required String title,
    String note = '',
    required String primaryTagId,
    List<String> tagIds = const [],
    required DateTime createdDate,
    DateTime? dueDate,
    bool reminderAtDue = true,
    int reminderLeadDays = 0,
    List<String> reminderDailyTimes = const [],
    List<int> reminderWeeklyDays = const [],
    String reminderWeeklyTime = '09:30',
    List<int> reminderOffsetsMinutes = const [],
    List<({int offsetMinutes, DateTime triggerAt})> scheduledReminders = const [],
  }) async {
    final db = await _database.database;
    final id = IdGenerator.next('task');
    final normalizedTags = <String>{primaryTagId, ...tagIds}.toList();

    final task = TaskModel(
      id: id,
      title: title.trim(),
      note: note.trim(),
      primaryTagId: primaryTagId,
      status: TaskStatus.active,
      createdDate: DateUtilsHelper.dateOnly(createdDate),
      dueDate: dueDate,
      reminderAtDue: reminderAtDue,
      reminderLeadDays: reminderLeadDays,
      reminderDailyTimes: reminderDailyTimes,
      reminderWeeklyDays: reminderWeeklyDays,
      reminderWeeklyTime: reminderWeeklyTime,
    );

    await db.transaction((txn) async {
      await txn.insert('tasks', task.toMap());
      for (final tagId in normalizedTags) {
        await txn.insert('task_tags', {
          'task_id': id,
          'tag_id': tagId,
          'is_primary': tagId == primaryTagId ? 1 : 0,
        });
      }
      if (scheduledReminders.isNotEmpty) {
        await _replaceScheduledRemindersInTxn(txn, id, scheduledReminders);
      } else if (dueDate != null && reminderOffsetsMinutes.isNotEmpty) {
        await _replaceRemindersInTxn(txn, id, dueDate, reminderOffsetsMinutes);
      }
    });

    return task;
  }

  Future<void> updateTask({
    required TaskModel task,
    required List<String> tagIds,
    List<int> reminderOffsetsMinutes = const [],
    List<({int offsetMinutes, DateTime triggerAt})> scheduledReminders = const [],
  }) async {
    final db = await _database.database;
    final normalizedTags = <String>{task.primaryTagId, ...tagIds}.toList();

    await db.transaction((txn) async {
      await txn.update(
        'tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
      await txn.delete('task_tags', where: 'task_id = ?', whereArgs: [task.id]);
      for (final tagId in normalizedTags) {
        await txn.insert('task_tags', {
          'task_id': task.id,
          'tag_id': tagId,
          'is_primary': tagId == task.primaryTagId ? 1 : 0,
        });
      }
      await txn.delete('reminders', where: 'task_id = ?', whereArgs: [task.id]);
      if (task.status == TaskStatus.active) {
        if (scheduledReminders.isNotEmpty) {
          await _replaceScheduledRemindersInTxn(
            txn,
            task.id,
            scheduledReminders,
          );
        } else if (task.dueDate != null && reminderOffsetsMinutes.isNotEmpty) {
          await _replaceRemindersInTxn(
            txn,
            task.id,
            task.dueDate!,
            reminderOffsetsMinutes,
          );
        }
      }
    });
  }

  Future<void> deleteTask(String taskId) async {
    final db = await _database.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
  }

  Future<WorkLogModel> addWorkLog({
    required String taskId,
    required DateTime workDate,
    required int durationMinutes,
    String memo = '',
    bool markTaskCompleted = false,
  }) async {
    final db = await _database.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final log = WorkLogModel(
      id: IdGenerator.next('log'),
      taskId: taskId,
      workDate: DateUtilsHelper.dateOnly(workDate),
      durationMinutes: durationMinutes,
      memo: memo.trim(),
      createdAtMillis: nowMs,
    );

    await db.transaction((txn) async {
      await txn.insert('work_logs', log.toMap());
      if (markTaskCompleted) {
        await txn.update(
          'tasks',
          {
            'status': TaskStatus.completed.dbValue,
            'completed_date': DateUtilsHelper.toDateKey(workDate),
          },
          where: 'id = ?',
          whereArgs: [taskId],
        );
      }
    });

    return log;
  }

  Future<void> updateWorkLog(WorkLogModel log) async {
    final db = await _database.database;
    await db.update(
      'work_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<void> deleteWorkLog(String workLogId) async {
    final db = await _database.database;
    await db.delete('work_logs', where: 'id = ?', whereArgs: [workLogId]);
  }

  Future<void> setTaskStatus({
    required String taskId,
    required TaskStatus status,
    DateTime? completedDate,
  }) async {
    final db = await _database.database;
    await db.update(
      'tasks',
      {
        'status': status.dbValue,
        'completed_date': status == TaskStatus.completed
            ? DateUtilsHelper.toDateKey(completedDate ?? DateTime.now())
            : null,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> _replaceScheduledRemindersInTxn(
    Transaction txn,
    String taskId,
    List<({int offsetMinutes, DateTime triggerAt})> entries,
  ) async {
    for (final entry in entries) {
      final millis = entry.triggerAt.millisecondsSinceEpoch;
      final notificationId = ('${taskId}_$millis'.hashCode & 0x7FFFFFFF);
      await txn.insert('reminders', {
        'id': 'rem_${taskId}_$millis',
        'task_id': taskId,
        'notification_id': notificationId,
        'offset_minutes': entry.offsetMinutes,
        'trigger_at': millis,
        'is_fired': 0,
      });
    }
  }

  Future<void> _replaceRemindersInTxn(
    Transaction txn,
    String taskId,
    DateTime dueDate,
    List<int> offsetsMinutes,
  ) async {
    for (final offset in offsetsMinutes.toSet()) {
      final triggerAt = dueDate.subtract(Duration(minutes: offset));
      final notificationId =
          ('${taskId}_$offset'.hashCode & 0x7FFFFFFF);
      await txn.insert('reminders', {
        'id': 'rem_${taskId}_$offset',
        'task_id': taskId,
        'notification_id': notificationId,
        'offset_minutes': offset,
        'trigger_at': triggerAt.millisecondsSinceEpoch,
        'is_fired': 0,
      });
    }
  }
}
