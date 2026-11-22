import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';

/// Snapshot metadata and serialized JSON payload for full user data backup.
class BackupExportResult {
  final String fileName;
  final String jsonString;
  final int schemaVersion;
  final int dbVersion;
  final int tagCount;
  final int taskCount;
  final int workLogCount;
  final int reminderCount;

  const BackupExportResult({
    required this.fileName,
    required this.jsonString,
    required this.schemaVersion,
    required this.dbVersion,
    required this.tagCount,
    required this.taskCount,
    required this.workLogCount,
    required this.reminderCount,
  });
}

/// Builds versioned JSON backups of all SQLite tables & user preferences.
class DataBackupService {
  DataBackupService._();

  static const int backupSchemaVersion = 1;
  static const String appVersion = '0.1.0+1';
  static const MethodChannel _channel =
      MethodChannel('com.pocketspan.pocket_span/export');

  static Future<BackupExportResult> buildBackup(
    AppDatabase database, {
    DateTime? now,
  }) async {
    final db = await database.database;
    final prefs = await SharedPreferences.getInstance();
    final timestamp = now ?? DateTime.now();

    final tags = await db.query('tags', orderBy: 'sort_order ASC');
    final tasks = await db.query('tasks', orderBy: 'created_date ASC');
    final taskTags = await db.query('task_tags');
    final workLogs = await db.query('work_logs', orderBy: 'work_date ASC');
    final reminders = await db.query('reminders', orderBy: 'trigger_at ASC');

    final payload = {
      'app': 'PocketSpan',
      'schemaVersion': backupSchemaVersion,
      'dbVersion': AppDatabase.schemaVersion,
      'appVersion': appVersion,
      'exportedAt': timestamp.toIso8601String(),
      'preferences': {
        'weekStartsOnMonday': prefs.getBool('week_starts_on_monday') ?? false,
        'themeMode': prefs.getString('theme_mode') ?? 'light',
      },
      'data': {
        'tags': tags,
        'tasks': tasks,
        'task_tags': taskTags,
        'work_logs': workLogs,
        'reminders': reminders,
      },
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(payload);
    final stamp = '${timestamp.year.toString().padLeft(4, '0')}'
        '${timestamp.month.toString().padLeft(2, '0')}'
        '${timestamp.day.toString().padLeft(2, '0')}_'
        '${timestamp.hour.toString().padLeft(2, '0')}'
        '${timestamp.minute.toString().padLeft(2, '0')}'
        '${timestamp.second.toString().padLeft(2, '0')}';

    return BackupExportResult(
      fileName: 'PocketSpan_backup_$stamp.json',
      jsonString: jsonString,
      schemaVersion: backupSchemaVersion,
      dbVersion: AppDatabase.schemaVersion,
      tagCount: tags.length,
      taskCount: tasks.length,
      workLogCount: workLogs.length,
      reminderCount: reminders.length,
    );
  }

  /// Opens the Android system document saver to write the JSON backup file.
  /// Returns the saved URI string, or null if cancelled.
  static Future<String?> saveWithSystemPicker(
    BackupExportResult backup,
  ) async {
    return _channel.invokeMethod<String>('saveJsonFile', {
      'fileName': backup.fileName,
      'content': backup.jsonString,
    });
  }
}
