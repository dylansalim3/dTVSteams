import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../catalog/parser.dart';
import '../catalog/show_channel.dart';
import '../services/download_manager.dart';
import '../services/favorites_manager.dart';
import '../services/playback_history_manager.dart';
import 'app_tokens.dart';
import 'downloads_screen.dart';
import 'player_screen.dart';
import 'share_dialog.dart';

/// Segmented Single-Border Circular Progress Download Icon (3-piece pie border)
/// Slice 1 (Top-Right): Part 1
/// Slice 2 (Bottom):    Part 2
/// Slice 3 (Top-Left):  Part 3
class TripleCircleDownloadButton extends StatelessWidget {
  final CatalogEpisode episode;
  final DownloadManager downloadManager;
  final VoidCallback onTap;

  const TripleCircleDownloadButton({
    super.key,
    required this.episode,
    required this.downloadManager,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parts = episode.parts;
    final totalParts = parts.isNotEmpty ? parts.length : 3;

    final progresses = <double>[];
    final isDownloadingList = <bool>[];
    final isDownloadedList = <bool>[];
    final isFailedList = <bool>[];

    for (int i = 0; i < totalParts; i++) {
      if (i < parts.length) {
        final p = parts[i];
        final isDown = downloadManager.isDownloaded(episode.id, p.label,
            showId: episode.showId, title: episode.title);
        final isDl = downloadManager.isDownloading(episode.id, p.label,
            showId: episode.showId, title: episode.title);
        final isFail = downloadManager.isFailed(episode.id, p.label,
            showId: episode.showId, title: episode.title);
        final item = downloadManager.getItem(episode.id, p.label,
            showId: episode.showId, title: episode.title);

        isDownloadedList.add(isDown);
        isDownloadingList.add(isDl);
        isFailedList.add(isFail);
        progresses.add(isDown ? 1.0 : ((isDl || isFail) && item != null ? item.progress : 0.0));
      } else {
        isDownloadedList.add(false);
        isDownloadingList.add(false);
        isFailedList.add(false);
        progresses.add(0.0);
      }
    }

    final allDownloaded = isDownloadedList.isNotEmpty && isDownloadedList.every((d) => d);
    final anyDownloading = isDownloadingList.any((d) => d);
    final anyFailed = isFailedList.any((f) => f);

    return TvFocusableButton(
      onPressed: onTap,
      child: Tooltip(
        message: allDownloaded
            ? '已下載全部分段 (點擊管理)'
            : (anyDownloading
                ? '分段下載中 (點擊查看)'
                : (anyFailed ? '部分分段下載失敗 (點擊重試)' : '下載此集分段')),
        child: SizedBox(
          width: AppCardTokens.actionHitSize,
          height: AppCardTokens.actionHitSize,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: Container(
                  width: AppCardTokens.actionVisualSize,
                  height: AppCardTokens.actionVisualSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.actionCircleBg,
                    shape: BoxShape.circle,
                  ),
                  child: CustomPaint(
                    size: const Size(30, 30),
                    painter: TripleRingPainter(
                      progresses: progresses,
                      isDownloading: isDownloadingList,
                      isDownloaded: isDownloadedList,
                      isFailed: isFailedList,
                      allDownloaded: allDownloaded,
                      anyDownloading: anyDownloading,
                      anyFailed: anyFailed,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for single circular border segmented into 3 pie pieces
class TripleRingPainter extends CustomPainter {
  final List<double> progresses;
  final List<bool> isDownloading;
  final List<bool> isDownloaded;
  final List<bool> isFailed;
  final bool allDownloaded;
  final bool anyDownloading;
  final bool anyFailed;

  TripleRingPainter({
    required this.progresses,
    required this.isDownloading,
    required this.isDownloaded,
    required this.isFailed,
    required this.allDownloaded,
    required this.anyDownloading,
    required this.anyFailed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 2.4;
    final radius = (size.width - strokeWidth) / 2;

    const totalParts = 3;
    const totalAnglePerPart = (2 * math.pi) / totalParts;
    // Gap angle between each pie slice (~9 degrees)
    const gapAngle = 0.16;
    const arcLength = totalAnglePerPart - gapAngle;

    // Start angle centered around top (-90 degrees)
    const baseStart = -math.pi / 2;

    for (int i = 0; i < totalParts; i++) {
      final partStart = baseStart + (i * totalAnglePerPart) + (gapAngle / 2);
      final isDown = i < isDownloaded.length && isDownloaded[i];
      final isDl = i < isDownloading.length && isDownloading[i];
      final isFail = i < isFailed.length && isFailed[i];
      final progress = i < progresses.length ? progresses[i] : 0.0;

      // 1. Background arc track for this pie piece
      final bgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth
        ..color = isDown
            ? AppColors.success.withValues(alpha: 0.25)
            : (isDl
                ? AppColors.accent.withValues(alpha: 0.25)
                : (isFail
                    ? AppColors.warning.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.20)));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        partStart,
        arcLength,
        false,
        bgPaint,
      );

      // 2. Completed / Downloading / Failed arc for this pie piece
      if (isDown) {
        final fgPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth
          ..color = AppColors.success;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          partStart,
          arcLength,
          false,
          fgPaint,
        );
      } else if ((isDl || isFail) && progress > 0.0) {
        final fgPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth
          ..color = isFail ? AppColors.warning : AppColors.accent;

        final fillSweep = math.max(arcLength * 0.12, arcLength * progress);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          partStart,
          fillSweep,
          false,
          fgPaint,
        );
      } else if (isFail) {
        final fgPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth
          ..color = AppColors.warning;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          partStart,
          arcLength * 0.28,
          false,
          fgPaint,
        );
      }
    }

    // 3. Center Icon
    if (allDownloaded) {
      // Completed Checkmark
      final p1 = Offset(center.dx - 3.5, center.dy);
      final p2 = Offset(center.dx - 1.0, center.dy + 3.2);
      final p3 = Offset(center.dx + 4.2, center.dy - 3.2);
      final checkPaint = Paint()
        ..color = AppColors.success
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.8;
      canvas.drawLine(p1, p2, checkPaint);
      canvas.drawLine(p2, p3, checkPaint);
    } else if (anyFailed && !anyDownloading) {
      // Warning Exclamation Icon
      final warnPaint = Paint()
        ..color = AppColors.warning
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.0;
      canvas.drawLine(
        Offset(center.dx, center.dy - 4.0),
        Offset(center.dx, center.dy + 1.0),
        warnPaint,
      );
      canvas.drawCircle(
        Offset(center.dx, center.dy + 3.8),
        1.1,
        Paint()..color = AppColors.warning,
      );
    } else {
      // Crisp Download Arrow & Tray
      final arrowColor = anyDownloading ? AppColors.accent : AppColors.textSecondary;
      final arrowPaint = Paint()
        ..color = arrowColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.6;

      // Vertical stem
      canvas.drawLine(
        Offset(center.dx, center.dy - 3.6),
        Offset(center.dx, center.dy + 1.2),
        arrowPaint,
      );

      // Arrow head V
      final headPath = Path();
      headPath.moveTo(center.dx - 2.6, center.dy - 0.4);
      headPath.lineTo(center.dx, center.dy + 2.0);
      headPath.lineTo(center.dx + 2.6, center.dy - 0.4);
      canvas.drawPath(headPath, arrowPaint);

      // Bottom tray line
      canvas.drawLine(
        Offset(center.dx - 3.6, center.dy + 4.4),
        Offset(center.dx + 3.6, center.dy + 4.4),
        arrowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TripleRingPainter oldDelegate) {
    return allDownloaded != oldDelegate.allDownloaded ||
        anyDownloading != oldDelegate.anyDownloading ||
        anyFailed != oldDelegate.anyFailed ||
        !listEquals(progresses, oldDelegate.progresses) ||
        !listEquals(isDownloading, oldDelegate.isDownloading) ||
        !listEquals(isDownloaded, oldDelegate.isDownloaded) ||
        !listEquals(isFailed, oldDelegate.isFailed);
  }
}

void _startPartDownloadWithFeedback({
  required ScaffoldMessengerState messenger,
  required NavigatorState navigator,
  required DownloadManager downloadManager,
  required CatalogEpisode episode,
  required CatalogPart part,
  required String showId,
}) {
  messenger.removeCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text('已開始下載 ${episode.title} - ${part.label}'),
      backgroundColor: AppColors.accent,
      action: SnackBarAction(
        label: '查看進度',
        textColor: AppColors.textPrimary,
        onPressed: () => navigator.push(
          MaterialPageRoute(builder: (_) => const DownloadsScreen()),
        ),
      ),
    ),
  );

  downloadManager.startDownload(episode, part).then((ok) {
    if (!ok && messenger.mounted) {
      final failedItem = downloadManager.getItem(
        episode.id,
        part.label,
        showId: showId,
        title: episode.title,
      );
      if (failedItem?.status == DownloadStatus.failed) {
        messenger.removeCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '下載失敗 (${part.label})：${failedItem?.error ?? "請檢查網路後重試"}',
            ),
            backgroundColor: AppColors.warningSurface,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '重試',
              textColor: AppColors.warning,
              onPressed: () => _startPartDownloadWithFeedback(
                messenger: messenger,
                navigator: navigator,
                downloadManager: downloadManager,
                episode: episode,
                part: part,
                showId: showId,
              ),
            ),
          ),
        );
      }
    }
  });
}

