import '../utils/date_utils_helper.dart';
import 'app_database.dart';

/// Seeds realistic multi-month tasks, multi-tag links, and minute-level work logs
/// so users can preview long-term calendar ribbons and Week/Month/Year analytics.
class DemoDataSeeder {
  DemoDataSeeder._();

  static Future<void> seedDemoData(AppDatabase appDb) async {
    final db = await appDb.database;
    final now = DateTime.now();
    final today = DateUtilsHelper.dateOnly(now);
    final y = today.year;
    final m = today.month;

    await db.transaction((txn) async {
      await txn.delete('reminders');
      await txn.delete('work_logs');
      await txn.delete('task_tags');
      await txn.delete('tasks');

      // Ensure 5th custom tag exists for richer tag breakdown
      await txn.insert('tags', {
        'id': 'tag_research',
        'name': '科研',
        'light_color_hex': '#F3E8FF',
        'dark_color_hex': '#8B5CF6',
        'sort_order': 4,
      });

      int seq = 0;
      Future<void> addTask({
        required String id,
        required String title,
        String note = '',
        required String primaryTagId,
        List<String> extraTagIds = const [],
        required String status,
        required DateTime createdDate,
        DateTime? dueDate,
        DateTime? completedDate,
        required List<({DateTime date, int minutes, String memo})> logs,
      }) async {
        await txn.insert('tasks', {
          'id': id,
          'title': title,
          'note': note,
          'primary_tag_id': primaryTagId,
          'status': status,
          'created_date': DateUtilsHelper.toDateKey(createdDate),
          'due_date': dueDate?.millisecondsSinceEpoch,
          'completed_date': completedDate == null
              ? null
              : DateUtilsHelper.toDateKey(completedDate),
        });

        final allTags = <String>{primaryTagId, ...extraTagIds};
        for (final tid in allTags) {
          await txn.insert('task_tags', {
            'task_id': id,
            'tag_id': tid,
            'is_primary': tid == primaryTagId ? 1 : 0,
          });
        }

        for (final log in logs) {
          seq++;
          await txn.insert('work_logs', {
            'id': 'demo_log_$seq',
            'task_id': id,
            'work_date': DateUtilsHelper.toDateKey(log.date),
            'duration_minutes': log.minutes,
            'memo': log.memo,
            'created_at': log.date.millisecondsSinceEpoch + seq,
          });
        }
      }

      DateTime monthOffset(int deltaMonths, int day) {
        final target = DateTime(y, m + deltaMonths, 1);
        final lastDay = DateTime(target.year, target.month + 1, 0).day;
        return DateTime(target.year, target.month, day.clamp(1, lastDay));
      }

      // ─── Historical months (-5 .. -1) for Year & MoM analytics ─────────────
      await addTask(
        id: 'demo_m5_1',
        title: '年中架构重构',
        primaryTagId: 'tag_work',
        extraTagIds: ['tag_study'],
        status: 'COMPLETED',
        createdDate: monthOffset(-5, 3),
        dueDate: monthOffset(-5, 20),
        completedDate: monthOffset(-5, 18),
        logs: [
          (date: monthOffset(-5, 5), minutes: 240, memo: '模块拆分'),
          (date: monthOffset(-5, 11), minutes: 330, memo: '核心迁移'),
          (date: monthOffset(-5, 18), minutes: 180, memo: '回归验收'),
        ],
      );

      await addTask(
        id: 'demo_m4_1',
        title: 'Flutter 源码研读',
        primaryTagId: 'tag_study',
        status: 'COMPLETED',
        createdDate: monthOffset(-4, 6),
        dueDate: monthOffset(-4, 25),
        completedDate: monthOffset(-4, 24),
        logs: [
          (date: monthOffset(-4, 8), minutes: 135, memo: 'RenderObject'),
          (date: monthOffset(-4, 15), minutes: 180, memo: 'Layout 管线'),
          (date: monthOffset(-4, 24), minutes: 120, memo: '笔记整理'),
        ],
      );

      await addTask(
        id: 'demo_m3_1',
        title: 'Q3 产品迭代评审',
        primaryTagId: 'tag_work',
        status: 'COMPLETED',
        createdDate: monthOffset(-3, 2),
        dueDate: monthOffset(-3, 14),
        completedDate: monthOffset(-3, 16), // 2 days overdue
        logs: [
          (date: monthOffset(-3, 4), minutes: 195, memo: '需求拆解'),
          (date: monthOffset(-3, 10), minutes: 300, memo: '原型走查'),
          (date: monthOffset(-3, 16), minutes: 210, memo: '定稿归档'),
        ],
      );

      await addTask(
        id: 'demo_m2_1',
        title: '论文实验复现',
        primaryTagId: 'tag_research',
        extraTagIds: ['tag_study'],
        status: 'COMPLETED',
        createdDate: monthOffset(-2, 5),
        dueDate: monthOffset(-2, 22),
        completedDate: monthOffset(-2, 20),
        logs: [
          (date: monthOffset(-2, 7), minutes: 270, memo: '基线模型训练'),
          (date: monthOffset(-2, 14), minutes: 360, memo: '消融实验'),
          (date: monthOffset(-2, 20), minutes: 150, memo: '图表绘制'),
        ],
      );

      await addTask(
        id: 'demo_m1_1',
        title: '十月客户方案交付',
        primaryTagId: 'tag_work',
        status: 'COMPLETED',
        createdDate: monthOffset(-1, 8),
        dueDate: monthOffset(-1, 20),
        completedDate: monthOffset(-1, 19),
        logs: [
          (date: monthOffset(-1, 10), minutes: 240, memo: '初稿编写'),
          (date: monthOffset(-1, 15), minutes: 315, memo: '性能压测'),
          (date: monthOffset(-1, 19), minutes: 225, memo: '客户演示'),
        ],
      );

      await addTask(
        id: 'demo_m1_2',
        title: '家庭体检与整理',
        primaryTagId: 'tag_life',
        extraTagIds: ['tag_personal'],
        status: 'COMPLETED',
        createdDate: monthOffset(-1, 12),
        dueDate: monthOffset(-1, 25),
        completedDate: monthOffset(-1, 21),
        logs: [
          (date: monthOffset(-1, 14), minutes: 90, memo: '预约登记'),
          (date: monthOffset(-1, 21), minutes: 180, memo: '体检与报告归档'),
        ],
      );

      // ─── Current Month: Classic customer scenario + concurrent spans ──────
      await addTask(
        id: 'demo_cur_1',
        title: '东华卓越项目',
        note: '客户经典示例：1号立项，5/7/12号分段Mark',
        primaryTagId: 'tag_work',
        extraTagIds: ['tag_study'],
        status: 'COMPLETED',
        createdDate: monthOffset(0, 1),
        dueDate: monthOffset(0, 15),
        completedDate: monthOffset(0, 12),
        logs: [
          (date: monthOffset(0, 5), minutes: 300, memo: '需求对齐与架构设计'),
          (date: monthOffset(0, 7), minutes: 180, memo: '核心逻辑开发'),
          (date: monthOffset(0, 12), minutes: 480, memo: '联调上线完成'),
        ],
      );

      await addTask(
        id: 'demo_cur_2',
        title: '微信好友整理昌都',
        primaryTagId: 'tag_personal',
        extraTagIds: ['tag_life'],
        status: 'COMPLETED',
        createdDate: monthOffset(0, 10),
        dueDate: monthOffset(0, 19),
        completedDate: monthOffset(0, 19),
        logs: [
          (date: monthOffset(0, 13), minutes: 75, memo: '分组整理'),
          (date: monthOffset(0, 19), minutes: 105, memo: '备注补充'),
        ],
      );

      await addTask(
        id: 'demo_cur_3',
        title: 'PocketSpan 效率打磨',
        primaryTagId: 'tag_study',
        extraTagIds: ['tag_work'],
        status: 'ACTIVE',
        createdDate: monthOffset(0, 14),
        dueDate: today.add(const Duration(days: 5)),
        logs: [
          (date: monthOffset(0, 16), minutes: 150, memo: '日历双色渲染'),
          (date: monthOffset(0, 18), minutes: 210, memo: '统计页图表'),
          (date: today, minutes: 95, memo: '真机测试与优化'),
        ],
      );

      await addTask(
        id: 'demo_cur_4',
        title: '周末居家大扫除',
        primaryTagId: 'tag_life',
        status: 'ACTIVE',
        createdDate: monthOffset(0, 17),
        dueDate: today.add(const Duration(days: 1)),
        logs: [
          (date: monthOffset(0, 19), minutes: 45, memo: '厨房清理'),
        ],
      );

      await addTask(
        id: 'demo_cur_5',
        title: '季度文献综述撰写',
        primaryTagId: 'tag_research',
        extraTagIds: ['tag_study'],
        status: 'ACTIVE',
        createdDate: monthOffset(0, 15),
        dueDate: today.add(const Duration(days: 8)),
        logs: [
          (date: monthOffset(0, 17), minutes: 120, memo: '精读3篇论文'),
          (date: monthOffset(0, 20), minutes: 165, memo: '撰写实验对比'),
        ],
      );

      // Future scheduled tasks
      await addTask(
        id: 'demo_future_1',
        title: '客户终版演示',
        primaryTagId: 'tag_work',
        status: 'ACTIVE',
        createdDate: today.add(const Duration(days: 4)),
        dueDate: today.add(const Duration(days: 4)),
        logs: const [],
      );

      await addTask(
        id: 'demo_future_2',
        title: '月底财务复盘',
        primaryTagId: 'tag_personal',
        status: 'ACTIVE',
        createdDate: today.add(const Duration(days: 7)),
        logs: const [],
      );
    });
  }

  static Future<void> clearAllTasks(AppDatabase appDb) async {
    final db = await appDb.database;
    await db.transaction((txn) async {
      await txn.delete('reminders');
      await txn.delete('work_logs');
      await txn.delete('task_tags');
      await txn.delete('tasks');
    });
  }
}
