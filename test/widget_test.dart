import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_span/core/database/app_database.dart';
import 'package:pocket_span/features/reminders/data/notification_service.dart';
import 'package:pocket_span/features/tasks/data/models/task_model.dart';
import 'package:pocket_span/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _NoopNotificationService extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> syncTaskReminders(List<TaskWithDetails> tasks) async {}
}

Future<void> _waitForLoadingToFinish(WidgetTester tester) async {
  for (int i = 0; i < 120; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    });
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('PocketSpan renders 4 tabs, opens DayDetailScreen on any date tap, and switches to analytics',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(customPath: inMemoryDatabasePath);
    await tester.runAsync(() async {
      await db.database;
    });
    addTearDown(() async {
      await tester.runAsync(() async {
        await db.close();
      });
    });

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      PocketSpanApp(
        database: db,
        notificationService: _NoopNotificationService(),
      ),
    );
    await _waitForLoadingToFinish(tester);

    // Verify 4 bottom navigation tabs
    expect(find.text('视图'), findsOneWidget);
    expect(find.text('待办'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    // Tapping an empty calendar day cell (e.g. day 15) should open DayDetailScreen
    await tester.tap(find.text('15').first);
    await tester.pump();
    await _waitForLoadingToFinish(tester);
    expect(find.text('这一天还没有事项记录'), findsOneWidget);

    // Navigate back and switch to 统计 tab
    Navigator.of(tester.element(find.text('这一天还没有事项记录'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('效率统计'), findsOneWidget);
    expect(find.text('周'), findsOneWidget);
    expect(find.text('月'), findsOneWidget);
    expect(find.text('年'), findsOneWidget);
    expect(find.text('持续跨度 vs 实际工时'), findsOneWidget);

    // Switch to 我的 tab
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('标签管理'), findsOneWidget);
    expect(find.text('外观主题'), findsOneWidget);
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);

    // Switch to dark theme and back to light theme
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(find.text('当前：深色'), findsOneWidget);

    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    expect(find.text('当前：浅色'), findsOneWidget);
  });
}
