import '../../../../core/utils/date_utils_helper.dart';
import '../../../tags/data/models/tag_model.dart';

enum TaskStatus {
  active,
  completed,
  archived;

  String get dbValue => name.toUpperCase();

  static TaskStatus fromDb(String? value) {
    switch (value?.toUpperCase()) {
      case 'COMPLETED':
        return TaskStatus.completed;
      case 'ARCHIVED':
        return TaskStatus.archived;
      default:
        return TaskStatus.active;
    }
  }
}

/// Core task entity tracking start date, optional DDL, completion date, and primary tag.
class TaskModel {
  final String id;
  final String title;
  final String note;
  final String primaryTagId;
  final TaskStatus status;
  final DateTime createdDate;
  final DateTime? dueDate;
  final DateTime? completedDate;
  final bool reminderAtDue;
  final int reminderLeadDays;
  final List<String> reminderDailyTimes;
  final List<int> reminderWeeklyDays;
  final String reminderWeeklyTime;

  const TaskModel({
    required this.id,
    required this.title,
    this.note = '',
    required this.primaryTagId,
    this.status = TaskStatus.active,
    required this.createdDate,
    this.dueDate,
    this.completedDate,
    this.reminderAtDue = true,
    this.reminderLeadDays = 0,
    this.reminderDailyTimes = const [],
    this.reminderWeeklyDays = const [],
    this.reminderWeeklyTime = '09:30',
  });

  TaskModel copyWith({
    String? id,
    String? title,
    String? note,
    String? primaryTagId,
    TaskStatus? status,
    DateTime? createdDate,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? completedDate,
    bool clearCompletedDate = false,
    bool? reminderAtDue,
    int? reminderLeadDays,
    List<String>? reminderDailyTimes,
    List<int>? reminderWeeklyDays,
    String? reminderWeeklyTime,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      primaryTagId: primaryTagId ?? this.primaryTagId,
      status: status ?? this.status,
      createdDate: createdDate ?? this.createdDate,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      completedDate:
          clearCompletedDate ? null : (completedDate ?? this.completedDate),
      reminderAtDue: reminderAtDue ?? this.reminderAtDue,
      reminderLeadDays: reminderLeadDays ?? this.reminderLeadDays,
      reminderDailyTimes: reminderDailyTimes ?? this.reminderDailyTimes,
      reminderWeeklyDays: reminderWeeklyDays ?? this.reminderWeeklyDays,
      reminderWeeklyTime: reminderWeeklyTime ?? this.reminderWeeklyTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'primary_tag_id': primaryTagId,
      'status': status.dbValue,
      'created_date': DateUtilsHelper.toDateKey(createdDate),
      'due_date': dueDate?.millisecondsSinceEpoch,
      'completed_date': completedDate == null
          ? null
          : DateUtilsHelper.toDateKey(completedDate!),
      'reminder_at_due': reminderAtDue ? 1 : 0,
      'reminder_lead_days': reminderLeadDays,
      'reminder_daily_times': reminderDailyTimes.join(','),
      'reminder_weekly_days': reminderWeeklyDays.join(','),
      'reminder_weekly_time': reminderWeeklyTime,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    final dueMs = map['due_date'] as int?;
    final completedStr = map['completed_date'] as String?;
    final rawTimes = (map['reminder_daily_times'] as String?) ?? '';
    final parsedTimes = rawTimes
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final rawWeeklyDays = (map['reminder_weekly_days'] as String?) ?? '';
    final parsedWeeklyDays = rawWeeklyDays
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        .toList();

    return TaskModel(
      id: map['id'] as String,
      title: map['title'] as String,
      note: (map['note'] as String?) ?? '',
      primaryTagId: map['primary_tag_id'] as String,
      status: TaskStatus.fromDb(map['status'] as String?),
      createdDate: DateUtilsHelper.parseDateKey(map['created_date'] as String),
      dueDate:
          dueMs == null ? null : DateTime.fromMillisecondsSinceEpoch(dueMs),
      completedDate: completedStr == null
          ? null
          : DateUtilsHelper.parseDateKey(completedStr),
      reminderAtDue: ((map['reminder_at_due'] as int?) ?? 1) == 1,
      reminderLeadDays: (map['reminder_lead_days'] as int?) ?? 0,
      reminderDailyTimes: parsedTimes,
      reminderWeeklyDays: parsedWeeklyDays,
      reminderWeeklyTime:
          ((map['reminder_weekly_time'] as String?)?.isNotEmpty ?? false)
              ? map['reminder_weekly_time'] as String
              : '09:30',
    );
  }
}

/// Helper to generate minute-accurate reminder schedules from DDL & weekly rules.
class ReminderScheduleBuilder {
  ReminderScheduleBuilder._();

