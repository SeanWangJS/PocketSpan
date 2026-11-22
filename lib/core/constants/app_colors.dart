import 'package:flutter/material.dart';

/// Paired light and dark colors for a tag's dual-track calendar visualization.
class TagColorPair {
  final String id;
  final String label;
  final String lightHex;
  final String darkHex;

  const TagColorPair({
    required this.id,
    required this.label,
    required this.lightHex,
    required this.darkHex,
  });

  Color get lightColor => AppColors.parseHex(lightHex);
  Color get darkColor => AppColors.parseHex(darkHex);
}

/// Application-wide color palette and preset tag dual-color schemes.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF5C82FF);
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color successGreen = Color(0xFF00B42A);
  static const Color dangerRed = Color(0xFFF53F3F);
  static const Color warningAmber = Color(0xFFFF7D00);

  static const Color lightBackground = Color(0xFFF7F8FC);
  static const Color darkBackground = Color(0xFF11141A);

  static const Color lightCard = Colors.white;
  static const Color darkCard = Color(0xFF1E2430);

  static const Color lightBorder = Color(0xFFEFF2F7);
  static const Color darkBorder = Color(0xFF2E3646);

  static const Color textPrimaryLight = Color(0xFF1D2129);
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondary = Color(0xFF86909C);

  /// Curated Morandi pastel-translucent + muted-deep pairs so calendar spans
  /// stay calm on both light and dark themes while effort days stand out.
  static const List<TagColorPair> tagPresets = [
    TagColorPair(
      id: 'morandi_rose',
      label: '干枯玫瑰',
      lightHex: '#40C48B8B',
      darkHex: '#DEB06B6B',
    ),
    TagColorPair(
      id: 'morandi_sage',
      label: '鼠尾草绿',
      lightHex: '#407FA68E',
      darkHex: '#DE638C73',
    ),
    TagColorPair(
      id: 'morandi_blue',
      label: '雾霾灰蓝',
      lightHex: '#407C96B3',
      darkHex: '#DE5E7C9E',
    ),
    TagColorPair(
      id: 'morandi_oat',
      label: '暖陶燕麦',
      lightHex: '#40C29B76',
      darkHex: '#DEB38357',
    ),
    TagColorPair(
      id: 'morandi_lavender',
      label: '烟灰丁香',
      lightHex: '#409B8EB3',
      darkHex: '#DE80719E',
    ),
    TagColorPair(
      id: 'morandi_teal',
      label: '海盐浅青',
      lightHex: '#4073A3A3',
      darkHex: '#DE558B8B',
    ),
    TagColorPair(
      id: 'morandi_clay',
      label: '焦糖豆沙',
      lightHex: '#40B8897E',
      darkHex: '#DEA66D60',
    ),
    TagColorPair(
      id: 'morandi_slate',
      label: '暮云冷灰',
      lightHex: '#408E96A3',
      darkHex: '#DE6F7887',
    ),
  ];

  static Color parseHex(String hex, {Color fallback = primary}) {
    final cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final value = int.tryParse('FF$cleaned', radix: 16);
      if (value != null) return Color(value);
    } else if (cleaned.length == 8) {
      final value = int.tryParse(cleaned, radix: 16);
      if (value != null) return Color(value);
    }
    return fallback;
  }

  /// Formats a [Color] as an 8-digit `#AARRGGBB` hex string.
  static String formatHex(Color color) {
    final a = (color.a * 255).round().clamp(0, 255);
    final r = (color.r * 255).round().clamp(0, 255);
    final g = (color.g * 255).round().clamp(0, 255);
    final b = (color.b * 255).round().clamp(0, 255);
    final argb = (a << 24) | (r << 16) | (g << 8) | b;
    return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  /// Derives a calm translucent span color from a chosen dark effort color.
  static Color deriveLightColor(Color darkColor) {
    final spanAlpha = (darkColor.a * 0.29).clamp(0.12, 0.38);
    return darkColor.withValues(alpha: spanAlpha);
  }
}
