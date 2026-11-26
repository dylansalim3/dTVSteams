import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../catalog/parser.dart';
import '../services/playback_history_manager.dart';
import 'app_tokens.dart';
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.normalOverlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
        backgroundColor: AppColors.surfaceSecondary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: AppColors.borderSeparator, height: 1),
        ),
        title: Row(
          children: [
            Icon(Icons.history, color: AppColors.accent, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text('觀看紀錄', style: AppType.title3Semibold),
            if (records.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfacePrimary,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '${records.length}',
                  style: AppType.caption1Semibold.copyWith(
                    color: AppColors.textSecondary,
                    fontFeatures: AppType.tabular,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (records.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: AppColors.textSecondary),
              tooltip: '清空歷史紀錄',
              onPressed: () => HistoryBody.confirmClearAll(context, _historyManager),
            ),
        ],
      ),
      body: const SafeArea(
        top: false,
        child: HistoryBody(),
      ),
    ),
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
        backgroundColor: AppColors.surfaceOverlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.modal)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Text('清空所有歷史紀錄？', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          ],
        ),
        content: Text(
          '確定要清空所有的觀看紀錄嗎？此操作將清除所有集數的播放進度與暫存時間戳。',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceInteractive,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent),
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
            child: const Text('確認清空'),
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderSeparator),
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                size: 28,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('尚無觀看歷史紀錄', style: AppType.title3Semibold),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '您播放過的任何精彩節目與分段都會自動記錄在這裡，隨時隨地一鍵續播。',
              textAlign: TextAlign.center,
              style: AppType.body2Medium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                elevation: 0,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
              ),
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: Text('開始探索節目', style: AppType.bodyMedium.copyWith(color: AppColors.onAccent)),
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
              padding: const EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.md, bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    groupName,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '(${groups[groupName]!.length})',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: AppColors.onAccent, size: 24),
            const SizedBox(width: 6),
            Text(
              '刪除',
              style: TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.bold),
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
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        color: AppColors.surfaceSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: AppColors.borderSeparator, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _playHistoryRecord(record),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail with progress indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: Container(
                    width: 104,
                    height: 62,
                    color: AppColors.surfaceInteractive,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasThumbnail)
                          Image.network(
                            record.effectiveThumbnail,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return Container(color: AppColors.surfaceInteractive);
                            },
                            errorBuilder: (ctx, err, stack) => Center(
                              child: Icon(Icons.movie_creation_outlined, color: AppColors.textTertiary, size: 30),
                            ),
                          )
                        else
                          Center(
                            child: Icon(Icons.movie_creation_outlined, color: AppColors.textTertiary, size: 30),
                          ),

                        // Completed status badge
                        if (record.isCompleted)
                          Positioned(
                            top: AppSpacing.xs,
                            left: AppSpacing.xs,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.successSurface,
                                borderRadius: BorderRadius.circular(AppRadius.badge),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.7)),
                              ),
                              child: Text(
                                '✓ 已看完',
                                style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.bold),
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
                              color: Colors.black.withValues(alpha: 0.6),
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
                              child: Container(color: AppColors.accent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

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
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            _formatRelativeDate(record.updatedAt),
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      // Episode Title
                      Tooltip(
                        message: record.effectiveTitle,
                        child: Text(
                          record.effectiveShowName.isNotEmpty
                              ? CatalogParser.stripShowNameFromTitle(
                                  record.effectiveTitle,
                                  showName: record.effectiveShowName,
                                )
                              : record.effectiveTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Part badge + Time & progress
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceInteractive,
                              borderRadius: BorderRadius.circular(AppRadius.badge),
                              border: Border.all(color: AppColors.borderSubtle, width: 0.8),
                            ),
                            child: Text(
                              record.partLabel,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '${record.positionFormatted} / ${record.durationFormatted} ($progressPct%)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Direct Delete Button (44x44 hit box, 36x36 visual slot)
                IconButton(
                  icon: Container(
                    width: AppCardTokens.actionVisualSize,
                    height: AppCardTokens.actionVisualSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.actionCircleBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, color: AppColors.textTertiary, size: AppCardTokens.actionIconSize),
                  ),
                  tooltip: '刪除紀錄',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: AppCardTokens.actionHitSize,
                    height: AppCardTokens.actionHitSize,
                  ),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: const CircleBorder(),
                  ),
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
