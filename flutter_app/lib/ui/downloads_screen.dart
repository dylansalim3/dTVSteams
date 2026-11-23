import 'dart:io';
import 'package:flutter/material.dart';
import '../catalog/parser.dart';
import '../services/download_manager.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final DownloadManager _manager = DownloadManager();

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onManagerUpdate);
    _manager.init();
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerUpdate);
    super.dispose();
  }

  void _onManagerUpdate() {
    if (mounted) setState(() {});
  }

  void _playLocalDownload(DownloadItem item) {
    final file = File(item.localFilePath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下載檔案不存在，可能已被外部清理')),
      );
      return;
    }

    final dummyEpisode = CatalogEpisode(
      id: item.episodeId,
      title: item.episodeTitle,
      date: item.date,
      url: item.partUrl,
      overview: '本地離線播放檔案：${item.partLabel}',
      backdrop: '',
      poster: '',
      match: 100,
      rating: '離線下載',
      duration: _manager.formatBytes(item.downloadedBytes),
      category: 'download',
      tags: ['離線', '本機檔案'],
      parts: [
        CatalogPart(label: item.partLabel, url: item.partUrl),
      ],
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NativePlayerScreen(
          episode: dummyEpisode,
          initialPartIndex: 0,
          localFile: file,
        ),
      ),
    );
  }

  void _confirmDelete(DownloadItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('刪除下載檔案', style: TextStyle(color: Colors.white)),
        content: Text(
          '確定要刪除「${item.episodeTitle} - ${item.partLabel}」嗎？\n將釋出 ${_manager.formatBytes(item.downloadedBytes)} 儲存空間。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
            onPressed: () {
              Navigator.of(ctx).pop();
              _manager.deleteDownload(item.episodeId, item.partLabel);
            },
            child: const Text('刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _resumeDownload(DownloadItem item) {
    final ep = CatalogEpisode(
      id: item.episodeId,
      title: item.episodeTitle,
      date: item.date,
      url: item.partUrl,
      parts: [
        CatalogPart(label: item.partLabel, url: item.partUrl),
      ],
    );
    _manager.startDownload(ep, ep.parts.first);
  }

  @override
  Widget build(BuildContext context) {
    final activeList = _manager.activeDownloads;
    final failedList = _manager.failedDownloads;
    final completedList = _manager.completedDownloads;
    final totalSize = _manager.formatBytes(_manager.totalDownloadedBytes);
    final folderPath = _manager.downloadDirectoryPath;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.folder_special, color: Color(0xFFE50914), size: 22),
            SizedBox(width: 8),
            Text(
              '下載資料夾 (Downloads)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: '重新整理並掃描磁碟',
            onPressed: () async {
              await _manager.refreshDisk();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已掃描本地下載目錄')),
                );
              }
            },
          ),
          if (completedList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white70),
              tooltip: '清空所有下載檔案',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: const Text('清空所有下載檔案', style: TextStyle(color: Colors.white)),
                    content: Text(
                      '確定要刪除所有 ${completedList.length} 個已下載分段檔案嗎？\n將釋出 $totalSize 儲存空間。',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('取消', style: TextStyle(color: Colors.white54)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _manager.deleteAllDownloads();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已清空所有下載檔案，釋出 $totalSize 儲存空間')),
                            );
                          }
                        },
                        child: const Text('全部清空', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Storage Summary Card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
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
                        child: const Icon(Icons.storage, color: Color(0xFFE50914), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '本機離線空間',
                              style: TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalSize • ${completedList.length} 個分段檔案' +
                                  (activeList.isNotEmpty ? ' (${activeList.length} 個下載中)' : ''),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.folder_open, size: 14, color: Colors.white54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          folderPath.isNotEmpty ? folderPath : '正在載入儲存路徑...',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white54,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 1. ACTIVE DOWNLOADS SECTION (Real-time progress bars)
          if (activeList.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE50914),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '正在下載中 (${activeList.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE50914),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = activeList[index];
                  final pctStr = item.progressPercentage;
                  final downloadedStr = _manager.formatBytes(item.downloadedBytes);
                  final totalStr = item.totalBytes > 0 ? _manager.formatBytes(item.totalBytes) : '未知大小';
                  final speedStr = _manager.formatSpeed(item.speedBytesPerSec);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.partLabel,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.episodeTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.pause_circle_outline, color: Colors.white70, size: 24),
                              tooltip: '暫停下載',
                              onPressed: () => _manager.cancelDownload(item.episodeId, item.partLabel),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Live Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.progress > 0 ? item.progress : null,
                            minHeight: 6,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$pctStr ($downloadedStr / $totalStr)',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Row(
                              children: [
                                Text(
                                  speedStr,
                                  style: const TextStyle(
                                    color: Color(0xFF46D369),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (item.etaString.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '• ${item.etaString}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (item.downloadedBytes > 1024 * 1024)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE50914),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.play_arrow, size: 16),
                                label: const Text('邊載邊播 (立即看)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _playLocalDownload(item),
                              ),
                            const SizedBox(width: 8),
                            if (item.downloadedBytes > 1024 * 1024)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF46D369),
                                  side: const BorderSide(color: Color(0xFF46D369)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.check, size: 14),
                                label: const Text('完成下載 (轉為離線檔)', style: TextStyle(fontSize: 11)),
                                onPressed: () => _manager.finalizeDownload(item.episodeId, item.partLabel),
                              ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.pause_circle_outline, color: Colors.white70, size: 22),
                              tooltip: '暫停下載',
                              onPressed: () => _manager.cancelDownload(item.episodeId, item.partLabel),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                childCount: activeList.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],

          // 2. PAUSED / INTERRUPTED DOWNLOADS SECTION
          if (failedList.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFFF9800)),
                    const SizedBox(width: 6),
                    Text(
                      '下載中斷或暫停 (${failedList.length})',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF9800)),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = failedList[index];
                  final downloadedStr = _manager.formatBytes(item.downloadedBytes);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_download_outlined, color: Color(0xFFFF9800), size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.episodeTitle} - ${item.partLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '已下載 $downloadedStr • 點擊右側按鈕繼續斷點續傳',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        if (item.downloadedBytes > 1024 * 1024)
                          IconButton(
                            icon: const Icon(Icons.play_arrow, color: Color(0xFFE50914), size: 24),
                            tooltip: '播放已下載內容',
                            onPressed: () => _playLocalDownload(item),
                          ),
                        if (item.downloadedBytes > 1024 * 1024)
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: Color(0xFF46D369), size: 22),
                            tooltip: '轉為完成離線檔',
                            onPressed: () => _manager.finalizeDownload(item.episodeId, item.partLabel),
                          ),
                        IconButton(
                          icon: const Icon(Icons.cloud_download, color: Colors.white70, size: 24),
                          tooltip: '繼續下載 (斷點續傳)',
                          onPressed: () => _resumeDownload(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                          tooltip: '刪除',
                          onPressed: () => _manager.deleteDownload(item.episodeId, item.partLabel),
                        ),
                      ],
                    ),
                  );
                },
                childCount: failedList.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],

          // 3. COMPLETED DOWNLOADS SECTION
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF46D369)),
                  const SizedBox(width: 6),
                  Text(
                    '已完成下載 (${completedList.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          if (completedList.isEmpty && activeList.isEmpty && failedList.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_for_offline_outlined, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    const Text(
                      '尚無已下載的離線影片',
                      style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        '在首頁或播放器中點擊「下載」按鈕，即可將節目儲存至本機資料夾隨時離線觀看。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (completedList.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    '尚無已完成的離線影片，下載完成後將自動儲存於此。',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = completedList[index];
                  final sizeStr = _manager.formatBytes(item.downloadedBytes);
                  final location = CatalogParser.extractLocation(item.episodeTitle);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF46D369).withValues(alpha: 0.35)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _playLocalDownload(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Badges & Actions Row (No left play icon)
                              Row(
                                children: [
                                  // Prominent Part Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE50914),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFE50914).withValues(alpha: 0.4),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      item.partLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Offline Ready Green Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF46D369).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF46D369).withValues(alpha: 0.6)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, size: 12, color: Color(0xFF46D369)),
                                        SizedBox(width: 4),
                                        Text(
                                          '已下載離線',
                                          style: TextStyle(
                                            color: Color(0xFF46D369),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // 1080p FHD Quality Tag
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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

                                  const Spacer(),

                                  // Play Action Button
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE50914),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.play_arrow, size: 16),
                                    label: const Text(
                                      '播放',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () => _playLocalDownload(item),
                                  ),
                                  const SizedBox(width: 6),

                                  // Delete Button
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                                    tooltip: '刪除檔案',
                                    onPressed: () => _confirmDelete(item),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Episode Title: 2 lines max, legible, stands out
                              Text(
                                item.episodeTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.white,
                                  height: 1.3,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Bottom Row: Location + Date + File Size
                              Row(
                                children: [
                                  if (location.isNotEmpty) ...[
                                    Text(
                                      '📍 $location',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFE50914),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  if (item.date.isNotEmpty) ...[
                                    Text(
                                      '📅 ${item.date}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Text(
                                    '💾 $sizeStr',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: completedList.length,
              ),
            ),
        ],
      ),
    );
  }
}