  static List<String> defaultTimesForCount(int count) {
    return switch (count) {
      1 => ['09:30'],
      2 => ['09:30', '20:00'],
      3 => ['09:00', '14:00', '20:00'],
      4 => ['09:00', '12:30', '17:00', '20:30'],
      _ => ['09:30'],
    };
  }

  static List<int> buildOffsets({
    required DateTime dueDate,
    required bool atDue,
    required int leadDays,
    required List<String> dailyTimes,
    DateTime? now,
  }) {
    final entries = buildEntries(
      startDate: dueDate,
      dueDate: dueDate,
      atDue: atDue,
      leadDays: leadDays,
      dailyTimes: dailyTimes,
      weeklyDays: const [],
      weeklyTime: '09:30',
      now: now,
    );
    return entries.map((e) => e.offsetMinutes).toList()
      ..sort((a, b) => b.compareTo(a));
  }

  /// Combines DDL on-time, lead-day daily times, and weekly fixed-time rules,
  /// deduplicating by exact trigger timestamp.
  static List<({int offsetMinutes, DateTime triggerAt})> buildEntries({
    required DateTime startDate,
    DateTime? dueDate,
    required bool atDue,
    required int leadDays,
    required List<String> dailyTimes,
    required List<int> weeklyDays,
    required String weeklyTime,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    final byMillis = <int, ({int offsetMinutes, DateTime triggerAt})>{};

    void addTrigger(DateTime triggerAt, int offsetMinutes) {
      byMillis.putIfAbsent(
        triggerAt.millisecondsSinceEpoch,
        () => (offsetMinutes: offsetMinutes, triggerAt: triggerAt),
      );
    }

    if (dueDate != null) {
      if (atDue && !dueDate.isBefore(referenceNow)) {
        addTrigger(dueDate, 0);
      }

      if (leadDays > 0 && dailyTimes.isNotEmpty) {
        final dueDay = DateUtilsHelper.dateOnly(dueDate);
        for (int d = leadDays; d >= 0; d--) {
          final day = dueDay.subtract(Duration(days: d));
          for (final hhmm in dailyTimes) {
            final parsed = _parseHHmm(hhmm);
            if (parsed == null) continue;
            final triggerAt = DateTime(
              day.year,
              day.month,
              day.day,
              parsed.$1,
              parsed.$2,
            );
            if (triggerAt.isAfter(referenceNow) && triggerAt.isBefore(dueDate)) {
              final diff = dueDate.difference(triggerAt).inMinutes;
              if (diff > 0) addTrigger(triggerAt, diff);
            }
          }
        }
      }
    }

    if (weeklyDays.isNotEmpty) {
      final parsed = _parseHHmm(weeklyTime);
      if (parsed != null) {
        final todayOnly = DateUtilsHelper.dateOnly(referenceNow);
        final startOnly = DateUtilsHelper.dateOnly(startDate);
        final windowStart =
            startOnly.isAfter(todayOnly) ? startOnly : todayOnly;
        final maxEnd = windowStart.add(const Duration(days: 84)); // 12 weeks
        final dueDay =
            dueDate != null ? DateUtilsHelper.dateOnly(dueDate) : null;
        final windowEnd =
            (dueDay != null && dueDay.isBefore(maxEnd)) ? dueDay : maxEnd;

        int weeklyAdded = 0;
        for (DateTime day = windowStart;
            !day.isAfter(windowEnd) && weeklyAdded < 60;
            day = day.add(const Duration(days: 1))) {
          if (!weeklyDays.contains(day.weekday)) continue;
          final triggerAt = DateTime(
            day.year,
            day.month,
            day.day,
            parsed.$1,
            parsed.$2,
          );
          if (!triggerAt.isAfter(referenceNow)) continue;
          if (dueDate != null && !triggerAt.isBefore(dueDate)) continue;

          final offset =
              dueDate != null ? dueDate.difference(triggerAt).inMinutes : -1;
          addTrigger(triggerAt, offset);
          weeklyAdded++;
        }
      }
    }

    final result = byMillis.values.toList()
      ..sort((a, b) => a.triggerAt.compareTo(b.triggerAt));
    return result;
  }

  static (int, int)? _parseHHmm(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return (h, m);
  }
}

/// Minute-level effort mark logged against a task on a specific date.
class WorkLogModel {
  final String id;
  final String taskId;
  final DateTime workDate;
  final int durationMinutes;
  final String memo;
  final int createdAtMillis;

