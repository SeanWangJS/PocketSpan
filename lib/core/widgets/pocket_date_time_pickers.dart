import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'pocket_sheet_components.dart';

/// Shows a PocketBudget-style bottom-sheet date picker with month swipe & quick chips.
Future<DateTime?> showPocketDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String title = '选择日期',
}) {
  final minDate = firstDate ?? DateTime(2020, 1, 1);
  final maxDate = lastDate ?? DateTime(2035, 12, 31);
  var selected = DateTime(initialDate.year, initialDate.month, initialDate.day);
  if (selected.isBefore(minDate)) selected = minDate;
  if (selected.isAfter(maxDate)) selected = maxDate;

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PocketDatePickerSheet(
      title: title,
      initialSelected: selected,
      minDate: minDate,
      maxDate: maxDate,
    ),
  );
}

/// Shows a PocketBudget-style bottom-sheet year & month picker.
Future<DateTime?> showPocketMonthPicker({
  required BuildContext context,
  required DateTime initialDate,
  int minYear = 2020,
  int maxYear = 2035,
  String title = '选择月份',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PocketMonthPickerSheet(
      title: title,
      initialYear: initialDate.year.clamp(minYear, maxYear),
      initialMonth: initialDate.month,
      minYear: minYear,
      maxYear: maxYear,
    ),
  );
}

/// Shows a PocketBudget-style bottom-sheet minute-exact time picker.
Future<TimeOfDay?> showPocketTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = '选择时间',
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PocketTimePickerSheet(
      title: title,
      initialTime: initialTime,
    ),
  );
}

class _PocketDatePickerSheet extends StatefulWidget {
  final String title;
  final DateTime initialSelected;
  final DateTime minDate;
  final DateTime maxDate;

  const _PocketDatePickerSheet({
    required this.title,
    required this.initialSelected,
    required this.minDate,
    required this.maxDate,
  });

  @override
  State<_PocketDatePickerSheet> createState() => _PocketDatePickerSheetState();
}

class _PocketDatePickerSheetState extends State<_PocketDatePickerSheet> {
  static const int _initialPage = 1200;

  late final DateTime _baseMonth;
  late DateTime _displayMonth;
  late DateTime _selected;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
    _baseMonth = DateTime(_selected.year, _selected.month);
    _displayMonth = _baseMonth;
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _monthForPage(int page) =>
      DateTime(_baseMonth.year, _baseMonth.month + (page - _initialPage));

  int _pageForMonth(DateTime month) =>
      _initialPage +
      (month.year - _baseMonth.year) * 12 +
      (month.month - _baseMonth.month);

