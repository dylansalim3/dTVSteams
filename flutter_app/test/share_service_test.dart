import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/services/share_service.dart';
import 'package:dtvsteams/ui/episode_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.dtvsteams.dtvsteams/share');
  late Directory tempDir;
  final log = <MethodCall>[];

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('dtv_test_share_');
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      if (methodCall.method == 'shareFile' || methodCall.method == 'shareFiles') {
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('ShareService Tests', () {
    test('shareVideoFile returns false when file does not exist', () async {
      final success = await ShareService.shareVideoFile('${tempDir.path}/non_existent.mp4');
      expect(success, isFalse);
      expect(log, isEmpty);
    });

    test('shareVideoFile invokes native channel when file exists', () async {
      final file = File('${tempDir.path}/video.mp4')..writeAsStringSync('dummy');
      final success = await ShareService.shareVideoFile(
        file.path,
        title: '綜藝玩很大 2026-11-08',
      );

      expect(success, isTrue);
      expect(log.length, 1);
      expect(log.first.method, 'shareFile');
      expect(log.first.arguments['filePath'], file.path);
      expect(log.first.arguments['title'], '綜藝玩很大 2026-11-08');
      expect(log.first.arguments['mimeType'], 'video/mp4');
    });

    test('shareVideoFiles filters out missing files and shares existing', () async {
      final f1 = File('${tempDir.path}/p1.mp4')..writeAsStringSync('p1');
      final f2 = File('${tempDir.path}/p2.mp4')..writeAsStringSync('p2');
      final nonExistent = '${tempDir.path}/missing.mp4';

      final success = await ShareService.shareVideoFiles(
        [f1.path, nonExistent, f2.path],
        title: '綜藝玩很大 全部分段',
      );

      expect(success, isTrue);
      expect(log.length, 1);
      expect(log.first.method, 'shareFiles');
      final paths = log.first.arguments['filePaths'] as List;
      expect(paths.length, 2);
      expect(paths, contains(f1.path));
      expect(paths, contains(f2.path));
      expect(paths, isNot(contains(nonExistent)));
    });
  });

  group('YouTubeEpisodeCard Share Button Widget Tests', () {
    testWidgets('renders share button in download view and triggers callback', (WidgetTester tester) async {
      bool shareTapped = false;
      final ep = CatalogEpisode(
        id: 'ep1',
        title: '【綜藝玩很大】第450集 嘉義 經典大對決',
        date: '2026-11-08',
        url: 'https://example.com/ep1',
        overview: '測試簡介',
        parts: [CatalogPart(label: 'Part 1', url: 'https://example.com/p1')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YouTubeEpisodeCard(
              episode: ep,
              isDownloadView: true,
              onPlayTapped: () {},
              onPartTapped: (_) {},
              onShareTapped: () {
                shareTapped = true;
              },
            ),
          ),
        ),
      );

      // Verify Share button exists with tooltip
      final shareBtn = find.byTooltip('分享離線影片');
      expect(shareBtn, findsOneWidget);

      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      expect(shareTapped, isTrue);
    });

    testWidgets('does not render share button when not in download view', (WidgetTester tester) async {
      final ep = CatalogEpisode(
        id: 'ep1',
        title: '【綜藝玩很大】第450集 嘉義 經典大對決',
        date: '2026-11-08',
        url: 'https://example.com/ep1',
        overview: '測試簡介',
        parts: [CatalogPart(label: 'Part 1', url: 'https://example.com/p1')],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YouTubeEpisodeCard(
              episode: ep,
              isDownloadView: false,
              onPlayTapped: () {},
              onPartTapped: (_) {},
              onShareTapped: () {},
            ),
          ),
        ),
      );

      final shareBtn = find.byTooltip('分享離線影片');
      expect(shareBtn, findsNothing);
    });
  });
}
