import 'dart:io';
import 'package:flutter/material.dart';
import '../services/download_manager.dart';
import '../services/storage_service.dart';

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
      builder: (ctx) => Material(
        color: const Color(0xFF222222),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          bottom: true,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '選擇下載儲存位置',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Option 1: Default App Documents
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder, color: Colors.white70),
                  title: const Text('預設應用內部儲存', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(defaultPath, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  trailing: (downloadManager.downloadDirectoryPath == defaultPath)
                      ? const Icon(Icons.check, color: Color(0xFF46D369), size: 20)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    handleSelectLocation(context, defaultPath, onStorageChanged: onStorageChanged);
                  },
                ),
                const Divider(color: Colors.white12, height: 1),

                // Option 2: Public Download folder
                if (publicDownloads != null && publicDownloads.isNotEmpty) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.file_download, color: Color(0xFFE50914)),
                    title: const Text('系統公開下載資料夾 (Downloads/dTVSteams)',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(publicDownloads, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    trailing: (downloadManager.downloadDirectoryPath == publicDownloads)
                        ? const Icon(Icons.check, color: Color(0xFF46D369), size: 20)
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      handleSelectLocation(context, publicDownloads, onStorageChanged: onStorageChanged);
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                ],

                // Option 3: Public Movies folder
                if (publicMovies != null && publicMovies.isNotEmpty) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.movie, color: Colors.amber),
                    title: const Text('系統公開影片資料夾 (Movies/dTVSteams)',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: Text(publicMovies, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    trailing: (downloadManager.downloadDirectoryPath == publicMovies)
                        ? const Icon(Icons.check, color: Color(0xFF46D369), size: 20)
                        : null,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      handleSelectLocation(context, publicMovies, onStorageChanged: onStorageChanged);
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                ],

                // Option 4: Custom Directory Picker / Input
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.drive_folder_upload, color: Colors.lightBlueAccent),
                  title: const Text('自訂資料夾 (系統資料夾選取器)...',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('自由選取手機或 SD 卡上的任意儲存資料夾',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await pickCustomDirectory(context, onStorageChanged: onStorageChanged);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
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
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('手動輸入儲存路徑', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            hintText: '/storage/emulated/0/...',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE50914))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
            onPressed: () {
              final path = controller.text.trim();
              Navigator.of(ctx).pop();
              if (path.isNotEmpty) {
                handleSelectLocation(context, path, onStorageChanged: onStorageChanged);
              }
            },
            child: const Text('確定', style: TextStyle(color: Colors.white)),
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
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.folder_shared, color: Color(0xFFE50914), size: 22),
                SizedBox(width: 8),
                Text('需要儲存空間權限', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: const Text(
              '存取並寫入外部儲存資料夾需要「所有檔案存取權限」。\n\n點選下方按鈕前往系統設定開啟授權。',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
                onPressed: () async {
                  Navigator.of(ctx).pop(true);
                  await StorageService.requestStoragePermission();
                },
                child: const Text('前往設定', style: TextStyle(color: Colors.white)),
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
          backgroundColor: Color(0xFF1E1E1E),
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFFE50914)),
              SizedBox(width: 16),
              Expanded(
                child: Text('正在轉移已下載影片與目錄...', style: TextStyle(color: Colors.white, fontSize: 14)),
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
            backgroundColor: const Color(0xFFE50914),
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
          backgroundColor: Color(0xFF1E1E1E),
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFFE50914)),
              SizedBox(width: 16),
              Expanded(
                child: Text('正在還原為預設儲存位置...', style: TextStyle(color: Colors.white, fontSize: 14)),
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
            backgroundColor: const Color(0xFFE50914),
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
