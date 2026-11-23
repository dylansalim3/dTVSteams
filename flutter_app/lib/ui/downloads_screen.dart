import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../catalog/parser.dart';
import '../services/download_manager.dart';
import 'episode_card.dart';
import 'player_screen.dart';
import 'storage_location_sheet.dart';

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

  void _playEpisode(CatalogEpisode ep, int partIndex) {
    final part = ep.parts.isNotEmpty && partIndex < ep.parts.length
        ? ep.parts[partIndex]
        : (ep.parts.isNotEmpty ? ep.parts.first : CatalogPart(label: 'Part 1', url: ep.url));

    final localFile = _manager.getLocalFile(ep.id, part.label, showId: ep.showId, title: ep.title);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NativePlayerScreen(
          episode: ep,
          initialPartIndex: partIndex,
          localFile: localFile,
        ),
      ),
    );
  }

  void _confirmDeleteEpisode(CatalogEpisode ep) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('刪除此集離線檔案', style: TextStyle(color: Colors.white)),
        content: Text(
          '確定要刪除「${ep.title}」的所有已下載分段檔案嗎？',
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
              for (final p in ep.parts) {
                if (_manager.isDownloaded(ep.id, p.label, showId: ep.showId, title: ep.title)) {
                  _manager.deleteDownload(ep.id, p.label, showId: ep.showId, title: ep.title);
                }
              }
              if (mounted) setState(() {});
            },
            child: const Text('刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<CatalogEpisode> get downloadedEpisodes {
    final Map<String, List<DownloadItem>> grouped = {};
    for (final item in [..._manager.completedDownloads, ..._manager.activeDownloads, ..._manager.failedDownloads]) {
      grouped.putIfAbsent(item.episodeId, () => []).add(item);
    }

    final episodes = <CatalogEpisode>[];
    for (final entry in grouped.entries) {
      final items = entry.value;
      if (items.isEmpty) continue;
      final first = items.first;

      final partsMap = <String, CatalogPart>{};
      for (final it in items) {
        partsMap[it.partLabel] = CatalogPart(label: it.partLabel, url: it.partUrl);
      }

      final parts = <CatalogPart>[];
      final maxParts = math.max(3, partsMap.length);
      for (int i = 1; i <= maxParts; i++) {
        final label = 'Part $i';
        if (partsMap.containsKey(label)) {
          parts.add(partsMap[label]!);
        } else {
          parts.add(CatalogPart(label: label, url: first.partUrl));
        }
      }

      final showId = first.showId.isNotEmpty
          ? first.showId
          : CatalogParser.detectShowId('${first.episodeTitle} ${first.episodeId}');
      final showName = first.showName.isNotEmpty
          ? first.showName
          : CatalogParser.detectShowName('${first.episodeTitle} ${first.episodeId} $showId');

      episodes.add(CatalogEpisode(
        id: entry.key,
        title: first.episodeTitle,
        date: first.date,
        url: first.partUrl,
        showId: showId,
        showName: showName,
        overview: '本機離線影片',
        parts: parts,
      ));
    }

    // Sort descending by date!
    episodes.sort(CatalogParser.compareDateDescending);
    return episodes;
  }

  @override
  Widget build(BuildContext context) {
    final completedList = _manager.completedDownloads;
    final activeList = _manager.activeDownloads;
    final totalSize = _manager.formatBytes(_manager.totalDownloadedBytes);
    final folderPath = _manager.downloadDirectoryPath;
    final episodes = downloadedEpisodes;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        elevation: 0,
        title: const Text(
          '下載資料夾 (Downloads)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_file_move_outlined, color: Colors.white70),
            tooltip: '變更下載儲存位置',
            onPressed: () => StorageLocationHelper.showStoragePickerSheet(
              context,
              onStorageChanged: () {
                if (mounted) setState(() {});
              },
            ),
          ),
          if (completedList.isNotEmpty || activeList.isNotEmpty)
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
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已清空所有下載檔案，釋出 $totalSize 儲存空間')),
                          );
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
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(14),
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
                        child: const Icon(Icons.storage, color: Color(0xFFE50914), size: 22),
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
                              '$totalSize • ${episodes.length} 部節目${activeList.isNotEmpty ? " (${activeList.length} 個分段下載中)" : ""}',
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
                  const SizedBox(height: 10),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),
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
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_manager.isUsingCustomDirectory) ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => StorageLocationHelper.handleResetStorage(
                            context,
                            onStorageChanged: () {
                              if (mounted) setState(() {});
                            },
                          ),
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
                        onPressed: () => StorageLocationHelper.showStoragePickerSheet(
                          context,
                          onStorageChanged: () {
                            if (mounted) setState(() {});
                          },
                        ),
                        icon: const Icon(Icons.drive_file_move_outlined, size: 14),
                        label: const Text('變更位置', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Header for Downloaded List
          if (episodes.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF46D369)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '已下載節目清單 (${episodes.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Empty State
          if (episodes.isEmpty)
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
          else
            // Episode Cards (Identical layout to Home Screen)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final ep = episodes[index];
                  return YouTubeEpisodeCard(
                    episode: ep,
                    isDownloadView: true,
                    onPlayTapped: () => _playEpisode(ep, 0),
                    onPartTapped: (partIdx) => _playEpisode(ep, partIdx),
                    onDeleteTapped: () => _confirmDeleteEpisode(ep),
                  );
                },
                childCount: episodes.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
