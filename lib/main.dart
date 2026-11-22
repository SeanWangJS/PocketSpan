import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_colors.dart';
import 'core/database/app_database.dart';
import 'features/analysis/presentation/screens/analysis_screen.dart';
import 'features/calendar/presentation/screens/calendar_screen.dart';
import 'features/reminders/data/notification_service.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/tags/data/models/tag_model.dart';
import 'features/tags/data/repositories/tag_repository.dart';
import 'features/tasks/data/models/task_model.dart';
import 'features/tasks/data/repositories/task_repository.dart';
import 'features/todo/presentation/screens/todo_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PocketSpanApp());
}

class PocketSpanApp extends StatefulWidget {
  final AppDatabase? database;
  final NotificationService? notificationService;

  const PocketSpanApp({
    super.key,
    this.database,
    this.notificationService,
  });

  @override
  State<PocketSpanApp> createState() => _PocketSpanAppState();
}

class _PocketSpanAppState extends State<PocketSpanApp> {
  static const _prefThemeMode = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefThemeMode);
    if (!mounted || saved == null) return;
    setState(() {
      _themeMode = switch (saved) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    };
    await prefs.setString(_prefThemeMode, value);
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketSpan',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        brightness: Brightness.dark,
      ),
      home: PocketSpanShell(
        database: widget.database,
        notificationService: widget.notificationService,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

class PocketSpanShell extends StatefulWidget {
  final AppDatabase? database;
  final NotificationService? notificationService;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const PocketSpanShell({
    super.key,
    this.database,
    this.notificationService,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<PocketSpanShell> createState() => _PocketSpanShellState();
}

class _PocketSpanShellState extends State<PocketSpanShell> {
  static const _prefWeekStartMonday = 'week_starts_on_monday';

  late final AppDatabase _database;
  late final TagRepository _tagRepo;
  late final TaskRepository _taskRepo;
  late final NotificationService _notificationService;

  int _selectedIndex = 0;
  bool _loading = true;
  bool _weekStartsOnMonday = false;
  List<TagModel> _tags = [];
  List<TaskWithDetails> _tasks = [];

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? AppDatabase();
    _tagRepo = TagRepository(_database);
    _taskRepo = TaskRepository(_database);
    _notificationService = widget.notificationService ?? NotificationService();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _notificationService.init();
    final prefs = await SharedPreferences.getInstance();
    final weekMon = prefs.getBool(_prefWeekStartMonday) ?? false;
    final tags = await _tagRepo.getAllTags();
    final tasks = await _taskRepo.getAllTasksWithDetails();
    await _notificationService.syncTaskReminders(tasks);

    if (!mounted) return;
    setState(() {
      _weekStartsOnMonday = weekMon;
      _tags = tags;
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<void> _reloadData() async {
    final tags = await _tagRepo.getAllTags();
    final tasks = await _taskRepo.getAllTasksWithDetails();
    await _notificationService.syncTaskReminders(tasks);
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _tasks = tasks;
    });
  }

  Future<void> _setWeekStartsOnMonday(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefWeekStartMonday, value);
    if (!mounted) return;
    setState(() => _weekStartsOnMonday = value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = [
      CalendarScreen(
        tasks: _tasks,
        tags: _tags,
        taskRepository: _taskRepo,
        weekStartsOnMonday: _weekStartsOnMonday,
        onDataChanged: _reloadData,
      ),
      TodoScreen(
        tasks: _tasks,
        tags: _tags,
        taskRepository: _taskRepo,
        onDataChanged: _reloadData,
      ),
      AnalysisScreen(
        tasks: _tasks,
        tags: _tags,
        taskRepository: _taskRepo,
        weekStartsOnMonday: _weekStartsOnMonday,
        onDataChanged: _reloadData,
      ),
      SettingsScreen(
        database: _database,
        tasks: _tasks,
        tags: _tags,
        tagRepository: _tagRepo,
        weekStartsOnMonday: _weekStartsOnMonday,
        onWeekStartChanged: _setWeekStartsOnMonday,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        onDataChanged: _reloadData,
      ),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: '视图',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline_rounded),
            selectedIcon: Icon(Icons.check_circle_rounded),
            label: '待办',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
