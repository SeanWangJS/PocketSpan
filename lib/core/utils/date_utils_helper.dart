import 'package:lunar/lunar.dart';

/// Date normalization, inclusive span math, and Chinese lunar/festival helpers.
class DateUtilsHelper {
  DateUtilsHelper._();

  /// Strips time components to midnight local date.
  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Formats [dt] as `yyyy-MM-dd`.
  static String toDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses a `yyyy-MM-dd` string back into a local midnight [DateTime].
  static DateTime parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Inclusive day count between [start] and [end] (minimum 1 if `end >= start`).
  static int daysBetweenInclusive(DateTime start, DateTime end) {
    final s = dateOnly(start);
    final e = dateOnly(end);
    if (e.isBefore(s)) return 0;
    return e.difference(s).inDays + 1;
  }

  /// Non-negative day difference `end - start`.
  static int daysBetween(DateTime start, DateTime end) {
    final s = dateOnly(start);
    final e = dateOnly(end);
    return e.difference(s).inDays;
  }

  /// Computes ISO-8601 week number (1..53) for [date].
  static int isoWeekNumber(DateTime date) {
    final d = dateOnly(date);
    final thursday = d.add(Duration(days: DateTime.thursday - d.weekday));
    final firstJan = DateTime(thursday.year, 1, 1);
    return ((thursday.difference(firstJan).inDays) ~/ 7) + 1;
  }

  /// Returns a concise lunar/solar-term/festival label for a calendar cell,
  /// matching the clean auxiliary cue style of Chinese calendar apps.
  static ({String text, bool isHighlight}) lunarLabel(DateTime date) {
    final solar = Solar.fromYmd(date.year, date.month, date.day);
    final lunar = solar.getLunar();

    final solarFestivals = solar.getFestivals();
    if (solarFestivals.isNotEmpty) {
      return (text: solarFestivals.first, isHighlight: true);
    }
    final lunarFestivals = lunar.getFestivals();
    if (lunarFestivals.isNotEmpty) {
      return (text: lunarFestivals.first, isHighlight: true);
    }
    final jieQi = lunar.getJieQi();
    if (jieQi.isNotEmpty) {
      return (text: jieQi, isHighlight: true);
    }
    if (lunar.getDay() == 1) {
      return (text: '${lunar.getMonthInChinese()}月', isHighlight: true);
    }
    return (text: lunar.getDayInChinese(), isHighlight: false);
  }
}
