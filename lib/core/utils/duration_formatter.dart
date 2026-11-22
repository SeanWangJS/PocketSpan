/// Formats minute-level effort durations into compact human-readable strings.
class DurationFormatter {
  DurationFormatter._();

  /// Formats [minutes] as `1h 25m`, `5h`, or `45m`.
  static String format(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  /// Formats [minutes] in compact form for tight calendar cells (e.g. `1.5h`, `45m`, `5h`).
  static String formatCompact(int minutes) {
    if (minutes <= 0) return '0m';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes / 60.0;
    if (minutes % 60 == 0) return '${minutes ~/ 60}h';
    final fixed = hours.toStringAsFixed(1);
    return fixed.endsWith('.0')
        ? '${fixed.substring(0, fixed.length - 2)}h'
        : '${fixed}h';
  }
}
