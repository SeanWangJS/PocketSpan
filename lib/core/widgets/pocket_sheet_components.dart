import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../../features/tags/data/models/tag_model.dart';

/// Resolves a crisp Material vector icon for a tag by its ID or name.
IconData iconForTag(TagModel tag) {
  switch (tag.id) {
    case 'tag_work':
      return Icons.work_outline_rounded;
    case 'tag_life':
      return Icons.home_outlined;
    case 'tag_study':
      return Icons.menu_book_outlined;
    case 'tag_personal':
      return Icons.person_outline_rounded;
    case 'tag_research':
      return Icons.science_outlined;
  }
  final n = tag.name;
  if (n.contains('工作') || n.contains('项目')) return Icons.work_outline_rounded;
  if (n.contains('生活') || n.contains('家')) return Icons.home_outlined;
  if (n.contains('学') || n.contains('书')) return Icons.menu_book_outlined;
  if (n.contains('研') || n.contains('实验')) return Icons.science_outlined;
  if (n.contains('健') || n.contains('运动')) return Icons.fitness_center_rounded;
  return Icons.label_outline_rounded;
}

/// Unified bottom sheet wrapper with PocketBudget-inspired rounded corners,
/// drag handle, keyboard inset handling, and bottom safe-area clearance.
class PocketSheetContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const PocketSheetContainer({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final bottomPadding = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom + 16
        : media.padding.bottom + 18;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: padding ?? EdgeInsets.fromLTRB(20, 10, 20, bottomPadding),
      child: child,
    );
  }
}

/// Drag handle + bold title + optional right text action (e.g. "保存").
class PocketSheetHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PocketSheetHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: onAction != null
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Borderless soft-tinted input/display card matching PocketBudget's sheet cards.
class PocketSoftCard extends StatelessWidget {
  final String? label;
  final Color? tintColor;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PocketSoftCard({
    super.key,
    this.label,
    this.tintColor,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark
        ? const Color(0xFF252D3D)
        : const Color(0xFFF6F7FB);
    final bg = (!isDark && tintColor != null)
        ? Color.alphaBlend(
            tintColor!.withValues(alpha: 0.055),
            const Color(0xFFFAFBFD),
          )
        : defaultBg;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
          ],
          child,
        ],
      ),
    );
  }
}

/// Pill-shaped tappable row for dates, deadlines, or secondary pickers.
class PocketActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  const PocketActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF252D3D) : const Color(0xFFF6F7FB),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width primary rounded action button with checkmark icon.
class PocketPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  const PocketPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.check_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon, size: 20, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Circular pastel icon badge grid for selecting single or multiple tags,
/// directly matching PocketBudget's category picker aesthetic.
class PocketTagBadgeGrid extends StatelessWidget {
  final List<TagModel> tags;
  final Set<String> selectedTagIds;
  final String primaryTagId;
  final ValueChanged<String> onToggleTag;
  final ValueChanged<String> onSetPrimaryTag;

  const PocketTagBadgeGrid({
    super.key,
    required this.tags,
    required this.selectedTagIds,
    required this.primaryTagId,
    required this.onToggleTag,
    required this.onSetPrimaryTag,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: tags.map((tag) {
        final selected = selectedTagIds.contains(tag.id);
        final isPrimary = primaryTagId == tag.id;
        final darkColor = AppColors.parseHex(tag.darkColorHex);
        final lightColor = AppColors.parseHex(tag.lightColorHex);

        return GestureDetector(
          onTap: () => onToggleTag(tag.id),
          onLongPress: () => onSetPrimaryTag(tag.id),
          child: SizedBox(
            width: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? (isPrimary
                            ? darkColor.withValues(alpha: isDark ? 0.38 : 0.22)
                            : lightColor)
                        : (isDark
                            ? const Color(0xFF252D3D)
                            : lightColor.withValues(alpha: 0.55)),
                    border: selected
                        ? Border.all(
                            color: darkColor.withValues(
                              alpha: isPrimary ? 0.9 : 0.45,
                            ),
                            width: isPrimary ? 1.8 : 1.1,
                          )
                        : null,
                    boxShadow: isPrimary
                        ? [
                            BoxShadow(
                              color: darkColor.withValues(alpha: 0.26),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    iconForTag(tag),
                    size: 21,
                    color: darkColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tag.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? darkColor : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: isPrimary ? 5 : 0,
                  height: isPrimary ? 5 : 0,
                  decoration: BoxDecoration(
                    color: darkColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Soft rounded confirmation dialog replacing default material alert styling.
Future<bool> showPocketConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '确定',
  Color confirmColor = AppColors.dangerRed,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}
