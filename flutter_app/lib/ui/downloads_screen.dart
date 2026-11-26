import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../catalog/parser.dart';
import '../services/download_manager.dart';
import '../services/favorites_manager.dart';
import '../services/playback_history_manager.dart';
import 'app_tokens.dart';
import 'episode_card.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'player_screen.dart';
import 'share_dialog.dart';
import 'storage_location_sheet.dart';

class DownloadsScreen extends StatefulWidget {
  final int initialTabIndex;
  const DownloadsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final DownloadManager _manager = DownloadManager();
  final FavoritesManager _favoritesManager = FavoritesManager();
  final PlaybackHistoryManager _historyManager = PlaybackHistoryManager();
  late int _currentTabIndex;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex.clamp(0, 2);
    _manager.addListener(_onManagerUpdate);
    _manager.init();
    _favoritesManager.addListener(_onManagerUpdate);
    _favoritesManager.init();
    _historyManager.addListener(_onManagerUpdate);
    _historyManager.init();
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerUpdate);
    _favoritesManager.removeListener(_onManagerUpdate);
    _historyManager.removeListener(_onManagerUpdate);
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
        backgroundColor: AppColors.surfaceOverlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.modal),
          side: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        title: Text('刪除此集離線檔案', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          '確定要刪除「${ep.title}」的所有已下載分段檔案嗎？',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('取消', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final freedBytes = await _manager.deleteEpisodeDownloads(ep);
              if (!mounted) return;
              setState(() {});
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    freedBytes > 0
                        ? '已刪除「${ep.title}」（釋出 ${_manager.formatBytes(freedBytes)}）'
                        : '已清除「${ep.title}」的下載紀錄',
                  ),
                ),
              );
            },
            child: const Text('刪除', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _shareEpisode(CatalogEpisode ep) {
    final showId = ep.showId.isNotEmpty
        ? ep.showId
        : CatalogParser.detectShowId('${ep.title} ${ep.id}');
    File? localFile;
    for (final p in ep.parts) {
      final f = _manager.getLocalFile(ep.id, p.label, showId: showId, title: ep.title);
      if (f != null && f.existsSync()) {
        localFile = f;
        break;
      }
    }

    showShareDialog(
      context,
      ep,
      localFilePath: localFile?.path,
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
    AppColors.watch(context);
    final completedList = _manager.completedDownloads;
    final activeList = _manager.activeDownloads;
    final failedList = _manager.failedDownloads;
    final totalItemCount = completedList.length + activeList.length + failedList.length;
    final totalSize = _manager.formatBytes(_manager.totalDownloadedBytes);
    final folderPath = _manager.downloadDirectoryPath;
    final episodes = downloadedEpisodes;
    final favoritesCount = _favoritesManager.count;
    final historyRecords = _historyManager.allRecordsSorted;

    final String appBarTitle = switch (_currentTabIndex) {
      1 => '我的收藏 (Favorites)',
      2 => '觀看紀錄',
      _ => '下載資料夾 (Downloads)',
    };

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
            Flexible(
              child: Text(
                appBarTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.title3Semibold,
              ),
            ),
            if (_currentTabIndex == 1 && favoritesCount > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$favoritesCount',
                  style: AppType.caption1Semibold.copyWith(
                    color: AppColors.accent,
                    fontFeatures: AppType.tabular,
                  ),
                ),
              ),
            ] else if (_currentTabIndex == 2 && historyRecords.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfacePrimary,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '${historyRecords.length}',
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
          if (_currentTabIndex == 0) ...[
            IconButton(
              icon: Icon(Icons.drive_file_move_outlined, color: AppColors.textSecondary),
              tooltip: '變更下載儲存位置',
              onPressed: () => StorageLocationHelper.showStoragePickerSheet(
                context,
                onStorageChanged: () {
                  if (mounted) setState(() {});
                },
              ),
            ),
            if (totalItemCount > 0)
              IconButton(
                icon: Icon(Icons.delete_sweep, color: AppColors.textSecondary),
                tooltip: '清空所有下載檔案',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surfaceOverlay,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.modal)),
                      title: Text('清空所有下載檔案', style: TextStyle(color: AppColors.textPrimary)),
                      content: Text(
                        '確定要刪除全部 $totalItemCount 個下載紀錄與離線檔案嗎？\n將釋出 $totalSize 儲存空間。',
                        style: TextStyle(color: AppColors.textSecondary),
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
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            final freed = await _manager.deleteAllDownloads();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).removeCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  freed > 0
                                      ? '已清空所有下載檔案，釋出 ${_manager.formatBytes(freed)} 儲存空間'
                                      : '已清空所有下載紀錄',
                                ),
                              ),
                            );
                          },
                          child: const Text('清空下載'),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ] else if (_currentTabIndex == 1 && favoritesCount > 0) ...[
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: AppColors.textSecondary),
              tooltip: '清空所有收藏',
              onPressed: () => FavoritesBody.confirmClearAll(context, _favoritesManager),
            ),
          ] else if (_currentTabIndex == 2 && historyRecords.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: AppColors.textSecondary),
              tooltip: '清空歷史紀錄',
              onPressed: () => HistoryBody.confirmClearAll(context, _historyManager),
            ),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(
        index: _currentTabIndex,
        children: [
          CustomScrollView(
            slivers: [
          // Storage Summary Card (BoardUI dark secondary surface + hairline border)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.borderSeparator),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfacePrimary,
                          borderRadius: BorderRadius.circular(AppRadius.control),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Icon(Icons.storage, color: AppColors.textSecondary, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('本機離線空間', style: AppType.caption1Medium),
                            const SizedBox(height: 2),
                            Text(
                              '$totalSize • ${episodes.length} 部節目${activeList.isNotEmpty ? " (${activeList.length} 個分段下載中)" : ""}',
                              style: AppType.headlineMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                fontFeatures: AppType.tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Divider(color: AppColors.borderSeparator, height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.folder_open, size: 14, color: AppColors.textTertiary),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Tooltip(
                          message: folderPath,
                          child: Text(
                            folderPath.isNotEmpty ? folderPath : '正在載入儲存路徑...',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption2Medium.copyWith(
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_manager.isUsingCustomDirectory) ...[
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                          ),
                          onPressed: () => StorageLocationHelper.handleResetStorage(
                            context,
                            onStorageChanged: () {
                              if (mounted) setState(() {});
                            },
                          ),
                          icon: const Icon(Icons.restore, size: 15),
                          label: Text('還原預設', style: AppType.caption1Medium),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                        ),
                        onPressed: () => StorageLocationHelper.showStoragePickerSheet(
                          context,
                          onStorageChanged: () {
                            if (mounted) setState(() {});
                          },
                        ),
                        icon: const Icon(Icons.drive_file_move_outlined, size: 15),
                        label: Text('變更位置', style: AppType.caption1Semibold.copyWith(color: AppColors.onAccent)),
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        '已下載節目清單 (${episodes.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
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
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
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
                        child: Icon(Icons.download_for_offline_outlined, size: 28, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('尚無已下載的離線影片', style: AppType.title3Semibold),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '在首頁或播放器中點擊「下載」按鈕，即可將節目儲存至本機資料夾隨時離線觀看。',
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
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                        ),
                        icon: const Icon(Icons.explore_outlined, size: 18),
                        label: Text('瀏覽節目清單', style: AppType.bodyMedium.copyWith(color: AppColors.onAccent)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
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
                    onShareTapped: () => _shareEpisode(ep),
                  );
                },
                childCount: episodes.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
          const FavoritesBody(),
          const HistoryBody(),
        ],
      ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (idx) => setState(() => _currentTabIndex = idx),
          backgroundColor: AppColors.surfaceOverlay,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.folder_special_outlined),
              activeIcon: Icon(Icons.folder_special),
              label: '下載',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.favorite_border),
              activeIcon: const Icon(Icons.favorite),
              label: favoritesCount > 0 ? '收藏 ($favoritesCount)' : '收藏',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history),
              activeIcon: Icon(Icons.history),
              label: '觀看紀錄',
            ),
          ],
        ),
      ),
    ),
    );
  }
}
