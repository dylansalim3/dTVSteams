import 'package:flutter/material.dart';
import '../services/download_manager.dart';
import '../services/settings_manager.dart';
import '../services/sleep_timer_manager.dart';
import '../services/update_manager.dart';
import 'app_themes.dart';
import 'app_tokens.dart';
import 'sleep_timer_sheet.dart';
import 'storage_location_sheet.dart';
import 'theme_picker_sheet.dart';

class AboutUpdateDialog {
  /// Shows the full "About & System Updates" modal dialog
  static void show(BuildContext context, UpdateManager updateManager) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _AboutUpdateSheet(updateManager: updateManager),
    );
  }

  /// Automatically prompts when a new update is found on startup
  static void showUpdatePrompt(BuildContext context, UpdateManager updateManager) {
    if (updateManager.latestUpdate == null || !updateManager.updateAvailable) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _NewVersionDialog(updateManager: updateManager),
    );
  }

  /// Shows the permission explanation dialog before opening system settings
  static void showPermissionExplanationDialog(BuildContext context, UpdateManager updateManager) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOverlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.modal)),
        title: Row(
          children: [
            Icon(Icons.security, color: AppColors.accent, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '需要安裝應用權限',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          '為讓應用程式能自動完成更新安裝，Android 系統要求為 dTVSteams 開啟「允許安裝未知應用程式」權限。\n\n點選下方按鈕前往系統設定開啟後，即可繼續安裝。',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('稍後再說', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await updateManager.openInstallPermissionSettings();
            },
            child: const Text('前往系統設定開啟'),
          ),
        ],
      ),
    );
  }
}

class _AboutUpdateSheet extends StatefulWidget {
  final UpdateManager updateManager;
  const _AboutUpdateSheet({required this.updateManager});

  @override
  State<_AboutUpdateSheet> createState() => _AboutUpdateSheetState();
}

class _AboutUpdateSheetState extends State<_AboutUpdateSheet> {
  final SettingsManager _settingsManager = SettingsManager();
  final DownloadManager _downloadManager = DownloadManager();
  final SleepTimerManager _sleepTimerManager = SleepTimerManager();

  @override
  void initState() {
    super.initState();
    widget.updateManager.addListener(_onUpdateChange);
    _settingsManager.addListener(_onUpdateChange);
    _downloadManager.addListener(_onUpdateChange);
    _sleepTimerManager.addListener(_onUpdateChange);
    _settingsManager.init();
    _downloadManager.init();
  }

  @override
  void dispose() {
    widget.updateManager.removeListener(_onUpdateChange);
    _settingsManager.removeListener(_onUpdateChange);
    _downloadManager.removeListener(_onUpdateChange);
    _sleepTimerManager.removeListener(_onUpdateChange);
    super.dispose();
  }

