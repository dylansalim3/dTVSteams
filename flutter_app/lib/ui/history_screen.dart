import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../catalog/parser.dart';
import '../services/playback_history_manager.dart';
import 'player_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final PlaybackHistoryManager _historyManager = PlaybackHistoryManager();

  @override
  void initState() {
    super.initState();
    _historyManager.addListener(_onHistoryUpdate);
    _historyManager.init();
  }

  @override
  void dispose() {
    _historyManager.removeListener(_onHistoryUpdate);
    super.dispose();
  }

  void _onHistoryUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final records = _historyManager.allRecordsSorted;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.history, color: Color(0xFFE50914), size: 22),
            const SizedBox(width: 8),
            const Text(
              '觀看紀錄',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (records.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${records.length}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
              tooltip: '清空歷史紀錄',
              onPressed: () => HistoryBody.confirmClearAll(context, _historyManager),
            ),
        ],
      ),
      body: const HistoryBody(),
    );
  }
}

/// Reusable watch-history list body embedded in [HistoryScreen] and [DownloadsScreen].
class HistoryBody extends StatefulWidget {
  const HistoryBody({super.key});

  static void confirmClearAll(BuildContext context, PlaybackHistoryManager manager) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE50914), size: 24),
            SizedBox(width: 8),
            Text('清空所有歷史紀錄？', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          '確定要清空所有的觀看紀錄嗎？此操作將清除所有集數的播放進度與暫存時間戳。',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              manager.clearAllHistory();
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已清空所有觀看歷史紀錄'),
                  duration: Duration(milliseconds: 1500),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('確認清空', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  State<HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<HistoryBody> {
  final PlaybackHistoryManager _historyManager = PlaybackHistoryManager();

  @override
  void initState() {
    super.initState();
    _historyManager.addListener(_onHistoryUpdate);
    _historyManager.init();
  }

  @override
  void dispose() {
    _historyManager.removeListener(_onHistoryUpdate);
    super.dispose();
  }

  void _onHistoryUpdate() {
    if (mounted) setState(() {});
  }

  void _playHistoryRecord(PlaybackRecord record) {
    CatalogEpisode episode;
    if (record.episode != null) {
      episode = record.episode!;
    } else {
      // Fallback CatalogEpisode
      episode = CatalogEpisode(
        id: record.episodeId,
        title: record.effectiveTitle,
        date: '',
        url: '',
        showName: record.effectiveShowName,
        backdrop: record.effectiveThumbnail,
        poster: record.effectiveThumbnail,
        parts: [
          CatalogPart(
            label: record.partLabel,
            url: '',
          ),
        ],
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NativePlayerScreen(
          episode: episode,
          initialPartIndex: record.partIndex,
        ),
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDate = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(recordDate).inDays;

    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (diffDays == 0) {
      return '今天 $timeStr';
    } else if (diffDays == 1) {
      return '昨天 $timeStr';
    } else if (diffDays < 7) {
      return '$diffDays 天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  Map<String, List<PlaybackRecord>> _groupRecordsByDate(List<PlaybackRecord> records) {
    final Map<String, List<PlaybackRecord>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final rec in records) {
      final recDate = DateTime(rec.updatedAt.year, rec.updatedAt.month, rec.updatedAt.day);
      final diff = today.difference(recDate).inDays;

      String groupKey;
      if (diff == 0) {
        groupKey = '今天';
      } else if (diff == 1) {
        groupKey = '昨天';
      } else if (diff <= 7) {
        groupKey = '本週';
      } else {
        groupKey = '更早';
      }

      groups.putIfAbsent(groupKey, () => []).add(rec);
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final records = _historyManager.allRecordsSorted;
    return records.isEmpty ? _buildEmptyState() : _buildHistoryList(records);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E1E1E),
                border: Border.all(color: const Color(0xFF2E2E2E), width: 1.5),
              ),
              child: const Icon(
                Icons.history_toggle_off_rounded,
                size: 44,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '尚無觀看歷史紀錄',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '您播放過的任何精彩節目與分段都會自動記錄在這裡，隨時隨地一鍵續播。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('開始探索節目'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<PlaybackRecord> records) {
    final groups = _groupRecordsByDate(records);
    final groupOrder = ['今天', '昨天', '本週', '更早'];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      children: [
        for (final groupName in groupOrder)
          if (groups.containsKey(groupName) && groups[groupName]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    groupName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${groups[groupName]!.length})',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            for (final record in groups[groupName]!)
              _buildHistoryCard(record),
          ],
      ],
    );
  }

  Widget _buildHistoryCard(PlaybackRecord record) {
    final hasThumbnail = record.effectiveThumbnail.isNotEmpty;
    final progressPct = (record.progress * 100).toInt();

    return Dismissible(
      key: Key('${record.episodeId}_${record.partLabel}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE50914),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(width: 6),
            Text(
              '刪除',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        _historyManager.clearRecord(record.episodeId, record.partLabel);
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已刪除：${record.effectiveTitle} ${record.partLabel}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: const Color(0xFF1E1E1E),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _playHistoryRecord(record),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail with progress indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 104,
                    height: 62,
                    color: const Color(0xFF2A2A2A),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasThumbnail)
                          Image.network(
                            record.effectiveThumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const Center(
                              child: Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 30),
                            ),
                          )
                        else
                          const Center(
                            child: Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 30),
                          ),

                        // Completed status badge
                        if (record.isCompleted)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '✓ 已看完',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),

                        // Play icon overlay
                        Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.6),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),

                        // Bottom progress bar
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 3,
                            color: Colors.black54,
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: record.progress,
                              child: Container(color: const Color(0xFFE50914)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Episode Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show Name + Relative Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              record.effectiveShowName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFE50914),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatRelativeDate(record.updatedAt),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Episode Title
                      Text(
                        record.effectiveTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Part badge + Time & progress
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF3E3E3E), width: 0.8),
                            ),
                            child: Text(
                              record.partLabel,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${record.positionFormatted} / ${record.durationFormatted} ($progressPct%)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Direct Delete Button
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                  tooltip: '刪除紀錄',
                  splashRadius: 18,
                  onPressed: () {
                    _historyManager.clearRecord(record.episodeId, record.partLabel);
                    HapticFeedback.lightImpact();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