Future<void> _confirmDeletePart({
  required BuildContext dialogContext,
  required ScaffoldMessengerState messenger,
  required DownloadManager downloadManager,
  required CatalogEpisode episode,
  required CatalogPart part,
  required String showId,
  required bool isDownloading,
  required bool isFailed,
  required VoidCallback onDeleted,
}) async {
  final actionVerb = isDownloading ? '取消並刪除' : (isFailed ? '刪除失敗紀錄與暫存' : '刪除離線檔案');
  final confirmed = await showDialog<bool>(
    context: dialogContext,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.modal),
        side: const BorderSide(color: AppColors.borderSubtle, width: 1),
      ),
      title: Text(actionVerb, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      content: Text(
        isDownloading
            ? '確定要取消下載「${episode.title} - ${part.label}」並刪除已下載的部分檔案嗎？'
            : '確定要刪除「${episode.title} - ${part.label}」的${isFailed ? "失敗下載紀錄與暫存檔" : "離線檔案"}嗎？',
        style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surfaceInteractive,
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          ),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(isDownloading ? '取消下載' : '刪除', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  final freedBytes = await downloadManager.deleteDownload(
    episode.id,
    part.label,
    showId: showId,
    title: episode.title,
  );
  onDeleted();
  if (messenger.mounted) {
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          freedBytes > 0
              ? '已刪除 ${part.label}（釋出 ${downloadManager.formatBytes(freedBytes)}）'
              : '已清除 ${part.label} 下載紀錄',
        ),
      ),
    );
  }
}

