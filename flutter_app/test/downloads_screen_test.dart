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
  });
}
