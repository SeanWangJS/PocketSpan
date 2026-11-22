import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Standard 2D HSV pigment canvas + hue slider + opacity slider for custom tags.
class PocketColorPalettePicker extends StatelessWidget {
  final HSVColor hsv;
  final double opacity;
  final ValueChanged<HSVColor> onHsvChanged;
  final ValueChanged<double> onOpacityChanged;

  const PocketColorPalettePicker({
    super.key,
    required this.hsv,
    required this.opacity,
    required this.onHsvChanged,
    required this.onOpacityChanged,
  });

  static const List<Color> _quickPigments = [
    Color(0xFFB06B6B), // 干枯玫瑰
    Color(0xFF638C73), // 鼠尾草绿
    Color(0xFF5E7C9E), // 雾霾灰蓝
    Color(0xFFB38357), // 暖陶燕麦
    Color(0xFF80719E), // 烟灰丁香
    Color(0xFF558B8B), // 海盐浅青
    Color(0xFFE07A5F), // 陶土橘红
    Color(0xFF4F78FF), // 晴空钴蓝
    Color(0xFF3D9970), // 橄榄青绿
    Color(0xFFD99B26), // 芥末姜黄
    Color(0xFF9E5A8A), // 梅子豆沙
    Color(0xFF6F7887), // 暮云冷灰
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final darkPreview = hsv.toColor().withValues(alpha: opacity);
    final lightPreview = AppColors.deriveLightColor(darkPreview);
    final percentText = '${(opacity * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2D Saturation x Value pigment canvas
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 148,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                void updateFromOffset(Offset pos) {
                  final s = (pos.dx / constraints.maxWidth).clamp(0.0, 1.0);
                  final v =
                      1.0 - (pos.dy / constraints.maxHeight).clamp(0.0, 1.0);
                  onHsvChanged(hsv.withSaturation(s).withValue(v));
                }

                return GestureDetector(
                  onPanDown: (d) => updateFromOffset(d.localPosition),
                  onPanUpdate: (d) => updateFromOffset(d.localPosition),
                  child: CustomPaint(
                    painter: _SatValPainter(hsv: hsv),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Hue rainbow bar
        SizedBox(
          height: 26,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              void updateHue(Offset pos) {
                final ratio = (pos.dx / constraints.maxWidth).clamp(0.0, 1.0);
                onHsvChanged(hsv.withHue(ratio * 360.0));
              }

              return GestureDetector(
                onPanDown: (d) => updateHue(d.localPosition),
                onPanUpdate: (d) => updateHue(d.localPosition),
                child: CustomPaint(
                  painter: _HueBarPainter(hue: hsv.hue),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Opacity slider row (30% - 100%)
        Row(
          children: [
            const Text(
              '透明度',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 26,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    void updateOpacity(Offset pos) {
                      final ratio =
                          (pos.dx / constraints.maxWidth).clamp(0.0, 1.0);
                      onOpacityChanged(0.30 + ratio * 0.70);
                    }

                    return GestureDetector(
                      onPanDown: (d) => updateOpacity(d.localPosition),
                      onPanUpdate: (d) => updateOpacity(d.localPosition),
                      child: CustomPaint(
                        painter: _OpacityBarPainter(
                          baseColor: hsv.toColor(),
                          opacity: opacity,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 48,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFF1F3F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                percentText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Quick pigment dots
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickPigments.map((pigment) {
            final pHsv = HSVColor.fromColor(pigment);
            final selected = (pHsv.hue - hsv.hue).abs() < 4 &&
                (pHsv.saturation - hsv.saturation).abs() < 0.06 &&
                (pHsv.value - hsv.value).abs() < 0.06;
            return GestureDetector(
              onTap: () => onHsvChanged(pHsv),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: pigment.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? (isDark ? Colors.white : AppColors.textPrimaryLight)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Live calendar dual-track preview
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBackground
                : AppColors.lightBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text(
                '日历预览',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: lightPreview,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    '事项跨度',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: darkPreview,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    color: darkPreview,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(6),
                    ),
                  ),
                  child: const Text(
                    '投入 1.5h',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SatValPainter extends CustomPainter {
  final HSVColor hsv;

  _SatValPainter({required this.hsv});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor();

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );

    final thumb = Offset(
      hsv.saturation * size.width,
      (1.0 - hsv.value) * size.height,
    );
    canvas.drawCircle(
      thumb,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      thumb,
      6.5,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _SatValPainter old) => old.hsv != hsv;
}

class _HueBarPainter extends CustomPainter {
  final double hue;

  _HueBarPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final trackRect = Rect.fromLTWH(0, 6, size.width, size.height - 12);
    final rrect = RRect.fromRectAndRadius(trackRect, const Radius.circular(8));
    final colors = List.generate(
      7,
      (i) => HSVColor.fromAHSV(1.0, (i * 60).toDouble(), 1.0, 1.0).toColor(),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(colors: colors).createShader(trackRect),
    );

    final dx = (hue / 360.0).clamp(0.0, 1.0) * size.width;
    final center = Offset(dx.clamp(10.0, size.width - 10.0), size.height / 2);
    canvas.drawCircle(center, 10, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      7.5,
      Paint()..color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor(),
    );
  }

  @override
  bool shouldRepaint(covariant _HueBarPainter old) => old.hue != hue;
}

class _OpacityBarPainter extends CustomPainter {
  final Color baseColor;
  final double opacity;

  _OpacityBarPainter({required this.baseColor, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final trackRect = Rect.fromLTWH(0, 6, size.width, size.height - 12);
    final rrect = RRect.fromRectAndRadius(trackRect, const Radius.circular(8));

    canvas.save();
    canvas.clipRRect(rrect);
    const cellSize = 6.0;
    final lightGrey = Paint()..color = const Color(0xFFE5E7EB);
    final darkGrey = Paint()..color = const Color(0xFFD1D5DB);
    for (double y = trackRect.top; y < trackRect.bottom; y += cellSize) {
      for (double x = trackRect.left; x < trackRect.right; x += cellSize) {
        final odd =
            (((x - trackRect.left) ~/ cellSize) +
                    ((y - trackRect.top) ~/ cellSize)) %
                2 ==
            0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          odd ? lightGrey : darkGrey,
        );
      }
    }
    canvas.drawRect(
      trackRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            baseColor.withValues(alpha: 0.30),
            baseColor.withValues(alpha: 1.0),
          ],
        ).createShader(trackRect),
    );
    canvas.restore();

    final ratio = ((opacity - 0.30) / 0.70).clamp(0.0, 1.0);
    final dx = (ratio * size.width).clamp(10.0, size.width - 10.0);
    final center = Offset(dx, size.height / 2);
    canvas.drawCircle(center, 10, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      7.5,
      Paint()..color = baseColor.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(covariant _OpacityBarPainter old) =>
      old.baseColor != baseColor || old.opacity != opacity;
}
