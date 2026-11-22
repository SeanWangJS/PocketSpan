import 'dart:math' as math;

import 'package:flutter/material.dart';

class EffortDonutSegment {
  final double value;
  final Color color;
  final String label;

  const EffortDonutSegment({
    required this.value,
    required this.color,
    required this.label,
  });
}

/// Clean ring chart showing tag effort breakdown with center total label.
class EffortDonutChart extends StatelessWidget {
  final List<EffortDonutSegment> segments;
  final String centerLabel;
  final String centerValue;
  final double size;
  final double strokeWidth;

  const EffortDonutChart({
    super.key,
    required this.segments,
    required this.centerLabel,
    required this.centerValue,
    this.size = 122,
    this.strokeWidth = 15,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          segments: segments,
          strokeWidth: strokeWidth,
          trackColor:
              isDark ? const Color(0xFF283040) : const Color(0xFFF0F2F7),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerLabel,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF86909C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                centerValue,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1D2129),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<EffortDonutSegment> segments;
  final double strokeWidth;
  final Color trackColor;

  _DonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final total = segments.fold<double>(0.0, (s, item) => s + item.value);
    if (total <= 0) return;

    double startAngle = -math.pi / 2;
    final gapAngle = segments.length > 1 ? 0.04 : 0.0;

    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweep = (seg.value / total) * (2 * math.pi) - gapAngle;
      if (sweep <= 0) continue;

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle + gapAngle / 2, sweep, false, paint);
      startAngle += sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments ||
      oldDelegate.trackColor != trackColor;
}
