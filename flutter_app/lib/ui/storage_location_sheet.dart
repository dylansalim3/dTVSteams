import 'dart:io';
import 'package:flutter/material.dart';
import '../services/download_manager.dart';
import '../services/storage_service.dart';
import 'app_tokens.dart';

/// Helper and UI modal for changing download storage location.
/// Reusable across Settings (AboutUpdateDialog) and the Downloads Screen.
class StorageLocationHelper {
  static Future<void> showStoragePickerSheet(
    BuildContext context, {
    VoidCallback? onStorageChanged,
  }) async {
    final downloadManager = DownloadManager();
    final defaultPath = await downloadManager.getDefaultDownloadDirectory();
    final publicLocations = await StorageService.getPublicStorageLocations();
    final publicDownloads = publicLocations['downloads'];
    final publicMovies = publicLocations['movies'];

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final maxHeight = mediaQuery.size.height * 0.72;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: AppColors.surfaceOverlay,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
              side: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: true,
              bottom: true,
              minimum: const EdgeInsets.only(top: AppSpacing.sm),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  (mediaQuery.padding.bottom + AppSpacing.lg) / 2,
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
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '選擇下載儲存位置',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                          style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          tooltip: '關閉',
                          icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Material(
                          color: AppColors.cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            side: const BorderSide(color: AppColors.borderSubtle),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Option 1: Default App Documents
                              ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                                leading: const Icon(Icons.folder, color: AppColors.textSecondary),
                                title: const Text('預設應用內部儲存', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                                subtitle: Tooltip(
                                  message: defaultPath,
                                  child: Text(
                                    defaultPath,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
                                  ),
                                ),
                                trailing: (downloadManager.downloadDirectoryPath == defaultPath)
                                    ? const Icon(Icons.check, color: AppColors.success, size: 20)
                                    : null,
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  handleSelectLocation(context, defaultPath, onStorageChanged: onStorageChanged);
                                },
                              ),
                              const Divider(color: AppColors.borderSubtle, height: 1),

                              // Option 2: Public Download folder
                              if (publicDownloads != null && publicDownloads.isNotEmpty) ...[
                                ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                                  leading: const Icon(Icons.file_download, color: AppColors.textSecondary),
                                  title: const Text('系統公開下載資料夾 (Downloads/dTVSteams)',
                                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                                  subtitle: Tooltip(
                                    message: publicDownloads,
                                    child: Text(
                                      publicDownloads,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
                                    ),
                                  ),
                                  trailing: (downloadManager.downloadDirectoryPath == publicDownloads)
                                      ? const Icon(Icons.check, color: AppColors.success, size: 20)
                                      : null,
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    handleSelectLocation(context, publicDownloads, onStorageChanged: onStorageChanged);
                                  },
                                ),
                                const Divider(color: AppColors.borderSubtle, height: 1),
                              ],

                              // Option 3: Public Movies folder
                              if (publicMovies != null && publicMovies.isNotEmpty) ...[
                                ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                                  leading: const Icon(Icons.movie, color: AppColors.textSecondary),
                                  title: const Text('系統公開影片資料夾 (Movies/dTVSteams)',
                                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                                  subtitle: Tooltip(
                                    message: publicMovies,
                                    child: Text(
                                      publicMovies,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
                                    ),
                                  ),
                                  trailing: (downloadManager.downloadDirectoryPath == publicMovies)
                                      ? const Icon(Icons.check, color: AppColors.success, size: 20)
                                      : null,
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    handleSelectLocation(context, publicMovies, onStorageChanged: onStorageChanged);
                                  },
                                ),
                                const Divider(color: AppColors.borderSubtle, height: 1),
                              ],

                              // Option 4: Custom Directory Picker / Input
                              ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                                leading: const Icon(Icons.drive_folder_upload, color: AppColors.accent),
                                title: const Text('自訂資料夾 (系統資料夾選取器)...',
                                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                                subtitle: const Text('自由選取手機或 SD 卡上的任意儲存資料夾',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                onTap: () async {
                                  Navigator.of(ctx).pop();
                                  await pickCustomDirectory(context, onStorageChanged: onStorageChanged);
                                },
                              ),
                            ],
                          ),
                        ),
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

  static Future<void> pickCustomDirectory(
    BuildContext context, {
    VoidCallback? onStorageChanged,
  }) async {
    final picked = await StorageService.pickDirectory();
    if (picked != null && picked.isNotEmpty) {
      if (!context.mounted) return;
      await handleSelectLocation(context, picked, onStorageChanged: onStorageChanged);
    } else if (Platform.isAndroid) {
      if (!context.mounted) return;
      showManualPathDialog(context, onStorageChanged: onStorageChanged);
    }
  }

  static void showManualPathDialog(
    BuildContext context, {
    VoidCallback? onStorageChanged,
  }) {
    final downloadManager = DownloadManager();
    final controller = TextEditingController(text: downloadManager.downloadDirectoryPath);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceOverlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.modal)),
        title: const Text('手動輸入儲存路徑', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: const InputDecoration(
            hintText: '/storage/emulated/0/...',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              final path = controller.text.trim();
              Navigator.of(ctx).pop();
              if (path.isNotEmpty) {
                handleSelectLocation(context, path, onStorageChanged: onStorageChanged);
              }
            },
            child: const Text('確定', style: TextStyle(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  static Future<void> handleSelectLocation(
    BuildContext context,
    String targetPath, {
    VoidCallback? onStorageChanged,
  }) async {
    final downloadManager = DownloadManager();
    final defaultPath = await downloadManager.getDefaultDownloadDirectory();

    // If target is external storage, check permission
    if (targetPath != defaultPath && Platform.isAndroid) {
      final hasPerm = await StorageService.hasStoragePermission();
      if (!hasPerm) {
        if (!context.mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceOverlay,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.modal)),
            title: const Row(
              children: [
                Icon(Icons.folder_shared, color: AppColors.accent, size: 22),
                SizedBox(width: AppSpacing.sm),
                Text('需要儲存空間權限', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
              ],
            ),
            content: const Text(
              '存取並寫入外部儲存資料夾需要「所有檔案存取權限」。\n\n點選下方按鈕前往系統設定開啟授權。',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () async {
                  Navigator.of(ctx).pop(true);
                  await StorageService.requestStoragePermission();
                },
                child: const Text('前往設定', style: TextStyle(color: AppColors.textPrimary)),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    if (!context.mounted) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceOverlay,
          content: Row(
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text('正在轉移已下載影片與目錄...', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final migratedCount = await downloadManager.migrateDownloadDirectory(targetPath);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              migratedCount > 0
                  ? '儲存位置已更新，已自動轉移 $migratedCount 部影片！'
                  : '下載儲存位置已更新',
            ),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 3),
          ),
        );
        onStorageChanged?.call();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('變更儲存位置失敗: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  static Future<void> handleResetStorage(
    BuildContext context, {
    VoidCallback? onStorageChanged,
  }) async {
    final downloadManager = DownloadManager();

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceOverlay,
          content: Row(
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text('正在還原為預設儲存位置...', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final migratedCount = await downloadManager.resetToDefaultDownloadDirectory();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              migratedCount > 0
                  ? '已還原預設儲存位置，轉移了 $migratedCount 部影片！'
                  : '已還原為預設應用儲存位置',
            ),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 3),
          ),
        );
        onStorageChanged?.call();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('還原預設位置失敗: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