  const WorkLogModel({
    required this.id,
    required this.taskId,
    required this.workDate,
    required this.durationMinutes,
    this.memo = '',
    required this.createdAtMillis,
  });

  WorkLogModel copyWith({
    String? id,
    String? taskId,
    DateTime? workDate,
    int? durationMinutes,
    String? memo,
    int? createdAtMillis,
  }) {
    return WorkLogModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      workDate: workDate ?? this.workDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      memo: memo ?? this.memo,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'work_date': DateUtilsHelper.toDateKey(workDate),
      'duration_minutes': durationMinutes,
      'memo': memo,
      'created_at': createdAtMillis,
    };
  }

  factory WorkLogModel.fromMap(Map<String, dynamic> map) {
    return WorkLogModel(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      workDate: DateUtilsHelper.parseDateKey(map['work_date'] as String),
      durationMinutes: map['duration_minutes'] as int,
      memo: (map['memo'] as String?) ?? '',
      createdAtMillis: (map['created_at'] as int?) ?? 0,
    );
  }
}

/// Scheduled local deadline reminder associated with a task.
class ReminderModel {
  final String id;
  final String taskId;
  final int notificationId;
  final int offsetMinutes;
  final DateTime triggerAt;
  final bool isFired;

  const ReminderModel({
    required this.id,
    required this.taskId,
    required this.notificationId,
    required this.offsetMinutes,
    required this.triggerAt,
    this.isFired = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'notification_id': notificationId,
      'offset_minutes': offsetMinutes,
      'trigger_at': triggerAt.millisecondsSinceEpoch,
      'is_fired': isFired ? 1 : 0,
    };
  }

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      notificationId: map['notification_id'] as int,
      offsetMinutes: map['offset_minutes'] as int,
      triggerAt: DateTime.fromMillisecondsSinceEpoch(map['trigger_at'] as int),
      isFired: (map['is_fired'] as int? ?? 0) == 1,
    );
  }
}

/// Rich view model combining a [TaskModel] with its tags, work logs, and efficiency metrics.
class TaskWithDetails {
  final TaskModel task;
  final TagModel primaryTag;
  final List<TagModel> tags;
  final List<WorkLogModel> workLogs;
  final List<ReminderModel> reminders;

  const TaskWithDetails({
    required this.task,
    required this.primaryTag,
    required this.tags,
    required this.workLogs,
    this.reminders = const [],
  });

  int get totalEffortMinutes =>
      workLogs.fold<int>(0, (sum, log) => sum + log.durationMinutes);

  /// End date of the light-color duration span:
  /// - Completed tasks end at [task.completedDate] (or today if missing).
  /// - Future active tasks (`createdDate > today`) span at least their scheduled start date.
  /// - Past/current active tasks strictly end at [today].
  DateTime effectiveSpanEnd([DateTime? referenceToday]) {
    final today = DateUtilsHelper.dateOnly(referenceToday ?? DateTime.now());
    final start = DateUtilsHelper.dateOnly(task.createdDate);
    if (task.status == TaskStatus.completed && task.completedDate != null) {
      return DateUtilsHelper.dateOnly(task.completedDate!);
    }
    if (start.isAfter(today)) {
      return start;
    }
    return today;
  }

  /// Inclusive lifecycle duration span in days.
  int spanDays([DateTime? referenceToday]) {
    final start = DateUtilsHelper.dateOnly(task.createdDate);
    final end = effectiveSpanEnd(referenceToday);
    if (end.isBefore(start)) return 1;
    return DateUtilsHelper.daysBetweenInclusive(start, end);
  }

  /// Days elapsed between [task.createdDate] and the earliest [WorkLogModel], if any.
  int? get startDelayDays {
    if (workLogs.isEmpty) return null;
    final earliest = workLogs
        .map((w) => DateUtilsHelper.dateOnly(w.workDate))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = DateUtilsHelper.daysBetween(task.createdDate, earliest);
    return delay < 0 ? 0 : delay;
  }

  /// Sum of effort minutes logged on a specific calendar date.
  int effortMinutesOn(DateTime date) {
    final key = DateUtilsHelper.toDateKey(date);
    return workLogs
        .where((w) => DateUtilsHelper.toDateKey(w.workDate) == key)
        .fold<int>(0, (sum, w) => sum + w.durationMinutes);
  }

  bool hasTag(String tagId) => tags.any((t) => t.id == tagId);
}
