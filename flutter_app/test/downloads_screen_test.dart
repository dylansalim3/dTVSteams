import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/services/download_manager.dart';
import 'package:dtvsteams/ui/downloads_screen.dart';
import 'package:dtvsteams/ui/episode_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadsScreen Unified Episode Card & Descending Sort Tests', () {
    late DownloadManager manager;
    late Directory tempDir;

    setUp(() {
      manager = DownloadManager();
      manager.clearForTesting();
      tempDir = Directory.systemTemp.createTempSync('dtv_test_downloads_');
    });

    tearDown(() {
      manager.clearForTesting();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('DownloadsScreen groups downloads by episode and sorts descending by date', (WidgetTester tester) async {
      final f1 = File('${tempDir.path}/ep1_p1.mp4')..writeAsStringSync('ep1_p1');
      final f2 = File('${tempDir.path}/ep1_p2.mp4')..writeAsStringSync('ep1_p2');
      final f3 = File('${tempDir.path}/ep2_p1.mp4')..writeAsStringSync('ep2_p1');

      // Older episode: 2026-11-08
      manager.addItemForTesting(DownloadItem(
        episodeId: 'https://example.com/ep_older',
        episodeTitle: '綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家',
        partLabel: 'Part 1',
        partUrl: 'https://example.com/ep_older/1',
        localFilePath: f1.path,
        date: '2026-11-08',
        totalBytes: 1024 * 1024 * 50,
        downloadedBytes: 1024 * 1024 * 50,
        status: DownloadStatus.completed,
      ));
      manager.addItemForTesting(DownloadItem(
        episodeId: 'https://example.com/ep_older',
        episodeTitle: '綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家',
        partLabel: 'Part 2',
        partUrl: 'https://example.com/ep_older/2',
        localFilePath: f2.path,
        date: '2026-11-08',
        totalBytes: 1024 * 1024 * 60,
        downloadedBytes: 1024 * 1024 * 60,
        status: DownloadStatus.completed,
      ));

      // Newer episode: 2026-11-21
      manager.addItemForTesting(DownloadItem(
        episodeId: 'https://example.com/ep_newer',
        episodeTitle: '綜藝玩很大 2026-11-21 台南 美食大作戰',
        partLabel: 'Part 1',
        partUrl: 'https://example.com/ep_newer/1',
        localFilePath: f3.path,
        date: '2026-11-21',
        totalBytes: 1024 * 1024 * 80,
        downloadedBytes: 1024 * 1024 * 80,
        status: DownloadStatus.completed,
      ));

      await tester.pumpWidget(const MaterialApp(
        home: DownloadsScreen(),
      ));
      await tester.pumpAndSettle();

      // 1. Verify header stats render
      expect(find.text('下載資料夾 (Downloads)'), findsOneWidget);
      expect(find.text('本機離線空間'), findsOneWidget);
      expect(find.textContaining('2 部節目'), findsOneWidget);

      // 2. Verify YouTubeEpisodeCard is used for each episode
      final cards = find.byType(YouTubeEpisodeCard);
      expect(cards, findsNWidgets(2));

      // 3. Verify chronological descending order: newer date (2026-11-21) appears first
      final card0 = tester.widget<YouTubeEpisodeCard>(cards.at(0));
      final card1 = tester.widget<YouTubeEpisodeCard>(cards.at(1));
      expect(card0.episode.date, '2026-11-21');
      expect(card1.episode.date, '2026-11-08');

      // 4. Verify Part 1 & Part 2 chips exist for the grouped older episode
      expect(find.text('Part 1 (已下載)'), findsNWidgets(2));
      expect(find.text('Part 2 (已下載)'), findsOneWidget);

      // 5. Verify Delete Button is present on each download card
      final deleteButtons = find.byTooltip('刪除此集離線檔案');
      expect(deleteButtons, findsNWidgets(2));

      // 6. Tap delete button on first card to trigger confirmation dialog
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('刪除此集離線檔案'), findsOneWidget);
      expect(find.textContaining('確定要刪除「綜藝玩很大 2026-11-21 台南 美食大作戰」的所有已下載分段檔案嗎？'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();

      // After deleting 2026-11-21, only 1 episode card remains
      expect(find.byType(YouTubeEpisodeCard), findsOneWidget);
      expect(f3.existsSync(), isFalse);
    });

    testWidgets('Cross-show download isolation: shows sharing same broadcast date do NOT cross-contaminate downloads',
        (WidgetTester tester) async {
      final showAFile = File('${tempDir.path}/mr_player_2026-11-15_Part1.mp4')
        ..writeAsStringSync('mr_player_content');

      const showAUrl = 'https://srgoideas.com/%e7%b6%9c%e8%97%9d%e7%8e%a9%e5%be%88%e5%a4%a7-2026-11-15-%e5%8f%b0%e4%b8%ad-%e5%89%8d%e8%bc%a9%e8%aa%aa%e4%ba%86%e7%ae%97/';
      const showBUrl = 'https://srgoideas.com/%e9%a3%a2%e9%a4%93%e9%81%8a%e6%88%b2-2026-11-15-%e8%aa%aa%e5%a5%bd%e7%9a%84%e6%8f%90%e6%97%a9%e4%b8%8b%e7%8f%ad%e4%b9%8b%e4%b8%bb%e8%ac%80%e9%a8%99%e4%bd%a0%e7%9a%84/';

      // Download Part 1 for Show A (綜藝玩很大, 2026-11-15)
      manager.addItemForTesting(DownloadItem(
        episodeId: showAUrl,
        episodeTitle: '綜藝玩很大 2026-11-15 台中 前輩說了算',
        showId: 'mr_player',
        showName: '綜藝玩很大',
        partLabel: 'Part 1',
        partUrl: showAUrl,
        localFilePath: showAFile.path,
        date: '2026-11-15',
        totalBytes: 50 * 1024 * 1024,
        downloadedBytes: 50 * 1024 * 1024,
        status: DownloadStatus.completed,
      ));

      // 1. Show A must be reported as downloaded
      expect(
        manager.isDownloaded(showAUrl, 'Part 1', showId: 'mr_player', title: '綜藝玩很大 2026-11-15 台中 前輩說了算'),
        isTrue,
      );
      expect(
        manager.getLocalFile(showAUrl, 'Part 1', showId: 'mr_player', title: '綜藝玩很大 2026-11-15 台中 前輩說了算'),
        isNotNull,
      );

      // 2. Show B on the exact same date (2026-11-15) must NEVER match Show A
      expect(
        manager.isDownloaded(showBUrl, 'Part 1', showId: 'hunger_games', title: '飢餓遊戲 2026-11-15 說好的提早下班之主謀騙你的'),
        isFalse,
      );
      expect(
        manager.getLocalFile(showBUrl, 'Part 1', showId: 'hunger_games', title: '飢餓遊戲 2026-11-15 說好的提早下班之主謀騙你的'),
        isNull,
      );
      expect(
        manager.getItem(showBUrl, 'Part 1', showId: 'hunger_games', title: '飢餓遊戲 2026-11-15 說好的提早下班之主謀騙你的'),
        isNull,
      );

      // 3. Render DownloadsScreen and verify show badge
      await tester.pumpWidget(const MaterialApp(
        home: DownloadsScreen(),
      ));
      await tester.pumpAndSettle();

      // Show badge with emoji should be visible
      expect(find.textContaining('🔥 綜藝玩很大'), findsWidgets);
    });

    testWidgets('DownloadsScreen bottom navigation switches between Downloads, Favorites, and History',
        (WidgetTester tester) async {
      final manager = DownloadManager();
      manager.clearForTesting();

      await tester.pumpWidget(const MaterialApp(
        home: DownloadsScreen(),
      ));
      await tester.pumpAndSettle();

      // Default tab: Downloads
      expect(find.text('下載資料夾 (Downloads)'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('下載'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('觀看紀錄'), findsOneWidget);

      // Switch to Favorites tab
      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();
      expect(find.text('我的收藏 (Favorites)'), findsOneWidget);
      expect(find.text('尚未加入任何收藏'), findsOneWidget);

      // Switch to History tab
      await tester.tap(find.text('觀看紀錄').last);
      await tester.pumpAndSettle();
      expect(find.text('尚無觀看歷史紀錄'), findsOneWidget);
    });
  });
}
