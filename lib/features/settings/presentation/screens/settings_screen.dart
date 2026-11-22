import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/data_backup_service.dart';
import '../../../../core/database/demo_data_seeder.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/widgets/pocket_sheet_components.dart';
import '../../../tags/data/models/tag_model.dart';
import '../../../tags/data/repositories/tag_repository.dart';
import '../../../tags/presentation/screens/tag_management_screen.dart';
import '../../../tasks/data/models/task_model.dart';

/// "My" / Settings tab providing Tag Management, preferences, and data tools.
class SettingsScreen extends StatelessWidget {
  final AppDatabase database;
  final List<TaskWithDetails> tasks;
  final List<TagModel> tags;
  final TagRepository tagRepository;
  final bool weekStartsOnMonday;
  final ValueChanged<bool> onWeekStartChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Future<void> Function() onDataChanged;

  const SettingsScreen({
    super.key,
    required this.database,
    required this.tasks,
    required this.tags,
    required this.tagRepository,
    required this.weekStartsOnMonday,
    required this.onWeekStartChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;
    final subtleDivider = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.045);

    final totalMinutes =
        tasks.fold<int>(0, (sum, t) => sum + t.totalEffortMinutes);
    final completedCount =
        tasks.where((t) => t.task.status == TaskStatus.completed).length;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            const Text(
              '我的',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 14),

            // Soft borderless summary card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  _ProfileStat(label: '累计事项', value: '${tasks.length}'),
                  _ProfileStat(label: '已完成', value: '$completedCount'),
                  _ProfileStat(
                    label: '总投入工时',
                    value: DurationFormatter.format(totalMinutes),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Preferences group
            Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.label_outline_rounded,
                    iconColor: const Color(0xFF5E7C9E),
                    iconBg: const Color(0x287C96B3),
                    title: '标签管理',
                    subtitle: '${tags.length} 个标签',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TagManagementScreen(
                            tagRepository: tagRepository,
                            onTagsChanged: onDataChanged,
                          ),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, indent: 62, endIndent: 16, color: subtleDivider),
                  _SettingsRow(
                    icon: Icons.calendar_view_week_outlined,
                    iconColor: const Color(0xFFB38357),
                    iconBg: const Color(0x28C29B76),
                    title: '每周从周一开始',
                    trailing: Switch.adaptive(
                      value: weekStartsOnMonday,
                      activeTrackColor: AppColors.primary,
                      onChanged: onWeekStartChanged,
                    ),
                    onTap: () => onWeekStartChanged(!weekStartsOnMonday),
                  ),
                  Divider(height: 1, indent: 62, endIndent: 16, color: subtleDivider),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Color(0x289B8EB3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.palette_outlined,
                                size: 18,
                                color: Color(0xFF80719E),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '外观主题',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    switch (themeMode) {
                                      ThemeMode.light => '当前：浅色',
                                      ThemeMode.dark => '当前：深色',
                                      ThemeMode.system => '当前：跟随系统',
                                    },
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF1F3F8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              _ThemeOption(
                                label: '浅色',
                                selected: themeMode == ThemeMode.light,
                                onTap: () => onThemeModeChanged(ThemeMode.light),
                              ),
                              _ThemeOption(
                                label: '深色',
                                selected: themeMode == ThemeMode.dark,
                                onTap: () => onThemeModeChanged(ThemeMode.dark),
                              ),
                              _ThemeOption(
                                label: '系统',
                                selected: themeMode == ThemeMode.system,
                                onTap: () =>
                                    onThemeModeChanged(ThemeMode.system),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Data tools group
            Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(22),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.download_outlined,
                    iconColor: const Color(0xFF558B8B),
                    iconBg: const Color(0x2873A3A3),
                    title: '导出备份数据',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    onTap: () => _openExportSheet(context),
                  ),
                  if (!kReleaseMode) ...[
                    Divider(height: 1, indent: 62, endIndent: 16, color: subtleDivider),
                    _SettingsRow(
                      icon: Icons.auto_awesome_outlined,
                      iconColor: const Color(0xFF638C73),
                      iconBg: const Color(0x287FA68E),
                      title: '导入演示数据',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                      onTap: () async {
                        await DemoDataSeeder.seedDemoData(database);
                        await onDataChanged();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已导入半年模拟数据')),
                        );
                      },
                    ),
                  ],
                  Divider(height: 1, indent: 62, endIndent: 16, color: subtleDivider),
                  _SettingsRow(
                    icon: Icons.delete_sweep_outlined,
                    iconColor: const Color(0xFFB06B6B),
                    iconBg: const Color(0x28C48B8B),
                    title: '清空事项数据',
                    onTap: () async {
                      final ok = await showPocketConfirmDialog(
                        context: context,
                        title: '确认清空',
                        message: '确定清空所有事项与工时记录吗？',
                        confirmLabel: '清空',
                      );
                      if (ok) {
                        await DemoDataSeeder.clearAllTasks(database);
                        await onDataChanged();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PocketSpan · 所有数据均存储于本地设备',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExportSheet(BuildContext context) async {
    final backup = await DataBackupService.buildBackup(database);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return PocketSheetContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PocketSheetHeader(title: '导出备份'),
              const SizedBox(height: 14),
              PocketSoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '格式版本 v${backup.schemaVersion}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· 数据库 v${backup.dbVersion}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${backup.tagCount} 个标签 · ${backup.taskCount} 个事项 · ${backup.workLogCount} 条工时',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      backup.fileName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: backup.jsonString),
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制备份 JSON 到剪贴板')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('复制 JSON'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PocketPrimaryButton(
                      label: '保存文件',
                      icon: Icons.save_alt_rounded,
                      onPressed: () async {
                        try {
                          final uri =
                              await DataBackupService.saveWithSystemPicker(
                            backup,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (uri != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已保存备份：${backup.fileName}'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('导出失败：$e')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? AppColors.darkCard : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