  void _jumpToDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final targetMonth = DateTime(normalized.year, normalized.month);
    final targetPage = _pageForMonth(targetMonth);
    setState(() {
      _selected = normalized;
      _displayMonth = targetMonth;
    });
    if (_pageController.hasClients) {
      final current = _pageController.page?.round() ?? targetPage;
      if ((targetPage - current).abs() > 4) {
        _pageController.jumpToPage(targetPage);
      } else {
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _stepMonth(int delta) {
    final next = DateTime(_displayMonth.year, _displayMonth.month + delta);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        _pageForMonth(next),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const weekdays = ['日', '一', '二', '三', '四', '五', '六'];

    return PocketSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PocketSheetHeader(
            title: widget.title,
            actionLabel: '确定',
            onAction: () => Navigator.pop(context, _selected),
          ),
          const SizedBox(height: 12),

          // Month navigation bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _stepMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_displayMonth.year}年${_displayMonth.month}月',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _stepMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded, size: 22),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Weekday header
          Row(
            children: List.generate(7, (i) {
              final weekend = i == 0 || i == 6;
              return Expanded(
                child: Center(
                  child: Text(
                    weekdays[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: weekend
                          ? AppColors.accentOrange
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),

          // Swipeable 6-row month grid
          SizedBox(
            height: 252,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() => _displayMonth = _monthForPage(page));
              },
              itemBuilder: (_, page) {
                final month = _monthForPage(page);
                final firstOfMonth = DateTime(month.year, month.month, 1);
                final leadingDays = firstOfMonth.weekday % 7;
                final start = firstOfMonth.subtract(Duration(days: leadingDays));

                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: 42,
                  ),
                  itemCount: 42,
                  itemBuilder: (_, idx) {
                    final date = DateTime(
                      start.year,
                      start.month,
                      start.day + idx,
                    );
                    final inMonth = date.month == month.month;
                    final isSelected = date == _selected;
                    final isToday = date == today;
                    final disabled = date.isBefore(widget.minDate) ||
                        date.isAfter(widget.maxDate);

                    return GestureDetector(
                      onTap: disabled
                          ? null
                          : () {
                              setState(() => _selected = date);
                            },
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (isToday
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : Colors.transparent),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : disabled
                                      ? AppColors.textSecondary
                                          .withValues(alpha: 0.25)
                                      : isToday
                                          ? AppColors.primary
                                          : inMonth
                                              ? (isDark
                                                  ? Colors.white
                                                  : AppColors.textPrimaryLight)
                                              : AppColors.textSecondary
                                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Quick jump chips
          Row(
            children: [
              _QuickDateChip(
                label: '今天',
                selected: _selected == today,
                onTap: () => _jumpToDate(today),
              ),
              const SizedBox(width: 8),
              _QuickDateChip(
                label: '明天',
                selected: _selected == today.add(const Duration(days: 1)),
                onTap: () => _jumpToDate(today.add(const Duration(days: 1))),
              ),
              const SizedBox(width: 8),
              _QuickDateChip(
                label: '3天后',
                selected: _selected == today.add(const Duration(days: 3)),
                onTap: () => _jumpToDate(today.add(const Duration(days: 3))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PocketPrimaryButton(
            label: '确定',
            onPressed: () => Navigator.pop(context, _selected),
          ),
        ],
      ),
    );
  }
}

class _PocketMonthPickerSheet extends StatefulWidget {
  final String title;
  final int initialYear;
  final int initialMonth;
  final int minYear;
  final int maxYear;

  const _PocketMonthPickerSheet({
    required this.title,
    required this.initialYear,
    required this.initialMonth,
    required this.minYear,
    required this.maxYear,
  });

  @override
  State<_PocketMonthPickerSheet> createState() =>
      _PocketMonthPickerSheetState();
}

class _PocketMonthPickerSheetState extends State<_PocketMonthPickerSheet> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return PocketSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PocketSheetHeader(
            title: widget.title,
            actionLabel: '确定',
            onAction: () => Navigator.pop(context, DateTime(_year, _month)),
          ),
          const SizedBox(height: 14),

          // Year stepper bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed:
                      _year > widget.minYear ? () => setState(() => _year--) : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_year 年',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      _year < widget.maxYear ? () => setState(() => _year++) : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 22),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3x4 month grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.8,
            ),
            itemCount: 12,
            itemBuilder: (_, idx) {
              final m = idx + 1;
              final selected = m == _month;
              final isCurrent = _year == now.year && m == now.month;
              return GestureDetector(
                onTap: () => setState(() => _month = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                        : (isCurrent
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : (isDark
                                ? AppColors.darkCard
                                : AppColors.lightBackground)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$m月',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected || isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : (isCurrent
                              ? AppColors.primary
                              : (isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight)),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          PocketPrimaryButton(
            label: '确定',
            onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
          ),
        ],
      ),
    );
  }
}

class _PocketTimePickerSheet extends StatefulWidget {
  final String title;
  final TimeOfDay initialTime;

  const _PocketTimePickerSheet({
    required this.title,
    required this.initialTime,
  });

  @override
  State<_PocketTimePickerSheet> createState() => _PocketTimePickerSheetState();
}

class _PocketTimePickerSheetState extends State<_PocketTimePickerSheet> {
  late int _hour;
  late int _minute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  static const _presets = [
    TimeOfDay(hour: 9, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 18, minute: 0),
    TimeOfDay(hour: 20, minute: 30),
  ];

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _applyPreset(TimeOfDay t) {
    setState(() {
      _hour = t.hour;
      _minute = t.minute;
    });
    _hourController.animateToItem(
      t.hour,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    _minuteController.animateToItem(
      t.minute,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatted =
        '${_hour.toString().padLeft(2, '0')} : ${_minute.toString().padLeft(2, '0')}';

    return PocketSheetContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PocketSheetHeader(
            title: widget.title,
            actionLabel: '确定',
            onAction: () => Navigator.pop(
              context,
              TimeOfDay(hour: _hour, minute: _minute),
            ),
          ),
          const SizedBox(height: 12),

          PocketSoftCard(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Center(
              child: Text(
                formatted,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            height: 168,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _hourController,
                    itemExtent: 38,
                    onSelectedItemChanged: (val) => setState(() => _hour = val),
                    children: List.generate(
                      24,
                      (h) => Center(
                        child: Text(
                          '${h.toString().padLeft(2, '0')} 时',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _minuteController,
                    itemExtent: 38,
                    onSelectedItemChanged: (val) =>
                        setState(() => _minute = val),
                    children: List.generate(
                      60,
                      (m) => Center(
                        child: Text(
                          '${m.toString().padLeft(2, '0')} 分',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: _presets.map((t) {
              final label =
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
              final active = _hour == t.hour && _minute == t.minute;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _QuickDateChip(
                  label: label,
                  selected: active,
                  onTap: () => _applyPreset(t),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          PocketPrimaryButton(
            label: '确定',
            onPressed: () => Navigator.pop(
              context,
              TimeOfDay(hour: _hour, minute: _minute),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickDateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.14)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF1F3F8)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
