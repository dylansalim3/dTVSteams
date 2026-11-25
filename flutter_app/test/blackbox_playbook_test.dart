import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/catalog/show_channel.dart';
import 'package:dtvsteams/main.dart';
import 'package:dtvsteams/services/download_manager.dart';
import 'package:dtvsteams/services/pip_manager.dart';
import 'package:dtvsteams/services/playback_history_manager.dart';
import 'package:dtvsteams/ui/downloads_screen.dart';
import 'package:dtvsteams/ui/player_screen.dart';

void main() {
  group('Black Box Playbook: End-to-End Test Suite', () {
    testWidgets('Playbook E2E Journey: Cold Boot to YouTube Feed, Search, Downloads, Player, and Pagination', (WidgetTester tester) async {
      // =========================================================================
      // STEP 1: BB-01 Cold Boot, Branding, Header Integrity & Pill-Free Search
      // =========================================================================
      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(autoRefresh: false),
      ));

      // Wait for catalog load from assets or fallback
      for (int i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('dTV').evaluate().isNotEmpty) break;
      }

      // 1.1 Brand logos and action buttons in top bar (minimalist icon buttons)
      expect(find.text('dTV'), findsWidgets);
      expect(find.text('STEAMS'), findsOneWidget);
      expect(find.byTooltip('下載庫'), findsOneWidget);
      expect(find.byTooltip('刷新'), findsOneWidget);

      // 1.2 Search input is mounted and prominent
      expect(find.byType(TextField), findsOneWidget);

      // 1.3 Strict Black-Box Check: Category filter pills below search bar MUST be absent
      expect(find.text('全部 (All)'), findsNothing);
      expect(find.text('🔥 熱門 (Trending)'), findsNothing);
      expect(find.text('⭐ 原創 (Originals)'), findsNothing);
      expect(find.text('😂 爆笑 (Comedy)'), findsNothing);
      expect(find.text('⚡ 競技 (Action)'), findsNothing);

      // =========================================================================
      // STEP 2: BB-02 YouTube 1-by-1 Vertical Feed & Direct Chapter/Part Chips
      // =========================================================================
      expect(find.text('最新劇集與節目 (Episodes)'), findsOneWidget);
      expect(find.byType(YouTubeEpisodeCard), findsWidgets);
      expect(find.text('1080p FHD'), findsWidgets);

      // Direct chapter/part quick selectors directly on cards
      expect(find.text('Part 1'), findsWidgets);
      expect(find.text('Part 2'), findsWidgets);
      expect(find.text('Part 3'), findsWidgets);

      // Verify avatar, % match, and 分段 text are REMOVED per user request
      expect(find.textContaining('Match'), findsNothing);
      expect(find.textContaining('分段'), findsNothing);

      // =========================================================================
      // STEP 3: BB-03 Real-Time Search Filtering & Query Reset
      // =========================================================================
      // 3.1 Filter by location "台北"
      await tester.enterText(find.byType(TextField), '台北');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('最新劇集與節目 (Episodes)'), findsOneWidget);
      expect(find.byType(YouTubeEpisodeCard), findsWidgets);

      // 3.2 Filter with unmatched keyword
      await tester.enterText(find.byType(TextField), 'NON_EXISTENT_SERIES_999');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('無符合篩選條件之集數'), findsOneWidget);

      // 3.3 Clear query via clear icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(YouTubeEpisodeCard), findsWidgets);

      // =========================================================================
      // STEP 4: BB-07 Google Search Style Numbered Pagination (1, 2, 3, 4, 5, Prev, Next)
      // =========================================================================
      // Filter by a specific episode date to bring the pagination bar into immediate view
      await tester.enterText(find.byType(TextField), '2026-11-08');
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll down slightly to reveal the Google pagination bar
      final scrollable = find.byType(Scrollable);
      await tester.drag(scrollable.first, const Offset(0, -350));
      await tester.pump(const Duration(milliseconds: 100));

      // 4.1 Verify full-width pagination bar (Google icon & page count removed per user request)
      expect(find.byType(GooglePaginationBar), findsOneWidget);
      expect(find.text('上一頁'), findsOneWidget);
      expect(find.text('下一頁'), findsOneWidget);
      expect(find.byKey(const Key('page_btn_1')), findsOneWidget);
      expect(find.byKey(const Key('page_btn_prev')), findsOneWidget);
      expect(find.byKey(const Key('page_btn_next')), findsOneWidget);
      expect(find.textContaining('Google'), findsNothing);
      expect(find.textContaining('分頁導航'), findsNothing);

      // Scroll back to top to restore top bar
      await tester.drag(scrollable.first, const Offset(0, 400));
      await tester.pump(const Duration(milliseconds: 100));

      // Clear search to restore full feed
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll to bottom of full feed to verify 5 numbered pages (1, 2, 3, 4, 5)
      for (int i = 0; i < 10; i++) {
        await tester.drag(scrollable.first, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byKey(const Key('page_btn_5')).evaluate().isNotEmpty) break;
      }
      expect(find.byType(GooglePaginationBar), findsOneWidget);
      expect(find.byKey(const Key('page_btn_1')), findsOneWidget);
      expect(find.byKey(const Key('page_btn_2')), findsOneWidget);
      expect(find.byKey(const Key('page_btn_3')), findsOneWidget);
      expect(find.byKey(const Key('page_btn_4')), findsOneWidget);
      expect(find.byKey(const Key('page_btn_5')), findsOneWidget);

      // Scroll back to top to restore top bar
      for (int i = 0; i < 10; i++) {
        await tester.drag(scrollable.first, const Offset(0, 600));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // =========================================================================
      // STEP 5: BB-04 Downloads Folder Screen Navigation & Storage Layout
      // =========================================================================
      await tester.tap(find.byTooltip('下載庫'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Downloads screen opens with storage summary
      expect(find.text('下載資料夾 (Downloads)'), findsOneWidget);
      expect(find.text('本機離線空間'), findsOneWidget);
      expect(find.text('尚無已下載的離線影片'), findsOneWidget);

      // Return back to Home screen
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('STEAMS'), findsOneWidget);
    });

    testWidgets('Playbook E2E Journey: Player OSD, Speed Controls, and Autoplay Architecture', (WidgetTester tester) async {
      // =========================================================================
      // STEP 6: BB-06 Native Video Player OSD & Speed Controls
      // =========================================================================
      final testEpisode = CatalogEpisode(
        id: 'playbook-ep-1',
        title: '綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家',
        date: '2026-11-08',
        url: 'https://example.com/episode',
        overview: '黑黃兩隊阿里山競技爭霸',
        backdrop: '',
        poster: '',
        match: 99,
        rating: '13+',
        duration: '1小時 48分',
        category: 'trending',
        tags: ['台北'],
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://example.com/part1'),
          CatalogPart(label: 'Part 2', url: 'https://example.com/part2'),
          CatalogPart(label: 'Part 3', url: 'https://example.com/part3'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: NativePlayerScreen(episode: testEpisode, initialPartIndex: 0),
      ));

      await tester.pump(const Duration(milliseconds: 100));

      // 6.1 Verify OSD header title and initial speed (1.0x)
      expect(find.text('綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);

      // 6.2 Cycle playback speeds: 1.0x -> 1.25x -> 1.5x -> 2.0x -> 1.0x
      await tester.tap(find.text('1.0x'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('1.25x'), findsOneWidget);

      await tester.tap(find.text('1.25x'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('1.5x'), findsOneWidget);

      await tester.tap(find.text('1.5x'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('2.0x'), findsOneWidget);

      await tester.tap(find.text('2.0x'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('1.0x'), findsOneWidget);

      // 6.3 Verify Parts navigation chips inside player OSD
      expect(find.text('Part 1'), findsWidgets);
      expect(find.text('Part 2'), findsWidgets);
      expect(find.text('Part 3'), findsWidgets);

      // 6.4 Verify OSD download button & 1080p FHD badge
      expect(find.text('1080p FHD'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);

      // Unmount player cleanly
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Playbook E2E Journey: DownloadManager Storage Engine & Formatter', (WidgetTester tester) async {
      // =========================================================================
      // STEP 7: BB-05 Download Manager Engine & Formatter
      // =========================================================================
      final manager = DownloadManager();
      manager.clearForTesting();

      // Test byte formatting
      expect(manager.formatBytes(0), '0 B');
      expect(manager.formatBytes(512), '512.0 B');
      expect(manager.formatBytes(1024), '1.0 KB');
      expect(manager.formatBytes(1048576 * 25), '25.0 MB');
      expect(manager.formatBytes(1073741824 * 3), '3.0 GB');

      // Verify non-existent item queries return false safely
      expect(manager.isDownloaded('unknown_id', 'Part 1'), isFalse);
      expect(manager.isDownloading('unknown_id', 'Part 1'), isFalse);

      // Verify Deduplication & Cross-Scheme Resolution (Fix for 2026-10-31 Part 1 duplicate)
      final testDir = Directory.systemTemp.createTempSync('dtv_dedup_');
      final testFile = File('${testDir.path}/2026-10-31_Part1.mp4')..writeAsStringSync('dummy_video_bytes');

      // 1. Register item via disk scan / Date-Title scheme
      final scannedItem = DownloadItem(
        episodeId: '2026-10-31_綜藝玩很大 2026-10-31 台北 搗蛋鬼到你家',
        episodeTitle: '綜藝玩很大 2026-10-31 台北 搗蛋鬼到你家',
        partLabel: 'Part 1',
        partUrl: '',
        localFilePath: testFile.path,
        date: '2026-10-31',
        totalBytes: 44334441,
        downloadedBytes: 44334441,
        status: DownloadStatus.completed,
      );
      manager.addItemForTesting(scannedItem);

      // 2. Querying by live feed URL scheme should resolve reliably via unified matcher
      const liveWebUrl = 'https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-10-31-%e5%8f%b0%e5%8c%97-%e6%90%97%e8%9b%8b%e9%ac%bc%e5%88%b0%e4%bd%a0%e5%ae%b6/';
      expect(manager.isDownloaded(liveWebUrl, 'Part 1'), isTrue);
      expect(manager.getItem(liveWebUrl, 'Part 1'), isNotNull);

      // 3. Adding a duplicate item with same localFilePath should be deduplicated in completedDownloads
      final urlItem = DownloadItem(
        episodeId: liveWebUrl,
        episodeTitle: '綜藝玩很大 2026-10-31 台北 搗蛋鬼到你家',
        partLabel: 'Part 1',
        partUrl: liveWebUrl,
        localFilePath: testFile.path,
        date: '2026-10-31',
        totalBytes: 44334441,
        downloadedBytes: 44334441,
        status: DownloadStatus.completed,
      );
      manager.addItemForTesting(urlItem);

      // Completed downloads must NEVER contain duplicate items for the same file
      expect(manager.completedDownloads.length, 1);
      expect(manager.totalDownloadedBytes, 44334441);

      // Clean up test files
      manager.clearForTesting();
      try { testDir.deleteSync(recursive: true); } catch (_) {}
    });

    testWidgets('Playbook E2E Journey: Downloaded Item Standoff & Left Play Icon Removed (BB-06)', (WidgetTester tester) async {
      // =========================================================================
      // STEP 8: BB-06 Downloaded List Item Layout & Useful Info Standoff
      // =========================================================================
      final manager = DownloadManager();
      manager.clearForTesting();

      final tempDir = Directory.systemTemp.createTempSync('dtv_test_');
      final tempFile = File('${tempDir.path}/2026-11-08_Part1.mp4')..writeAsStringSync('mock_mp4_bytes');

      final mockItem = DownloadItem(
        episodeId: 'https://example.com/episode/',
        episodeTitle: '綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家',
        partLabel: 'Part 1',
        partUrl: 'https://example.com/part1',
        localFilePath: tempFile.path,
        date: '2026-11-08',
        totalBytes: 26214400, // 25.0 MB
        downloadedBytes: 26214400,
        status: DownloadStatus.completed,
      );
      manager.addItemForTesting(mockItem);

      // Mount DownloadsScreen
      await tester.pumpWidget(const MaterialApp(
        home: DownloadsScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // 8.1 Verify useful information stands out clearly on the unified episode card
      expect(find.byType(YouTubeEpisodeCard), findsOneWidget);
      expect(find.text('綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家'), findsOneWidget);
      expect(find.text('2026-11-08'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      expect(find.text('台北'), findsOneWidget);
      expect(find.text('1080p FHD'), findsOneWidget);
      expect(find.textContaining('已儲存 25.0 MB'), findsOneWidget);
      expect(find.text('Part 1 (已下載)'), findsOneWidget);

      // 8.2 Verify feed card reflects downloaded item clearly
      final testEp = CatalogEpisode(
        id: 'https://example.com/episode/',
        title: '綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家',
        date: '2026-11-08',
        url: 'https://example.com/episode/',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://example.com/part1'),
          CatalogPart(label: 'Part 2', url: 'https://example.com/part2'),
          CatalogPart(label: 'Part 3', url: 'https://example.com/part3'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: YouTubeEpisodeCard(
            episode: testEp,
            onPlayTapped: () {},
            onPartTapped: (_) {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Part 1 (已下載)'), findsOneWidget);
      expect(find.text('Part 2'), findsOneWidget);
      expect(find.text('Part 3'), findsOneWidget);
      expect(find.text('已載 1/3'), findsOneWidget);

      // 8.3 Verify TripleCircleDownloadButton and Popover Selection Sheet
      expect(find.byType(TripleCircleDownloadButton), findsOneWidget);
      await tester.tap(find.byType(TripleCircleDownloadButton));
      await tester.pumpAndSettle();

      // Verify popover reflects which parts have been downloaded & options for un-downloaded parts
      expect(find.text('下載分段管理'), findsOneWidget);
      expect(find.textContaining('已下載完成'), findsOneWidget);
      expect(find.text('未下載 (支援離線播放)'), findsNWidgets(2));
      expect(find.text('下載全集 (1080p FHD)'), findsNWidgets(2));
      expect(find.textContaining('快速版'), findsNothing);

      // Dismiss popover
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 8.4 Clean up
      manager.clearForTesting();
      try { tempDir.deleteSync(recursive: true); } catch (_) {}
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Playbook E2E Journey: Playback History & Watch Progress Tracking (BB-07)', (WidgetTester tester) async {
      // =========================================================================
      // STEP 9: BB-07 Playback History & Watch Progress Tracking
      // =========================================================================
      final historyManager = PlaybackHistoryManager();
      historyManager.clearForTesting();

      const testEpisodeId = 'https://srgoideas.com/test-episode-2026-11-08/';

      // 9.1 Test formatting and completion detection
      final recPart1 = PlaybackRecord(
        episodeId: testEpisodeId,
        partLabel: 'Part 1',
        partIndex: 0,
        positionMs: 1950000, // 32:30
        durationMs: 2100000, // 35:00 (Watched >90%)
        updatedAt: DateTime.now(),
      );
      expect(recPart1.isCompleted, isTrue);
      expect(recPart1.positionFormatted, '32:30');
      expect(recPart1.durationFormatted, '35:00');

      final recPart2 = PlaybackRecord(
        episodeId: testEpisodeId,
        partLabel: 'Part 2',
        partIndex: 1,
        positionMs: 630000, // 10:30 (Watched ~30%)
        durationMs: 2100000, // 35:00
        updatedAt: DateTime.now(),
      );
      expect(recPart2.isCompleted, isFalse);
      expect(recPart2.positionFormatted, '10:30');

      historyManager.addRecordForTesting(recPart1);
      historyManager.addRecordForTesting(recPart2);

      // Verify retrieval
      expect(historyManager.getRecord(testEpisodeId, 'Part 1')?.isCompleted, isTrue);
      expect(historyManager.getRecord(testEpisodeId, 'Part 2')?.isCompleted, isFalse);
      expect(historyManager.isEpisodeCompleted(testEpisodeId, 3), isFalse);

      // 9.2 Mount card and verify watch indicators render
      final testEp = CatalogEpisode(
        id: testEpisodeId,
        title: '綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家',
        date: '2026-11-08',
        url: testEpisodeId,
        parts: [
          CatalogPart(label: 'Part 1', url: '$testEpisodeId/1'),
          CatalogPart(label: 'Part 2', url: '$testEpisodeId/2'),
          CatalogPart(label: 'Part 3', url: '$testEpisodeId/3'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: YouTubeEpisodeCard(
            episode: testEp,
            onPlayTapped: () {},
            onPartTapped: (_) {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      // Part 1 completed shows checkmark, Part 2 in progress shows percentage
      expect(find.text('Part 1 ✓'), findsOneWidget);
      expect(find.textContaining('Part 2 (30%)'), findsOneWidget);
      expect(find.text('Part 3'), findsOneWidget);

      // Verify overall red progress bar indicator renders
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // 9.3 Test full completion badge
      final recPart3 = PlaybackRecord(
        episodeId: testEpisodeId,
        partLabel: 'Part 3',
        partIndex: 2,
        positionMs: 2000000,
        durationMs: 2100000,
        updatedAt: DateTime.now(),
      );
      historyManager.addRecordForTesting(recPart3);
      // Mark Part 2 complete as well
      historyManager.addRecordForTesting(PlaybackRecord(
        episodeId: testEpisodeId,
        partLabel: 'Part 2',
        partIndex: 1,
        positionMs: 2000000,
        durationMs: 2100000,
        updatedAt: DateTime.now(),
      ));

      expect(historyManager.isEpisodeCompleted(testEpisodeId, 3), isTrue);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: YouTubeEpisodeCard(
            episode: testEp,
            onPlayTapped: () {},
            onPartTapped: (_) {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('已看完'), findsOneWidget);

      // Clean up
      historyManager.clearForTesting();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Playbook E2E Journey: Batch Download & Storage Automation (BB-08)', (WidgetTester tester) async {
      final downloadManager = DownloadManager();
      downloadManager.clearForTesting();

      final tempDir = Directory.systemTemp.createTempSync('dtv_batch_');
      final f1 = File('${tempDir.path}/ep_part1.mp4')..writeAsStringSync('p1_bytes');
      final f2 = File('${tempDir.path}/ep_part2.mp4')..writeAsStringSync('p2_bytes');

      const epId = 'https://example.com/batch_ep';
      downloadManager.addItemForTesting(DownloadItem(
        episodeId: epId,
        episodeTitle: '綜藝玩很大 2026-11-08',
        partLabel: 'Part 1',
        partUrl: '$epId/1',
        localFilePath: f1.path,
        date: '2026-11-08',
        totalBytes: 5000000,
        downloadedBytes: 5000000,
        status: DownloadStatus.completed,
      ));
      downloadManager.addItemForTesting(DownloadItem(
        episodeId: epId,
        episodeTitle: '綜藝玩很大 2026-11-08',
        partLabel: 'Part 2',
        partUrl: '$epId/2',
        localFilePath: f2.path,
        date: '2026-11-08',
        totalBytes: 5000000,
        downloadedBytes: 5000000,
        status: DownloadStatus.completed,
      ));

      expect(downloadManager.completedDownloads.length, 2);

      // 10.1 Verify cleanupWatchedDownload deletes file and item
      final cleaned = await downloadManager.cleanupWatchedDownload(epId, 'Part 1');
      expect(cleaned, isTrue);
      expect(downloadManager.completedDownloads.length, 1);
      expect(f1.existsSync(), isFalse);

      // 10.2 Verify deleteAllDownloads purges remaining files
      await downloadManager.deleteAllDownloads();
      expect(downloadManager.completedDownloads.length, 0);
      expect(f2.existsSync(), isFalse);

      // 10.3 Verify One-Tap Batch Download Sheet UI
      final batchEp = CatalogEpisode(
        id: 'https://example.com/batch_sheet',
        title: '綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家',
        date: '2026-11-08',
        url: 'https://example.com/batch_sheet',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://example.com/p1'),
          CatalogPart(label: 'Part 2', url: 'https://example.com/p2'),
          CatalogPart(label: 'Part 3', url: 'https://example.com/p3'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: YouTubeEpisodeCard(
            episode: batchEp,
            onPlayTapped: () {},
            onPartTapped: (_) {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      // Tap download button to open popover sheet
      expect(find.byType(TripleCircleDownloadButton), findsOneWidget);
      await tester.tap(find.byType(TripleCircleDownloadButton));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Verify "一鍵下載全集 (剩餘 3 個未下載分段)" button is rendered
      expect(find.textContaining('一鍵下載全集'), findsOneWidget);
      expect(find.textContaining('剩餘 3 個未下載分段'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Clean up
      downloadManager.clearForTesting();
      try { tempDir.deleteSync(recursive: true); } catch (_) {}
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Playbook E2E Journey: Multi-Show Channel Expansion & Switcher (BB-09)', (WidgetTester tester) async {
      // 11.1 Verify ShowChannels Registry & URL Generation
      expect(ShowChannels.all.length, 5);
      expect(ShowChannels.mrPlayer.name, '綜藝玩很大');
      expect(ShowChannels.hungerGames.name, '飢餓遊戲');
      expect(ShowChannels.allStars.name, '全明星運動會');
      expect(ShowChannels.superEnt.name, '小明星大跟班');
      expect(ShowChannels.hotShop.name, '11點熱吵店');

      expect(ShowChannels.hungerGames.categoryUrl, contains('variety-show/%E9%A3%A2%E9%A4%93%E9%81%8A%E6%88%B2/'));
      expect(ShowChannels.hungerGames.pageUrl(2), contains('page/2/'));

      // 11.2 Verify Multi-Show HTML Parsing
      const mockCategoryHtml = '''
        <article>
          <header class="entry-header">
            <h2 class="entry-title"><a href="https://srgoideas.com/hunger-2026-11-22/">飢餓遊戲 2026-11-22 飢餓指數特別企劃</a></h2>
          </header>
        </article>
        <article>
          <header class="entry-header">
            <h2 class="entry-title"><a href="https://srgoideas.com/hunger-2026-11-15/">飢餓遊戲 2026-11-15 說好的提早下班之主謀騙你的</a></h2>
          </header>
        </article>
      ''';
      final parsed = CatalogParser.parseList(mockCategoryHtml, defaultShowName: '飢餓遊戲');
      expect(parsed.length, 2);
      expect(parsed.first.title, contains('飢餓遊戲 2026-11-22'));
      expect(parsed.first.overview, contains('飢餓遊戲全員挑戰飢餓指數'));
      expect(parsed.first.parts.length, 3);

      // 11.3 Mount HomeScreen and verify Channel Switcher Pill in Top Bar
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(autoRefresh: false, initialEpisodes: ShowChannels.mrPlayer.fallbackEpisodes),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Initial channel pill: 綜藝玩很大
      expect(find.text('綜藝玩很大'), findsWidgets);
      expect(find.text('🔥'), findsOneWidget);

      // Tap channel pill to open bottom sheet picker
      await tester.tap(find.text('綜藝玩很大').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify modal sheet opened with all channels
      expect(find.text('切換節目頻道 (Channels)'), findsOneWidget);
      expect(find.text('飢餓遊戲'), findsWidgets);
      expect(find.text('全明星運動會'), findsOneWidget);
      expect(find.text('小明星大跟班'), findsOneWidget);
      expect(find.text('11點熱吵店'), findsOneWidget);

      // Tap 飢餓遊戲 to switch
      await tester.tap(find.text('飢餓遊戲').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Active channel is now 飢餓遊戲
      expect(find.text('⚡'), findsOneWidget);
      expect(find.text('飢餓遊戲'), findsWidgets);
      expect(find.textContaining('已切換至「飢餓遊戲」'), findsOneWidget);

      // Verify channel feed has switched to Hunger Games episodes
      expect(find.textContaining('飢餓指數特別企劃'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Playbook E2E Journey: Picture-in-Picture (PiP) & Background Audio (BB-10)', (WidgetTester tester) async {
      const channel = MethodChannel('com.dtvsteams.dtvsteams/pip');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'isPipSupported') return true;
        if (call.method == 'enterPip') return true;
        if (call.method == 'setAutoPip') return true;
        return null;
      });

      final pipManager = PipManager();
      expect(pipManager.isInPipMode.value, isFalse);

      // Verify PiP support query
      final isSupported = await pipManager.isPipSupported();
      expect(isSupported, isTrue);

      final testEp = CatalogEpisode(
        id: 'https://srgoideas.com/pip_test/',
        title: '綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家',
        date: '2026-11-08',
        url: 'https://srgoideas.com/pip_test/',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/pip_test/1'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: NativePlayerScreen(episode: testEp, initialPartIndex: 0),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // 12.1 Verify PiP icon button is mounted in player OSD
      expect(find.byIcon(Icons.picture_in_picture_alt), findsOneWidget);

      // 12.2 Tap PiP button
      await tester.tap(find.byIcon(Icons.picture_in_picture_alt));
      await tester.pump(const Duration(milliseconds: 100));

      // 12.3 Simulate PiP mode activation
      pipManager.isInPipMode.value = true;
      await tester.pump(const Duration(milliseconds: 100));

      // In PiP mode, OSD header, buttons, and chips are suppressed to prevent clutter
      expect(find.byIcon(Icons.picture_in_picture_alt), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);

      // 12.4 Restore full screen
      pipManager.isInPipMode.value = false;
      await tester.pump(const Duration(milliseconds: 100));

      // Controls return
      expect(find.byIcon(Icons.picture_in_picture_alt), findsOneWidget);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
