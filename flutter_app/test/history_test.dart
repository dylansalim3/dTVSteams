import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/services/playback_history_manager.dart';
import 'package:dtvsteams/ui/history_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final historyManager = PlaybackHistoryManager();

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('dtv_history_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (MethodCall call) async {
      return tempDir.path;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await historyManager.init();
    historyManager.clearForTesting();
  });

  group('PlaybackHistoryManager & PlaybackRecord Unit Tests', () {
    test('PlaybackRecord json roundtrip preserves all metadata', () {
      final ep = CatalogEpisode(
        id: 'mrplayer_20261121',
        title: '2026-11-21 苗栗客家庄大冒險',
        date: '2026-11-21',
        url: 'https://example.com/20261121',
        showName: '綜藝玩很大',
      );

      final record = PlaybackRecord(
        episodeId: 'mrplayer_20261121',
        partLabel: 'Part 1',
        partIndex: 0,
        positionMs: 120000,
        durationMs: 300000,
        updatedAt: DateTime(2026, 11, 21, 15, 30),
        episodeTitle: ep.title,
        thumbnailUrl: 'https://example.com/thumb.jpg',
        showName: '綜藝玩很大',
        episode: ep,
      );

      expect(record.progress, closeTo(0.4, 0.01));
      expect(record.isCompleted, isFalse);
      expect(record.positionFormatted, '02:00');
      expect(record.durationFormatted, '05:00');
      expect(record.effectiveTitle, ep.title);
      expect(record.effectiveShowName, '綜藝玩很大');

      final json = record.toJson();
      final restored = PlaybackRecord.fromJson(json);

      expect(restored.episodeId, record.episodeId);
      expect(restored.partLabel, record.partLabel);
      expect(restored.partIndex, 0);
      expect(restored.positionMs, 120000);
      expect(restored.durationMs, 300000);
      expect(restored.episodeTitle, ep.title);
      expect(restored.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(restored.showName, '綜藝玩很大');
      expect(restored.episode?.id, ep.id);
    });

    test('allRecordsSorted orders records by updatedAt descending', () {
      final now = DateTime.now();
      historyManager.addRecordForTesting(PlaybackRecord(
        episodeId: 'ep1',
        partLabel: 'Part 1',
        positionMs: 1000,
        durationMs: 10000,
        updatedAt: now.subtract(const Duration(hours: 2)),
      ));
      historyManager.addRecordForTesting(PlaybackRecord(
        episodeId: 'ep2',
        partLabel: 'Part 1',
        positionMs: 2000,
        durationMs: 10000,
        updatedAt: now,
      ));

      final sorted = historyManager.allRecordsSorted;
      expect(sorted.length, 2);
      expect(sorted[0].episodeId, 'ep2');
      expect(sorted[1].episodeId, 'ep1');
    });

    test('recentEpisodeRecords dedupes multi-part records per episode', () {
      final now = DateTime.now();
      historyManager.addRecordForTesting(PlaybackRecord(
        episodeId: 'ep1',
        partLabel: 'Part 1',
        positionMs: 1000,
        durationMs: 10000,
        updatedAt: now.subtract(const Duration(minutes: 10)),
      ));
      historyManager.addRecordForTesting(PlaybackRecord(
        episodeId: 'ep1',
        partLabel: 'Part 2',
        positionMs: 5000,
        durationMs: 10000,
        updatedAt: now,
      ));

      final recents = historyManager.recentEpisodeRecords;
      expect(recents.length, 1);
      expect(recents.first.partLabel, 'Part 2');
    });
  });

  group('HistoryScreen Widget Tests', () {
    testWidgets('Displays empty state when no history records exist', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('觀看紀錄'), findsOneWidget);
      expect(find.text('尚無觀看歷史紀錄'), findsOneWidget);
      expect(find.text('開始探索節目'), findsOneWidget);
    });

    testWidgets('Displays history items and allows single delete', (WidgetTester tester) async {
      final now = DateTime.now();
      historyManager.addRecordForTesting(PlaybackRecord(
        episodeId: 'test_ep_01',
        partLabel: 'Part 1',
        partIndex: 0,
        positionMs: 300000,
        durationMs: 600000,
        updatedAt: now,
        episodeTitle: '2026-11-21 苗栗關卡激鬥',
        showName: '綜藝玩很大',
      ));

      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026-11-21 苗栗關卡激鬥'), findsOneWidget);
      expect(find.text('綜藝玩很大'), findsOneWidget);
      expect(find.text('Part 1'), findsOneWidget);
      expect(find.textContaining('05:00 / 10:00 (50%)'), findsOneWidget);

      // Tap delete button on the card
      final deleteBtn = find.byTooltip('刪除紀錄');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Card is removed, empty state appears
      expect(find.text('2026-11-21 苗栗關卡激鬥'), findsNothing);
      expect(find.text('尚無觀看歷史紀錄'), findsOneWidget);
    });

    testWidgets('Clear all dialog empties history upon confirmation', (WidgetTester tester) async {
      final now = DateTime.now();
      historyManager.addRecordForTesting(PlaybackRecord(
        episodeId: 'test_ep_01',
        partLabel: 'Part 1',
        positionMs: 100,
        durationMs: 1000,
        updatedAt: now,
        episodeTitle: '測試第一集',
      ));
      historyManager.addRecordForTesting(PlaybackRecord(
        episodeId: 'test_ep_02',
        partLabel: 'Part 2',
        positionMs: 200,
        durationMs: 1000,
        updatedAt: now,
        episodeTitle: '測試第二集',
      ));

      await tester.pumpWidget(
        const MaterialApp(
          home: HistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('測試第一集'), findsOneWidget);
      expect(find.text('測試第二集'), findsOneWidget);

      // Tap top clear all action
      final clearAllBtn = find.byTooltip('清空歷史紀錄');
      expect(clearAllBtn, findsOneWidget);
      await tester.tap(clearAllBtn);
      await tester.pumpAndSettle();

      // Alert dialog confirms clear
      expect(find.text('清空所有歷史紀錄？'), findsOneWidget);
      await tester.tap(find.text('確認清空'));
      await tester.pumpAndSettle();

      expect(find.text('尚無觀看歷史紀錄'), findsOneWidget);
      expect(historyManager.records.isEmpty, isTrue);
    });
  });
}
