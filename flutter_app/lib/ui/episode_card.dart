import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../catalog/parser.dart';
import '../catalog/show_channel.dart';
import '../services/download_manager.dart';
import '../services/playback_history_manager.dart';
import 'downloads_screen.dart';
import 'player_screen.dart';

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

    for (int i = 0; i < totalParts; i++) {
      if (i < parts.length) {
        final p = parts[i];
        final isDown = downloadManager.isDownloaded(episode.id, p.label,
            showId: episode.showId, title: episode.title);
        final isDl = downloadManager.isDownloading(episode.id, p.label,
            showId: episode.showId, title: episode.title);
        final item = downloadManager.getItem(episode.id, p.label,
            showId: episode.showId, title: episode.title);

        isDownloadedList.add(isDown);
        isDownloadingList.add(isDl);
        progresses.add(isDown ? 1.0 : (isDl && item != null ? item.progress : 0.0));
      } else {
        isDownloadedList.add(false);
        isDownloadingList.add(false);
        progresses.add(0.0);
      }
    }

    final allDownloaded = isDownloadedList.isNotEmpty && isDownloadedList.every((d) => d);
    final anyDownloading = isDownloadingList.any((d) => d);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Tooltip(
        message: allDownloaded
            ? '已下載全部分段 (點擊管理)'
            : (anyDownloading ? '分段下載中 (點擊查看)' : '下載此集分段'),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            shape: BoxShape.circle,
          ),
          child: CustomPaint(
            size: const Size(30, 30),
            painter: TripleRingPainter(
              progresses: progresses,
              isDownloading: isDownloadingList,
              isDownloaded: isDownloadedList,
              allDownloaded: allDownloaded,
              anyDownloading: anyDownloading,
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
  final bool allDownloaded;
  final bool anyDownloading;

  TripleRingPainter({
    required this.progresses,
    required this.isDownloading,
    required this.isDownloaded,
    required this.allDownloaded,
    required this.anyDownloading,
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
      final progress = i < progresses.length ? progresses[i] : 0.0;

      // 1. Background arc track for this pie piece
      final bgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth
        ..color = isDown
            ? const Color(0xFF46D369).withValues(alpha: 0.25)
            : (isDl
                ? const Color(0xFFE50914).withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.20));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        partStart,
        arcLength,
        false,
        bgPaint,
      );

      // 2. Completed / Downloading arc for this pie piece
      if (isDown) {
        final fgPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth
          ..color = const Color(0xFF46D369);

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          partStart,
          arcLength,
          false,
          fgPaint,
        );
      } else if (isDl && progress > 0.0) {
        final fgPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth
          ..color = const Color(0xFFE50914);

        final fillSweep = math.max(arcLength * 0.12, arcLength * progress);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          partStart,
          fillSweep,
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
        ..color = const Color(0xFF46D369)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.8;
      canvas.drawLine(p1, p2, checkPaint);
      canvas.drawLine(p2, p3, checkPaint);
    } else {
      // Crisp Download Arrow & Tray
      final arrowColor = anyDownloading ? const Color(0xFFE50914) : Colors.white70;
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
  bool shouldRepaint(covariant TripleRingPainter oldDelegate) => true;
}

/// Download Part Selection Modal Sheet
void showDownloadSelectionSheet(
  BuildContext context,
  CatalogEpisode episode,
  DownloadManager downloadManager,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
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
            top: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, (bottomInset + 16.0) / 2),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.download_for_offline, color: Color(0xFFE50914), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showName.isNotEmpty) ...[
                                Text(
                                  '$showEmoji $showName',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFE50914),
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
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                allDone
                                    ? '已下載全部分段 (${parts.length}/${parts.length}) • 可離線觀看'
                                    : '已下載 $downloadedCount/${parts.length} 個分段 • 點擊選擇分段下載',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: allDone ? const Color(0xFF46D369) : Colors.white60,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 12),

                    // One-tap Batch Download All Parts Button
                    if (!allDone) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                backgroundColor: const Color(0xFFE50914),
                                action: SnackBarAction(
                                  label: '查看進度',
                                  textColor: Colors.white,
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // List of Parts with Downloaded vs Not-Downloaded Standoff
                    for (int i = 0; i < parts.length; i++) ...[
                      Builder(
                        builder: (partContext) {
                          final p = parts[i];
                          final isDown = downloadManager.isDownloaded(episode.id, p.label,
                              showId: showId, title: episode.title);
                          final isDl = downloadManager.isDownloading(episode.id, p.label,
                              showId: showId, title: episode.title);
                          final item = downloadManager.getItem(episode.id, p.label,
                              showId: showId, title: episode.title);
                          final sizeStr = item != null && item.downloadedBytes > 0
                              ? downloadManager.formatBytes(item.downloadedBytes)
                              : '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDown
                                  ? const Color(0xFF13381B)
                                  : (isDl ? const Color(0xFF331111) : const Color(0xFF262626)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDown
                                    ? const Color(0xFF46D369)
                                    : (isDl ? const Color(0xFFE50914) : Colors.white12),
                                width: isDown ? 1.4 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Row 1: Part Label & Status Badge
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDown ? const Color(0xFF46D369) : const Color(0xFFE50914),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        p.label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Status Badge
                                    if (isDown)
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle, size: 14, color: Color(0xFF46D369)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '已下載完成 ${sizeStr.isNotEmpty ? "($sizeStr)" : ""}',
                                            style: const TextStyle(
                                              color: Color(0xFF46D369),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      )
                                    else if (isDl)
                                      Row(
                                        children: [
                                          const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE50914)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '下載中 ${item != null ? item.progressPercentage : ""}',
                                            style: const TextStyle(
                                              color: Color(0xFFE50914),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      const Text(
                                        '未下載 (支援離線播放)',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),

                                    const Spacer(),

                                    // Action for Already Downloaded: Play or Delete
                                    if (isDown) ...[
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: const Icon(Icons.play_circle_fill, color: Color(0xFF46D369), size: 26),
                                        tooltip: '播放本機離線檔案',
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          final localFile = downloadManager.getLocalFile(
                                              episode.id, p.label,
                                              showId: showId, title: episode.title);
                                          if (localFile != null) {
                                            Navigator.of(context).push(
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
                                      const SizedBox(width: 4),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                                        tooltip: '刪除下載檔案',
                                        onPressed: () {
                                          downloadManager.deleteDownload(
                                              episode.id, p.label,
                                              showId: showId, title: episode.title);
                                          setSheetState(() {});
                                        },
                                      ),
                                    ],
                                  ],
                                ),

                                // Row 2: Single Full 1080p Download Option (No 快速版)
                                if (!isDown && !isDl) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE50914),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      icon: const Icon(Icons.download, size: 16),
                                      label: const Text('下載全集 (1080p FHD)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        downloadManager.startDownload(episode, p);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('已開始下載 ${episode.title} - ${p.label}'),
                                            backgroundColor: const Color(0xFFE50914),
                                            action: SnackBarAction(
                                              label: '查看進度',
                                              textColor: Colors.white,
                                              onPressed: () => Navigator.of(context).push(
                                                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                                              ),
                                            ),
                                          ),
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
                        icon: const Icon(Icons.folder_special, size: 16, color: Colors.white70),
                        label: const Text('前往下載資料夾 (Downloads)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
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
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFE50914).withValues(alpha: 0.5),
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
  final bool isDownloadView;

  const YouTubeEpisodeCard({
    super.key,
    required this.episode,
    required this.onPlayTapped,
    required this.onPartTapped,
    this.onDeleteTapped,
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

    final downloadManager = DownloadManager();
    final historyManager = PlaybackHistoryManager();
    final downloadedParts = episode.parts
        .where((p) => downloadManager.isDownloaded(episode.id, p.label,
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
      margin: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: downloadedParts > 0
              ? const Color(0xFF46D369).withValues(alpha: 0.35)
              : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Play Indicator + Title & Clean Metadata + Download & Delete Buttons
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Play Icon
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPlayTapped,
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(top: 2, right: 10),
                    decoration: BoxDecoration(
                      color: downloadedParts > 0
                          ? const Color(0xFF46D369).withValues(alpha: 0.15)
                          : const Color(0xFFE50914).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: downloadedParts > 0
                            ? const Color(0xFF46D369).withValues(alpha: 0.5)
                            : const Color(0xFFE50914).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      downloadedParts > 0 ? Icons.play_arrow : Icons.play_arrow,
                      color: downloadedParts > 0 ? const Color(0xFF46D369) : const Color(0xFFE50914),
                      size: 20,
                    ),
                  ),
                ),

                // Title and Clean Subtitle
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onPlayTapped,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              episode.date,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (showName.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE50914).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '$showEmoji $showName',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            if (location.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '📍 $location',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFE50914),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Text(
                                '1080p FHD',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isEpDone) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF46D369).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: const Color(0xFF46D369).withValues(alpha: 0.5)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, size: 10, color: Color(0xFF46D369)),
                                    SizedBox(width: 2),
                                    Text(
                                      '已看完',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF46D369),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (downloadedParts > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF46D369).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: const Color(0xFF46D369).withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, size: 10, color: Color(0xFF46D369)),
                                    const SizedBox(width: 3),
                                    Text(
                                      isDownloadView && totalDownloadedBytes > 0
                                          ? '已儲存 ${downloadManager.formatBytes(totalDownloadedBytes)}'
                                          : '已載 $downloadedParts/${episode.parts.length}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF46D369),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Delete Button for Downloads View
                if (isDownloadView && onDeleteTapped != null) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                    tooltip: '刪除此集離線檔案',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: onDeleteTapped,
                  ),
                  const SizedBox(width: 4),
                ],

                // Triple-Ring Concentric Circular Progress Download Button (Part 1, Part 2, Part 3)
                TripleCircleDownloadButton(
                  episode: episode,
                  downloadManager: downloadManager,
                  onTap: () => showDownloadSelectionSheet(context, episode, downloadManager),
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
                  } else if (isPartWatched) {
                    chipLabel = '${p.label} ✓';
                  } else if (inProgressWatched) {
                    chipLabel = '${p.label} (${(partRec.progress * 100).toInt()}%)';
                  }

                  return GestureDetector(
                    onLongPress: () => showDownloadSelectionSheet(context, episode, downloadManager),
                    child: TvFocusableButton(
                      onPressed: () => onPartTapped(idx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isPartDown
                              ? const Color(0xFF13381B)
                              : (isPartDownloading
                                  ? const Color(0xFF331111)
                                  : (isPartWatched ? const Color(0xFF1F2E22) : const Color(0xFF262626))),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isPartDown
                                ? const Color(0xFF46D369)
                                : (isPartDownloading
                                    ? const Color(0xFFE50914)
                                    : (isPartWatched ? const Color(0xFF46D369).withValues(alpha: 0.6) : Colors.white12)),
                            width: isPartDown ? 1.4 : 1.0,
                          ),
                          boxShadow: isPartDown
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF46D369).withValues(alpha: 0.3),
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
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFE50914)),
                              )
                            else
                              Icon(
                                isPartDown ? Icons.check_circle : (isPartWatched ? Icons.check : Icons.play_arrow),
                                size: 12,
                                color: isPartDown
                                    ? const Color(0xFF46D369)
                                    : (isPartWatched ? const Color(0xFF46D369) : const Color(0xFFE50914)),
                              ),
                            const SizedBox(width: 4),
                            Text(
                              chipLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPartDown ? const Color(0xFF46D369) : (isPartWatched ? const Color(0xFF46D369) : Colors.white),
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
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: epProgress,
                  minHeight: 2.5,
                  color: const Color(0xFFE50914),
                  backgroundColor: Colors.white12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
