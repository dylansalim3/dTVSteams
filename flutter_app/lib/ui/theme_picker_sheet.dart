import 'package:flutter/material.dart';
import '../services/settings_manager.dart';
import 'app_themes.dart';
import 'app_tokens.dart';

/// Segmented pill button to switch between Light and Dark theme counterparts.
class ThemeBrightnessToggle extends StatelessWidget {
  final Brightness brightness;
  final ValueChanged<Brightness> onChanged;
  final Key? lightKey;
  final Key? darkKey;

  const ThemeBrightnessToggle({
    super.key,
    required this.brightness,
    required this.onChanged,
    this.lightKey,
    this.darkKey,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    final isLight = brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentButton(
            key: lightKey,
            icon: Icons.light_mode_outlined,
            label: '淺色',
            selected: isLight,
            onTap: () => onChanged(Brightness.light),
          ),
          const SizedBox(width: 2),
          _SegmentButton(
            key: darkKey,
            icon: Icons.dark_mode_outlined,
            label: '深色',
            selected: !isLight,
            onTap: () => onChanged(Brightness.dark),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm - 1),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? AppColors.onAccent : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.onAccent : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the live 21st.dev theme picker modal bottom sheet.
Future<void> showThemePickerSheet(
  BuildContext context, [
  SettingsManager? settingsManager,
]) {
  final manager = settingsManager ?? SettingsManager();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => ThemePickerSheet(settingsManager: manager),
  );
}

class ThemePickerSheet extends StatelessWidget {
  final SettingsManager settingsManager;
  const ThemePickerSheet({super.key, required this.settingsManager});

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    return ListenableBuilder(
      listenable: settingsManager,
      builder: (context, _) {
        final activeId = settingsManager.themeId;
        final activeTheme = settingsManager.activeTheme;
        final themes = AppThemes.allForBrightness(settingsManager.themeBrightness);
        final mediaQuery = MediaQuery.of(context);
        final maxHeight = mediaQuery.size.height * 0.84;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceOverlay,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
              border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1)),
            ),
            child: SafeArea(
              top: true,
              bottom: true,
              minimum: const EdgeInsets.only(top: AppSpacing.sm),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  mediaQuery.viewInsets.bottom + AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.borderDefault,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('外觀主題選擇', style: AppType.title3Semibold),
                              const SizedBox(height: 2),
                              Text(
                                '1 款預設 + ${AppThemes.twentyFirstDevThemes.length} 款 21st.dev 精選主題',
                                style: AppType.caption1Medium.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                          style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          tooltip: '關閉主題選擇',
                          icon: Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '色彩模式',
                          style: AppType.caption1Semibold.copyWith(color: AppColors.textSecondary),
                        ),
                        ThemeBrightnessToggle(
                          key: const ValueKey('theme_picker_brightness_toggle'),
                          lightKey: const ValueKey('theme_picker_light_mode_button'),
                          darkKey: const ValueKey('theme_picker_dark_mode_button'),
                          brightness: settingsManager.themeBrightness,
                          onChanged: settingsManager.setThemeBrightness,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Live selected vs unselected contrast preview bar
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(AppRadius.badge),
                            ),
                            child: Text(
                              '已選文字',
                              style: TextStyle(
                                color: AppColors.onAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfacePrimary,
                              borderRadius: BorderRadius.circular(AppRadius.badge),
                              border: Border.all(color: AppColors.borderDefault),
                            ),
                            child: Text(
                              '未選文字',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              activeTheme.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Flexible(
                      child: ListView.separated(
                        key: const ValueKey('theme_picker_list'),
                        shrinkWrap: true,
                        itemCount: themes.length,
                        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final palette = themes[index];
                          final isSelected = palette.id == activeId;
                          return _ThemeOptionTile(
                            palette: palette,
                            isSelected: isSelected,
                            onTap: () => settingsManager.setThemeId(palette.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final AppThemePalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightnessLabel = palette.brightness == Brightness.dark ? '深色' : '淺色';
    final sourceLabel = palette.id == AppThemes.defaultThemeId ? '預設' : palette.source;

    return Semantics(
      selected: isSelected,
      button: true,
      label: palette.name,
      child: Material(
        color: isSelected ? AppColors.surfaceRaised : AppColors.surfaceSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: isSelected ? AppColors.accent : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('theme_option_${palette.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            child: Row(
              children: [
                _PaletteSwatchDots(palette: palette),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        palette.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$brightnessLabel • $sourceLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 12, color: AppColors.onAccent),
                        const SizedBox(width: 3),
                        Text(
                          '使用中',
                          style: TextStyle(
                            color: AppColors.onAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfacePrimary,
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Text(
                      '套用',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteSwatchDots extends StatelessWidget {
  final AppThemePalette palette;
  const _PaletteSwatchDots({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(palette.canvas),
        const SizedBox(width: 3),
        _dot(palette.surfaceSecondary),
        const SizedBox(width: 3),
        _dot(palette.accent),
      ],
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderDefault, width: 1),
      ),
    );
  }
}
