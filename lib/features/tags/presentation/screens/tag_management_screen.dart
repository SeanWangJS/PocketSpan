import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/pocket_sheet_components.dart';
import '../../data/models/tag_model.dart';
import '../../data/repositories/tag_repository.dart';
import '../widgets/pocket_color_palette_picker.dart';

/// Screen for creating, editing, and deleting custom dual-color tags.
class TagManagementScreen extends StatefulWidget {
  final TagRepository tagRepository;
  final Future<void> Function() onTagsChanged;

  const TagManagementScreen({
    super.key,
    required this.tagRepository,
    required this.onTagsChanged,
  });

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  List<TagModel> _tags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.tagRepository.getAllTags();
    if (!mounted) return;
    setState(() {
      _tags = list;
      _loading = false;
    });
  }

  Future<void> _openTagDialog({TagModel? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final matchedPresetIndex = existing == null
        ? 0
        : AppColors.tagPresets.indexWhere(
            (p) => p.darkHex.toUpperCase() == existing.darkColorHex.toUpperCase(),
          );
    var useCustomPalette = existing != null && matchedPresetIndex < 0;
    var selectedPreset = matchedPresetIndex >= 0
        ? AppColors.tagPresets[matchedPresetIndex]
        : AppColors.tagPresets.first;

    final initialDarkColor = existing != null
        ? AppColors.parseHex(existing.darkColorHex)
        : selectedPreset.darkColor;
    var customHsv = HSVColor.fromColor(initialDarkColor.withValues(alpha: 1.0));
    var customOpacity = initialDarkColor.a.clamp(0.30, 1.0);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final activeDarkColor = useCustomPalette
              ? customHsv.toColor().withValues(alpha: customOpacity)
              : selectedPreset.darkColor;

          return PocketSheetContainer(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PocketSheetHeader(
                    title: existing == null ? '新建标签' : '编辑标签',
                    actionLabel: '保存',
                    onAction: () {
                      if (nameController.text.trim().isEmpty) return;
                      Navigator.pop(ctx, true);
                    },
                  ),
                  const SizedBox(height: 16),
                  PocketSoftCard(
                    label: '标签名称',
                    tintColor: activeDarkColor,
                    child: TextField(
                      controller: nameController,
                      autofocus: existing == null,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        hintText: '例如：工作、科研、健身',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '配色与透明度',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFF1F3F8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PaletteModeTab(
                              label: '推荐',
                              selected: !useCustomPalette,
                              onTap: () => setSheetState(
                                () => useCustomPalette = false,
                              ),
                            ),
                            _PaletteModeTab(
                              label: '自定义',
                              selected: useCustomPalette,
                              onTap: () => setSheetState(
                                () => useCustomPalette = true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!useCustomPalette)
                    Wrap(
                      spacing: 10,
                      runSpacing: 12,
                      children: AppColors.tagPresets.map((preset) {
                        final active = preset.id == selectedPreset.id;
                        return GestureDetector(
                          onTap: () => setSheetState(() {
                            selectedPreset = preset;
                            customHsv = HSVColor.fromColor(
                              preset.darkColor.withValues(alpha: 1.0),
                            );
                            customOpacity = preset.darkColor.a.clamp(0.30, 1.0);
                          }),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 64,
                                height: 38,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: active
                                        ? preset.darkColor
                                        : Colors.transparent,
                                    width: 2.2,
                                  ),
                                  boxShadow: active
                                      ? [
                                          BoxShadow(
                                            color: preset.darkColor
                                                .withValues(alpha: 0.25),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: preset.lightColor,
                                          borderRadius:
                                              const BorderRadius.horizontal(
                                            left: Radius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: preset.darkColor,
                                          borderRadius:
                                              const BorderRadius.horizontal(
                                            right: Radius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                preset.label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active
                                      ? preset.darkColor
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  else
                    PocketColorPalettePicker(
                      hsv: customHsv,
                      opacity: customOpacity,
                      onHsvChanged: (next) =>
                          setSheetState(() => customHsv = next),
                      onOpacityChanged: (next) =>
                          setSheetState(() => customOpacity = next),
                    ),
                  const SizedBox(height: 20),
                  PocketPrimaryButton(
                    label: existing == null ? '保存标签' : '保存修改',
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) return;
                      Navigator.pop(ctx, true);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (saved != true) return;
    final name = nameController.text.trim();
    final String finalLightHex;
    final String finalDarkHex;
    if (useCustomPalette) {
      final darkColor = customHsv.toColor().withValues(alpha: customOpacity);
      final lightColor = AppColors.deriveLightColor(darkColor);
      finalLightHex = AppColors.formatHex(lightColor);
      finalDarkHex = AppColors.formatHex(darkColor);
    } else {
      finalLightHex = selectedPreset.lightHex;
      finalDarkHex = selectedPreset.darkHex;
    }

    if (existing == null) {
      await widget.tagRepository.createTag(
        name: name,
        lightColorHex: finalLightHex,
        darkColorHex: finalDarkHex,
      );
    } else {
      await widget.tagRepository.updateTag(
        existing.copyWith(
          name: name,
          lightColorHex: finalLightHex,
          darkColorHex: finalDarkHex,
        ),
      );
    }
    await _load();
    await widget.onTagsChanged();
  }

  Future<void> _deleteTag(TagModel tag) async {
    try {
      await widget.tagRepository.deleteTag(tag.id);
      await _load();
      await widget.onTagsChanged();
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final card = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('标签管理', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: _tags.length,
              itemBuilder: (_, idx) {
                final tag = _tags[idx];
                final light = AppColors.parseHex(tag.lightColorHex);
                final dark = AppColors.parseHex(tag.darkColorHex);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 24,
                          decoration: BoxDecoration(
                            color: light,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(6),
                            ),
                          ),
                        ),
                        Container(
                          width: 16,
                          height: 24,
                          decoration: BoxDecoration(
                            color: dark,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      tag.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _openTagDialog(existing: tag),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _deleteTag(tag),
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTagDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新建标签'),
      ),
    );
  }
}

class _PaletteModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.darkCard : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
