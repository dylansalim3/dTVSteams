import 'package:flutter/material.dart';
import '../services/download_manager.dart';
import '../services/settings_manager.dart';
import '../services/update_manager.dart';
import 'storage_location_sheet.dart';

class AboutUpdateDialog {
  /// Shows the full "About & System Updates" modal dialog
  static void show(BuildContext context, UpdateManager updateManager) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.security, color: Color(0xFFE50914), size: 24),
            SizedBox(width: 8),
            Text(
              '需要安裝應用權限',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          '為讓應用程式能自動完成更新安裝，Android 系統要求為 dTVSteams 開啟「允許安裝未知應用程式」權限。\n\n點選下方按鈕前往系統設定開啟後，即可繼續安裝。',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('稍後再說', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  @override
  void initState() {
    super.initState();
    widget.updateManager.addListener(_onUpdateChange);
    _settingsManager.addListener(_onUpdateChange);
    _downloadManager.addListener(_onUpdateChange);
    _settingsManager.init();
    _downloadManager.init();
  }

  @override
  void dispose() {
    widget.updateManager.removeListener(_onUpdateChange);
    _settingsManager.removeListener(_onUpdateChange);
    _downloadManager.removeListener(_onUpdateChange);
    super.dispose();
  }

  void _onUpdateChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mgr = widget.updateManager;
    final update = mgr.latestUpdate;

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + (bottomInset + 24) / 2,
        ),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'dTV',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '關於與版本更新',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Current Version Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white70, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'dTVSteams 綜藝影音串流平台',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '目前安裝版本: v${UpdateManager.currentAppVersion}',
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: mgr.isChecking
                        ? null
                        : () => mgr.checkForUpdate(manual: true),
                    icon: mgr.isChecking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync, size: 16),
                    label: Text(mgr.isChecking ? '檢查中...' : '檢查更新'),
                  ),
                ],
              ),
            ),

            if (mgr.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mgr.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Playback Preferences Settings Section
            const Text(
              '播放偏好設定 (Settings)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: const Color(0xFF2A2A2A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SwitchListTile(
                    activeColor: const Color(0xFFE50914),
                    title: const Text('背景播放 (鎖定螢幕繼續播放音訊)',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('螢幕關閉鎖定或切換應用時，背景繼續播放節目聲音',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                    value: _settingsManager.backgroundPlay,
                    onChanged: (val) => _settingsManager.setBackgroundPlay(val),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  SwitchListTile(
                    activeColor: const Color(0xFFE50914),
                    title: const Text('播放時保持螢幕常亮 (防止休眠)',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('影片播放中螢幕不會因逾時自動變暗或關閉',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                    value: _settingsManager.keepScreenAwake,
                    onChanged: (val) => _settingsManager.setKeepScreenAwake(val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Download Storage Location Section
            const Text(
              '下載儲存位置 (Download Storage)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildStorageLocationCard(context),

            const SizedBox(height: 16),

            // If Update Available
            if (mgr.updateAvailable && update != null) ...[
              _buildUpdateAvailableCard(context, mgr, update),
            ] else if (!mgr.isChecking && mgr.lastCheckedAt != null && !mgr.updateAvailable) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.check_circle, color: Color(0xFF46D369), size: 20),
                    SizedBox(width: 8),
                    Text(
                      '目前已是最新版本，無需更新',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),

            // Safety Fallback Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    '遇到下載問題？可直接使用瀏覽器',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => mgr.openBrowserFallback(),
                  icon: const Icon(Icons.open_in_browser, size: 16, color: Colors.white70),
                  label: const Text('開啟 GitHub 發布頁', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildStorageLocationCard(BuildContext context) {
    final isCustom = _downloadManager.isUsingCustomDirectory;
    final currentPath = _downloadManager.downloadDirectoryPath;

    return Material(
      color: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isCustom ? Icons.sd_storage : Icons.folder,
                  color: isCustom ? const Color(0xFFE50914) : Colors.white70,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isCustom ? '自訂儲存目錄' : '預設內部儲存空間',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCustom
                                  ? const Color(0xFFE50914).withValues(alpha: 0.2)
                                  : Colors.white12,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isCustom
                                    ? const Color(0xFFE50914).withValues(alpha: 0.5)
                                    : Colors.white24,
                              ),
                            ),
                            child: Text(
                              isCustom ? '已自訂' : '預設',
                              style: TextStyle(
                                color: isCustom ? const Color(0xFFE50914) : Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentPath.isEmpty ? '載入中...' : currentPath,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isCustom) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => StorageLocationHelper.handleResetStorage(context, onStorageChanged: () {
                      if (mounted) setState(() {});
                    }),
                    icon: const Icon(Icons.restore, size: 14),
                    label: const Text('還原預設', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.6), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '發現新版本 v${update.latestVersion}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '安裝包大小: ${update.formattedSize}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            update.releaseTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Release Notes Container
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF191919),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: SingleChildScrollView(
              child: Text(
                update.releaseNotes,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

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
                      style: const TextStyle(color: Color(0xFFE50914), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(mgr.downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(mgr.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: mgr.downloadProgress > 0 ? mgr.downloadProgress : null,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '下載於背景進行中，您可以關閉此視窗繼續觀看劇集',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
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
                        backgroundColor: const Color(0xFF46D369),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        backgroundColor: const Color(0xFFE50914),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    final update = updateManager.latestUpdate;
    if (update == null) return const SizedBox.shrink();

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.system_update_alt, color: Color(0xFFE50914), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '發現新版本 v${update.latestVersion}',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: SingleChildScrollView(
              child: Text(
                update.releaseNotes,
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '檔案大小: ${update.formattedSize}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            updateManager.dismissVersion(update.latestVersion);
            Navigator.of(context).pop();
          },
          child: const Text('稍後再說', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE50914),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
