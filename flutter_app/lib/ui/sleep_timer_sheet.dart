import 'package:flutter/material.dart';
import '../services/sleep_timer_manager.dart';
import 'app_tokens.dart';

/// Bottom Sheet for selecting Sleep Timer duration (BoardUI surface & radio list tokens)
void showSleepTimerSheet(BuildContext context, {VoidCallback? onTimerChanged}) {
  final manager = SleepTimerManager();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceSecondary,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      side: BorderSide(color: AppColors.borderSeparator),
    ),
    builder: (ctx) {
      return AnimatedBuilder(
        animation: manager,
        builder: (context, _) {
          AppColors.watch(context);
          final bottomInset = MediaQuery.of(context).padding.bottom;
          return SafeArea(
            top: true,
            bottom: true,
            minimum: const EdgeInsets.only(top: AppSpacing.sm),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                (bottomInset + AppSpacing.lg) / 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.borderDefault,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  // Title Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.accentSoft,
                                borderRadius: BorderRadius.circular(AppRadius.control),
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Icon(Icons.timer_outlined, color: AppColors.accentForeground, size: 20),
                            ),
                            const SizedBox(width: AppSpacing.md - 2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '睡眠定時器 (Sleep Timer)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppType.title3Semibold,
                                  ),
                                  if (manager.isActive) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '倒數中：${manager.formattedTime}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.caption1Semibold.copyWith(
                                        color: AppColors.accentForeground,
                                        fontFeatures: AppType.tabular,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Option Tiles
                  Material(
                    color: AppColors.surfaceRaised,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      side: BorderSide(color: AppColors.borderSeparator),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: SleepTimerMode.values.map((mode) {
                        final isSelected = manager.mode == mode;
                        return InkWell(
                          onTap: () {
                            manager.setTimer(mode);
                            Navigator.of(ctx).pop();
                            onTimerChanged?.call();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  mode == SleepTimerMode.off
                                      ? '已關閉睡眠定時器'
                                      : '已設定睡眠定時：${mode.label}',
                                  style: TextStyle(color: AppColors.textPrimary),
                                ),
                                duration: const Duration(seconds: 2),
                                backgroundColor: AppColors.surfacePrimary,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accentSoft : Colors.transparent,
                              border: Border(
                                bottom: mode != SleepTimerMode.values.last
                                    ? BorderSide(color: AppColors.borderSeparator, width: 1)
                                    : BorderSide.none,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: isSelected ? AppColors.accentForeground : AppColors.textTertiary,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Text(
                                    mode.label,
                                    style: (isSelected ? AppType.bodyMedium : AppType.bodyRegular).copyWith(
                                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                if (isSelected && manager.isActive)
                                  Text(
                                    manager.formattedTime,
                                    style: AppType.caption1Semibold.copyWith(
                                      color: AppColors.accentForeground,
                                      fontFeatures: AppType.tabular,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
