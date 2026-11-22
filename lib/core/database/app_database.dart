import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite database manager for PocketSpan.
class AppDatabase {
  static const int _version = 4;
  static const int schemaVersion = _version;
  static const String _defaultDbName = 'pocket_span.db';

  Database? _db;
  final String? customPath;

  AppDatabase({this.customPath});

  /// Opens (and initializes if needed) the SQLite database.
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    final dbPath = customPath ?? join(await getDatabasesPath(), _defaultDbName);
    _db = await openDatabase(
      dbPath,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      const migrations = [
        ('tag_work', '#FCE8E8', '#E55353', '#40C48B8B', '#DEB06B6B'),
        ('tag_life', '#E6F7EE', '#16A34A', '#407FA68E', '#DE638C73'),
        ('tag_study', '#E8F0FE', '#4F78FF', '#407C96B3', '#DE5E7C9E'),
        ('tag_personal', '#FEF3C7', '#D97706', '#40C29B76', '#DEB38357'),
      ];
      for (final (id, oldLight, oldDark, newLight, newDark) in migrations) {
        await db.update(
          'tags',
          {'light_color_hex': newLight, 'dark_color_hex': newDark},
          where: 'id = ? AND light_color_hex = ? AND dark_color_hex = ?',
          whereArgs: [id, oldLight, oldDark],
        );
      }
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN reminder_at_due INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN reminder_lead_days INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN reminder_daily_times TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN reminder_weekly_days TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN reminder_weekly_time TEXT NOT NULL DEFAULT '09:30'",
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        light_color_hex TEXT NOT NULL,
        dark_color_hex TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        primary_tag_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        created_date TEXT NOT NULL,
        due_date INTEGER,
        completed_date TEXT,
        reminder_at_due INTEGER NOT NULL DEFAULT 1,
        reminder_lead_days INTEGER NOT NULL DEFAULT 0,
        reminder_daily_times TEXT NOT NULL DEFAULT '',
        reminder_weekly_days TEXT NOT NULL DEFAULT '',
        reminder_weekly_time TEXT NOT NULL DEFAULT '09:30',
        FOREIGN KEY (primary_tag_id) REFERENCES tags(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE task_tags (
        task_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        is_primary INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (task_id, tag_id),
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE work_logs (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        work_date TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        memo TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        notification_id INTEGER NOT NULL,
        offset_minutes INTEGER NOT NULL,
        trigger_at INTEGER NOT NULL,
        is_fired INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_work_logs_task_date ON work_logs(task_id, work_date)',
    );
    await db.execute(
      'CREATE INDEX idx_tasks_status ON tasks(status)',
    );

    await _seedDefaultTags(db);
  }

  Future<void> _seedDefaultTags(Database db) async {
    const defaults = [
      {
        'id': 'tag_work',
        'name': '工作',
        'light_color_hex': '#40C48B8B',
        'dark_color_hex': '#DEB06B6B',
        'sort_order': 0,
      },
      {
        'id': 'tag_life',
        'name': '生活',
        'light_color_hex': '#407FA68E',
        'dark_color_hex': '#DE638C73',
        'sort_order': 1,
      },
      {
        'id': 'tag_study',
        'name': '学习',
        'light_color_hex': '#407C96B3',
        'dark_color_hex': '#DE5E7C9E',
        'sort_order': 2,
      },
      {
        'id': 'tag_personal',
        'name': '个人',
        'light_color_hex': '#40C29B76',
        'dark_color_hex': '#DEB38357',
        'sort_order': 3,
      },
    ];

    for (final row in defaults) {
      await db.insert('tags', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