/// Download Part Selection Modal Sheet
void showDownloadSelectionSheet(
  BuildContext context,
  CatalogEpisode episode,
  DownloadManager downloadManager,
) {
  final rootMessenger = ScaffoldMessenger.of(context);
  final rootNavigator = Navigator.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceOverlay,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
    ),
    builder: (ctx) {
      return ListenableBuilder(
        listenable: downloadManager,
        builder: (sheetContext, _) {
          final showId = episode.showId.isNotEmpty
              ? episode.showId
              : CatalogParser.detectShowId('${episode.title} ${episode.id}');
          final showName = episode.showName.isNotEmpty
              ? episode.showName
              : ShowChannels.getShowName(showId);
          final showEmoji = ShowChannels.getEmoji(showId);

          final parts = episode.parts;
          final downloadedCount = parts
              .where((p) => downloadManager.isDownloaded(episode.id, p.label,
                  showId: showId, title: episode.title))
              .length;
          final allDone = parts.isNotEmpty && downloadedCount == parts.length;
          final bottomInset = MediaQuery.of(sheetContext).padding.bottom;

          return SafeArea(
            top: true,
            bottom: true,
            minimum: const EdgeInsets.only(top: AppSpacing.sm),
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, (bottomInset + AppSpacing.lg) / 2),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: const Icon(Icons.download_for_offline, color: AppColors.accent, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showName.isNotEmpty) ...[
                                Text(
                                  '$showEmoji $showName',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              const Text(
                                '下載分段管理',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                allDone
                                    ? '已下載全部分段 (${parts.length}/${parts.length}) • 可離線觀看'
                                    : '已下載 $downloadedCount/${parts.length} 個分段 • 點擊選擇分段下載',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: allDone ? AppColors.success : AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(color: AppColors.borderSubtle, height: 1),
                    const SizedBox(height: AppSpacing.md),

                    // One-tap Batch Download All Parts Button
                    if (!allDone) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.textPrimary,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
                          ),
                          icon: const Icon(Icons.download_for_offline, size: 18),
                          label: Text(
                            '一鍵下載全集 (剩餘 ${parts.length - downloadedCount} 個未下載分段)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            downloadManager.startBatchDownload(episode);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已開始批量下載「${episode.title}」所有分段'),
                                backgroundColor: AppColors.accent,
                                action: SnackBarAction(
                                  label: '查看進度',
                                  textColor: AppColors.textPrimary,
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // List of Parts with Downloaded vs Downloading vs Failed vs Idle Standoff
                    for (int i = 0; i < parts.length; i++) ...[
                      Builder(
                        builder: (partContext) {
                          final p = parts[i];
                          final isDown = downloadManager.isDownloaded(episode.id, p.label,
                              showId: showId, title: episode.title);
                          final isDl = downloadManager.isDownloading(episode.id, p.label,
                              showId: showId, title: episode.title);
                          final isFail = !isDown &&
                              !isDl &&
                              downloadManager.isFailed(episode.id, p.label,
                                  showId: showId, title: episode.title);
                          final item = downloadManager.getItem(episode.id, p.label,
                              showId: showId, title: episode.title);
                          final sizeStr = item != null && item.downloadedBytes > 0
                              ? downloadManager.formatBytes(item.downloadedBytes)
                              : '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: isDown
                                  ? AppColors.successSurface
                                  : (isDl
                                      ? AppColors.dangerSurface
                                      : (isFail ? AppColors.warningSurface : AppColors.surfaceInteractive)),
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              border: Border.all(
                                color: isDown
                                    ? AppColors.success
                                    : (isDl
                                        ? AppColors.accent
                                        : (isFail ? AppColors.warning : AppColors.borderSubtle)),
                                width: (isDown || isFail) ? 1.4 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Row 1: Part Label & Status Badge
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDown
                                            ? AppColors.success
                                            : (isFail ? AppColors.warning : AppColors.accent),
                                        borderRadius: BorderRadius.circular(AppRadius.badge),
                                      ),
                                      child: Text(
                                        p.label,
                                        style: TextStyle(
                                          color: isFail ? AppColors.canvas : AppColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),

                                    // Status Badge
                                    if (isDown)
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                                            const SizedBox(width: AppSpacing.xs),
                                            Flexible(
                                              child: Text(
                                                '已下載完成 ${sizeStr.isNotEmpty ? "($sizeStr)" : ""}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.success,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (isDl)
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                '下載中 ${item != null ? item.progressPercentage : ""}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.accent,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (isFail)
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline, size: 14, color: AppColors.warning),
                                            const SizedBox(width: AppSpacing.xs),
                                            Flexible(
                                              child: Text(
                                                '下載失敗 ${sizeStr.isNotEmpty ? "(已暫存 $sizeStr)" : ""}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: AppColors.warning,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      const Expanded(
                                        child: Text(
                                          '未下載 (支援離線播放)',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),

                                    // Action for Already Downloaded / Active / Failed
                                    if (isDown) ...[
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                                        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                        icon: const Icon(Icons.share_outlined, color: AppColors.textSecondary, size: 19),
                                        tooltip: '分享此分段影片',
                                        onPressed: () {
                                          final localFile = downloadManager.getLocalFile(
                                              episode.id, p.label,
                                              showId: showId, title: episode.title);
                                          showShareDialog(
                                            context,
                                            episode,
                                            partIndex: i,
                                            localFilePath: localFile?.path,
                                          );
                                        },
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                                        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                        icon: const Icon(Icons.play_circle_fill, color: AppColors.success, size: 24),
                                        tooltip: '播放本機離線檔案',
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          final localFile = downloadManager.getLocalFile(
                                              episode.id, p.label,
                                              showId: showId, title: episode.title);
                                          if (localFile != null) {
                                            rootNavigator.push(
                                              MaterialPageRoute(
                                                builder: (_) => NativePlayerScreen(
                                                  episode: episode,
                                                  initialPartIndex: i,
                                                  localFile: localFile,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                                        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                        icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 19),
                                        tooltip: '刪除下載檔案',
                                        onPressed: () => _confirmDeletePart(
                                          dialogContext: sheetContext,
                                          messenger: rootMessenger,
                                          downloadManager: downloadManager,
                                          episode: episode,
                                          part: p,
                                          showId: showId,
                                          isDownloading: false,
                                          isFailed: false,
                                          onDeleted: () {},
                                        ),
                                      ),
                                    ] else if (isDl || isFail) ...[
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                                        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                        icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 19),
                                        tooltip: isDl ? '取消並刪除下載' : '刪除失敗下載檔案',
                                        onPressed: () => _confirmDeletePart(
                                          dialogContext: sheetContext,
                                          messenger: rootMessenger,
                                          downloadManager: downloadManager,
                                          episode: episode,
                                          part: p,
                                          showId: showId,
                                          isDownloading: isDl,
                                          isFailed: isFail,
                                          onDeleted: () {},
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                if (isFail && item?.error != null && item!.error!.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    item.error!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      height: 1.35,
                                    ),
                                  ),
                                ],

                                // Row 2: Retry or Download Action
                                if (!isDown && !isDl) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFail ? AppColors.warning : AppColors.accent,
                                        foregroundColor: isFail ? AppColors.canvas : AppColors.textPrimary,
                                        minimumSize: const Size(0, 44),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
                                      ),
                                      icon: Icon(isFail ? Icons.refresh : Icons.download, size: 16),
                                      label: Text(
                                        isFail ? '重試下載 (${p.label})' : '下載全集 (1080p FHD)',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        _startPartDownloadWithFeedback(
                                          messenger: rootMessenger,
                                          navigator: rootNavigator,
                                          downloadManager: downloadManager,
                                          episode: episode,
                                          part: p,
                                          showId: showId,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 4),

                    // Bottom Link to Downloads Screen
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.folder_special, size: 16, color: AppColors.textSecondary),
                        label: const Text('前往下載資料夾 (Downloads)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          rootNavigator.push(
                            MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// D-Pad focusable button for Android TV and controller navigation
class TvFocusableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool autofocus;

  const TvFocusableButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.autofocus = false,
  });

  @override
  State<TvFocusableButton> createState() => _TvFocusableButtonState();
}

class _TvFocusableButtonState extends State<TvFocusableButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppDurations.focus,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          transform: _isFocused ? Matrix4.diagonal3Values(1.05, 1.05, 1.0) : Matrix4.identity(),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Unified YouTube-Style Episode Card
/// Used identically on both the Home Page feed and the Downloads Library
class YouTubeEpisodeCard extends StatelessWidget {
  final CatalogEpisode episode;
  final VoidCallback onPlayTapped;
  final Function(int) onPartTapped;
  final VoidCallback? onDeleteTapped;
  final VoidCallback? onShareTapped;
  final bool isDownloadView;

  const YouTubeEpisodeCard({
    super.key,
    required this.episode,
    required this.onPlayTapped,
    required this.onPartTapped,
    this.onDeleteTapped,
    this.onShareTapped,
    this.isDownloadView = false,
  });

  @override
  Widget build(BuildContext context) {
    final location = CatalogParser.extractLocation(episode.title);
    final showId = episode.showId.isNotEmpty
        ? episode.showId
        : CatalogParser.detectShowId('${episode.title} ${episode.id}');
    final showName = episode.showName.isNotEmpty
        ? episode.showName
        : ShowChannels.getShowName(showId);
    final showEmoji = ShowChannels.getEmoji(showId);
    final displayTitle = showName.isNotEmpty
        ? CatalogParser.stripShowNameFromTitle(episode.title, showName: showName)
        : episode.title;

    final downloadManager = DownloadManager();
    final historyManager = PlaybackHistoryManager();
    final downloadedParts = episode.parts
        .where((p) => downloadManager.isDownloaded(episode.id, p.label,
            showId: showId, title: episode.title))
        .length;
    final failedParts = episode.parts
        .where((p) => downloadManager.isFailed(episode.id, p.label,
            showId: showId, title: episode.title))
        .length;
    final isEpDone = historyManager.isEpisodeCompleted(episode.id, episode.parts.length);
    final epProgress = historyManager.getEpisodeProgress(episode.id, episode.parts.length);

    // Compute total downloaded bytes for this episode if in download view
    int totalDownloadedBytes = 0;
    for (final p in episode.parts) {
      final item = downloadManager.getItem(episode.id, p.label,
          showId: showId, title: episode.title);
      if (item != null && item.downloadedBytes > 0) {
        totalDownloadedBytes += item.downloadedBytes;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: downloadedParts > 0
              ? AppColors.success.withValues(alpha: 0.35)
              : (failedParts > 0
                  ? AppColors.warning.withValues(alpha: 0.45)
                  : AppColors.borderSubtle),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Play Indicator + Title & Clean Metadata + Uniform 44x44 Action Cluster (36x36 visual circles)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Play Icon (44x44 touch target with 36x36 visual circle matching trailing actions)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: TvFocusableButton(
                    onPressed: onPlayTapped,
                    child: Tooltip(
                      message: '播放節目',
                      child: SizedBox(
                        width: AppCardTokens.actionHitSize,
                        height: AppCardTokens.actionHitSize,
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onPlayTapped,
                            child: Center(
                              child: Container(
                                width: AppCardTokens.actionVisualSize,
                                height: AppCardTokens.actionVisualSize,
                                decoration: BoxDecoration(
                                  color: downloadedParts > 0
                                      ? AppColors.success.withValues(alpha: 0.15)
                                      : AppColors.accent.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: downloadedParts > 0
                                        ? AppColors.success.withValues(alpha: 0.5)
                                        : AppColors.accent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Icon(
                                  Icons.play_arrow,
                                  color: downloadedParts > 0 ? AppColors.success : AppColors.accent,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Title and Clean Subtitle
                Expanded(
                  child: TvFocusableButton(
                    onPressed: onPlayTapped,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tooltip(
                          message: episode.title,
                          child: Text(
                            displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              episode.date,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            if (showName.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.badge),
                                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '$showEmoji $showName',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (location.isNotEmpty) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 12, color: AppColors.accent),
                                  const SizedBox(width: 2),
                                  Text(
                                    location,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(AppRadius.badge),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: const Text(
                                '1080p FHD',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isEpDone) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.badge),
                                  border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, size: 10, color: AppColors.success),
                                    SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        '已看完',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (downloadedParts > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.badge),
                                  border: Border.all(color: AppColors.success.withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, size: 10, color: AppColors.success),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        isDownloadView && totalDownloadedBytes > 0
                                            ? '已儲存 ${downloadManager.formatBytes(totalDownloadedBytes)}'
                                            : '已載 $downloadedParts/${episode.parts.length}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.bold,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (failedParts > 0) ...[
                              GestureDetector(
                                onTap: () => showDownloadSelectionSheet(context, episode, downloadManager),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningSurface,
                                    borderRadius: BorderRadius.circular(AppRadius.badge),
                                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.7)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline, size: 10, color: AppColors.warning),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          '下載失敗 $failedParts • 點擊重試',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.warning,
                                            fontWeight: FontWeight.bold,
                                            fontFeatures: [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.xs),

                // Uniformly aligned trailing action cluster (44x44 touch boxes, 36x36 visual circles)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Favorite Button (Save to Favorites / Watch Later)
                    ListenableBuilder(
                      listenable: FavoritesManager(),
                      builder: (context, _) {
                        final favManager = FavoritesManager();
                        final isFav = favManager.isFavorite(episode.id);
                        return _buildCardActionButton(
                          icon: isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? AppColors.accent : AppColors.textSecondary,
                          tooltip: isFav ? '已收藏 (點擊取消)' : '加入收藏',
                          animateIconSwap: true,
                          onPressed: () async {
                            final added = await favManager.toggleFavorite(episode);
                            HapticFeedback.lightImpact();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).removeCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(added ? '已加入收藏清單' : '已從收藏清單移除'),
                                  duration: const Duration(milliseconds: 1200),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),

                    // Share Button (Available in both Home Feed and Downloads View)
                    if (onShareTapped != null)
                      _buildCardActionButton(
                        icon: Icons.share_outlined,
                        color: AppColors.textSecondary,
                        tooltip: '分享此集影片',
                        onPressed: onShareTapped!,
                      ),

                    // Delete Button for Downloads View
                    if (isDownloadView && onDeleteTapped != null)
                      _buildCardActionButton(
                        icon: Icons.delete_outline,
                        color: Colors.white38,
                        tooltip: '刪除此集離線檔案',
                        onPressed: onDeleteTapped!,
                      ),

                    // Triple-Ring Concentric Circular Progress Download Button (Part 1, Part 2, Part 3)
                    TripleCircleDownloadButton(
                      episode: episode,
                      downloadManager: downloadManager,
                      onTap: () => showDownloadSelectionSheet(context, episode, downloadManager),
                    ),
                  ],
                ),
              ],
            ),

            // Bottom: Chapter / Part Quick Selectors (Part 1, Part 2, Part 3)
            if (episode.parts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: List.generate(episode.parts.length, (idx) {
                  final p = episode.parts[idx];
                  final isPartDown = downloadManager.isDownloaded(episode.id, p.label,
                      showId: showId, title: episode.title);
                  final isPartDownloading = downloadManager.isDownloading(episode.id, p.label,
                      showId: showId, title: episode.title);
                  final isPartFailed = !isPartDown &&
                      !isPartDownloading &&
                      downloadManager.isFailed(episode.id, p.label,
                          showId: showId, title: episode.title);
                  final item = downloadManager.getItem(episode.id, p.label,
                      showId: showId, title: episode.title);
                  final partRec = historyManager.getRecord(episode.id, p.label);
                  final isPartWatched = partRec != null && partRec.isCompleted;
                  final inProgressWatched = partRec != null && !partRec.isCompleted && partRec.progress > 0.05;

                  String chipLabel = p.label;
                  if (isPartDown) {
                    chipLabel = '${p.label} (已下載)';
                  } else if (isPartDownloading && item != null) {
                    chipLabel = '${p.label} ${(item.progress * 100).toInt()}%';
                  } else if (isPartFailed) {
                    chipLabel = '${p.label} (失敗)';
                  } else if (isPartWatched) {
                    chipLabel = '${p.label} ✓';
                  } else if (inProgressWatched) {
                    chipLabel = '${p.label} (${(partRec.progress * 100).toInt()}%)';
                  }

                  return GestureDetector(
                    onLongPress: () => showDownloadSelectionSheet(context, episode, downloadManager),
                    child: TvFocusableButton(
                      onPressed: isPartFailed && isDownloadView
                          ? () => showDownloadSelectionSheet(context, episode, downloadManager)
                          : () => onPartTapped(idx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isPartDown
                              ? AppColors.successSurface
                              : (isPartDownloading
                                  ? AppColors.dangerSurface
                                  : (isPartFailed
                                      ? AppColors.warningSurface
                                      : (isPartWatched ? AppColors.successMutedSurface : AppColors.surfaceInteractive))),
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          border: Border.all(
                            color: isPartDown
                                ? AppColors.success
                                : (isPartDownloading
                                    ? AppColors.accent
                                    : (isPartFailed
                                        ? AppColors.warning
                                        : (isPartWatched ? AppColors.success.withValues(alpha: 0.6) : AppColors.borderSubtle))),
                            width: (isPartDown || isPartFailed) ? 1.4 : 1.0,
                          ),
                          boxShadow: isPartDown
                              ? [
                                  BoxShadow(
                                    color: AppColors.success.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    spreadRadius: 0.5,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPartDownloading)
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent),
                              )
                            else
                              Icon(
                                isPartDown
                                    ? Icons.check_circle
                                    : (isPartFailed
                                        ? Icons.error_outline
                                        : (isPartWatched ? Icons.check : Icons.play_arrow)),
                                size: 12,
                                color: isPartDown
                                    ? AppColors.success
                                    : (isPartFailed
                                        ? AppColors.warning
                                        : (isPartWatched ? AppColors.success : AppColors.accent)),
                              ),
                            const SizedBox(width: 4),
                            Text(
                              chipLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: isPartDown
                                    ? AppColors.success
                                    : (isPartFailed
                                        ? AppColors.warning
                                        : (isPartWatched ? AppColors.success : AppColors.textPrimary)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],

            // Watch History Overall Progress Bar (YouTube/Netflix style)
            if (epProgress > 0.02) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: epProgress,
                  minHeight: 2.5,
                  color: AppColors.accent,
                  backgroundColor: AppColors.borderSubtle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
    bool animateIconSwap = false,
  }) {
    final iconWidget = Icon(
      icon,
      key: animateIconSwap ? ValueKey(icon) : null,
      color: color,
      size: AppCardTokens.actionIconSize,
    );

    return SizedBox(
      width: AppCardTokens.actionHitSize,
      height: AppCardTokens.actionHitSize,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(
          width: AppCardTokens.actionHitSize,
          height: AppCardTokens.actionHitSize,
        ),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const CircleBorder(),
        ),
        icon: Container(
          width: AppCardTokens.actionVisualSize,
          height: AppCardTokens.actionVisualSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.actionCircleBg,
            shape: BoxShape.circle,
          ),
          child: animateIconSwap
              ? AnimatedSwitcher(
                  duration: AppDurations.fast,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  child: iconWidget,
                )
              : iconWidget,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