  void _onUpdateChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    final mgr = widget.updateManager;
    final update = mgr.latestUpdate;

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final maxSheetHeight = mediaQuery.size.height * 0.75;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
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
              mediaQuery.viewInsets.bottom + (bottomInset + AppSpacing.lg) / 2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle indicator (pinned)
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
                // Header with Close (pinned)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(AppRadius.badge),
                          ),
                          child: Text(
                            'dTV',
                            style: TextStyle(
                              color: AppColors.onAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '關於與版本更新',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                      style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      tooltip: '關閉設定',
                      icon: Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Version Card
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppColors.textSecondary, size: 22),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'dTVSteams 綜藝影音串流平台',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '目前安裝版本: v${UpdateManager.currentAppVersion}',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: AppColors.onAccent,
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                                  minimumSize: const Size(0, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                onPressed: mgr.isChecking
                                    ? null
                                    : () => mgr.checkForUpdate(manual: true),
                                icon: mgr.isChecking
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent),
                                      )
                                    : const Icon(Icons.sync, size: 15),
                                label: Text(mgr.isChecking ? '檢查中...' : '檢查更新', style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),

                        if (mgr.errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.dangerSurface,
                              borderRadius: BorderRadius.circular(AppRadius.chip),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: AppColors.accent, size: 16),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    mgr.errorMessage!,
                                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.md),

                        // Theme Selection Section (21st.dev Themes)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '外觀主題 (Theme)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${AppThemes.twentyFirstDevThemes.length} 款 21st.dev 主題',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildThemeSelectionCard(context),

                        const SizedBox(height: AppSpacing.md),

                        // Playback Preferences Settings Section (with declared autosave indicator)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '播放偏好設定 (Settings)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '變更將自動儲存',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Material(
                          color: AppColors.cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            side: BorderSide(color: AppColors.borderSubtle),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              CompactSwitchTile(
                                title: '背景播放 (鎖定螢幕繼續播放音訊)',
                                subtitle: '螢幕關閉鎖定或切換應用時，背景繼續播放節目聲音',
                                value: _settingsManager.backgroundPlay,
                                onChanged: (val) => _settingsManager.setBackgroundPlay(val),
                              ),
                              Divider(color: AppColors.borderSubtle, height: 1),
                              CompactSwitchTile(
                                title: '播放時保持螢幕常亮 (防止休眠)',
                                subtitle: '影片播放中螢幕不會因逾時自動變暗或關閉',
                                value: _settingsManager.keepScreenAwake,
                                onChanged: (val) => _settingsManager.setKeepScreenAwake(val),
                              ),
                              Divider(color: AppColors.borderSubtle, height: 1),
                              CompactSwitchTile(
                                title: '自動連續播放下一段 / 下一集',
                                subtitle: '分段或整集播畢前浮現 5 秒倒數並自動續播',
                                value: _settingsManager.autoPlayNext,
                                onChanged: (val) => _settingsManager.setAutoPlayNext(val),
                              ),
                              Divider(color: AppColors.borderSubtle, height: 1),
                              ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
                                leading: Icon(
                                  _sleepTimerManager.isActive ? Icons.alarm_on : Icons.timer_outlined,
                                  size: 20,
                                  color: _sleepTimerManager.isActive ? AppColors.accent : AppColors.textSecondary,
                                ),
                                title: Text('睡眠定時器 (Sleep Timer)',
                                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  _sleepTimerManager.isActive
                                      ? '倒數中：${_sleepTimerManager.formattedTime}'
                                      : '定時自動暫停並停止背景音訊服務',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _sleepTimerManager.isActive ? AppColors.accent : AppColors.textMuted,
                                    fontSize: 11,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                trailing: Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  showSleepTimerSheet(context);
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Download Storage Location Section
                        Text(
                          '下載儲存位置 (Download Storage)',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildStorageLocationCard(context),

                        const SizedBox(height: AppSpacing.md),

                        // If Update Available
                        if (mgr.updateAvailable && update != null) ...[
                          _buildUpdateAvailableCard(context, mgr, update),
                        ] else if (!mgr.isChecking && mgr.lastCheckedAt != null && !mgr.updateAvailable) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: AppColors.success, size: 18),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  '目前已是最新版本，無需更新',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),
                        Divider(color: AppColors.borderSeparator, height: 1),
                        const SizedBox(height: 4),

                        // Safety Fallback Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '遇到下載問題？可直接使用瀏覽器',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              onPressed: () => mgr.openBrowserFallback(),
                              icon: Icon(Icons.open_in_browser, size: 15, color: AppColors.textSecondary),
                              label: Text('開啟 GitHub 發布頁', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildThemeSelectionCard(BuildContext context) {
    final activeTheme = _settingsManager.activeTheme;
    return Material(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: const ValueKey('settings_theme_picker_tile'),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _themeDot(activeTheme.canvas),
            const SizedBox(width: 3),
            _themeDot(activeTheme.surfaceSecondary),
            const SizedBox(width: 3),
            _themeDot(activeTheme.accent),
          ],
        ),
        title: Text(
          activeTheme.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '點擊從 ${AppThemes.all.length} 款主題即時切換',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(AppRadius.badge),
              ),
              child: Text(
                '更換主題',
                style: TextStyle(
                  color: AppColors.onAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 18),
          ],
        ),
        onTap: () => showThemePickerSheet(context, _settingsManager),
      ),
    );
  }

  Widget _themeDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderDefault, width: 1),
      ),
    );
  }

  Widget _buildStorageLocationCard(BuildContext context) {
    final isCustom = _downloadManager.isUsingCustomDirectory;
    final currentPath = _downloadManager.downloadDirectoryPath;

    return Material(
      color: AppColors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isCustom ? Icons.sd_storage : Icons.folder,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isCustom ? '自訂儲存目錄' : '預設內部儲存空間',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCustom
                                  ? AppColors.success.withValues(alpha: 0.16)
                                  : AppColors.surfaceInteractive,
                              borderRadius: BorderRadius.circular(AppRadius.badge),
                              border: Border.all(
                                color: isCustom
                                    ? AppColors.success.withValues(alpha: 0.45)
                                    : AppColors.borderDefault,
                              ),
                            ),
                            child: Text(
                              isCustom ? '已自訂' : '預設',
                              style: TextStyle(
                                color: isCustom ? AppColors.success : AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Tooltip(
                        message: currentPath,
                        child: Text(
                          currentPath.isEmpty ? '載入中...' : currentPath,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isCustom) ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                    ),
                    onPressed: () => StorageLocationHelper.handleResetStorage(context, onStorageChanged: () {
                      if (mounted) setState(() {});
                    }),
                    icon: const Icon(Icons.restore, size: 14),
                    label: const Text('還原預設', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                  ),
                  onPressed: () => StorageLocationHelper.showStoragePickerSheet(context, onStorageChanged: () {
                    if (mounted) setState(() {});
                  }),
                  icon: const Icon(Icons.drive_file_move_outlined, size: 14),
                  label: const Text('變更位置', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateAvailableCard(BuildContext context, UpdateManager mgr, AppUpdateInfo update) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.modal),
                ),
                child: Text(
                  '發現新版本 v${update.latestVersion}',
                  style: TextStyle(
                    color: AppColors.onAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '安裝包大小: ${update.formattedSize}',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            update.releaseTitle,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Release Notes Container
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: SingleChildScrollView(
              child: Text(
                update.releaseNotes,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Downloading Progress Bar
          if (mgr.isDownloading) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '背景下載中... ${(mgr.downloadProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '${(mgr.downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(mgr.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  child: LinearProgressIndicator(
                    value: mgr.downloadProgress > 0 ? mgr.downloadProgress : null,
                    minHeight: 6,
                    backgroundColor: AppColors.borderSubtle,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '下載於背景進行中，您可以關閉此視窗繼續觀看劇集',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ] else ...[
            // Action Buttons
            Row(
              children: [
                if (mgr.isDownloaded) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.onSuccess,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                      ),
                      onPressed: () => _handleInstall(context, mgr),
                      icon: const Icon(Icons.install_mobile, size: 18),
                      label: const Text(
                        '安裝檔已就緒，立即安裝',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                      ),
                      onPressed: () async {
                        final success = await mgr.startDownload();
                        if (success && context.mounted) {
                          _handleInstall(context, mgr);
                        }
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text(
                        '背景下載更新 (Download)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '提示：若系統提示「安裝套件無效」或「套件與現有套件衝突」，代表手機現有版本與本次正式版簽名不相容。請先手動解除安裝舊版後再安裝，之後的版本即可直接覆蓋更新。',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleInstall(BuildContext context, UpdateManager mgr) async {
    final canInstall = await mgr.canRequestPackageInstalls();
    if (!canInstall && context.mounted) {
      AboutUpdateDialog.showPermissionExplanationDialog(context, mgr);
      return;
    }
    await mgr.installApk();
  }
}

class _NewVersionDialog extends StatelessWidget {
  final UpdateManager updateManager;
  const _NewVersionDialog({required this.updateManager});

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    final update = updateManager.latestUpdate;
    if (update == null) return const SizedBox.shrink();

    return AlertDialog(
      backgroundColor: AppColors.surfaceOverlay,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.modal)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.system_update_alt, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '發現新版本 v${update.latestVersion}',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            update.releaseTitle,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: SingleChildScrollView(
              child: Text(
                update.releaseNotes,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '檔案大小: ${update.formattedSize}',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            updateManager.dismissVersion(update.latestVersion);
            Navigator.of(context).pop();
          },
          child: Text('稍後再說', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            // Open full update sheet
            AboutUpdateDialog.show(context, updateManager);
            if (!updateManager.isDownloading && !updateManager.isDownloaded) {
              updateManager.startDownload();
            }
          },
          child: const Text('立即更新 (背景下載)'),
        ),
      ],
    );
  }
}
