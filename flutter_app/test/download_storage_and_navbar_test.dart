import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/main.dart';
import 'package:dtvsteams/services/download_manager.dart';
import 'package:dtvsteams/services/settings_manager.dart';
import 'package:dtvsteams/services/update_manager.dart';
import 'package:dtvsteams/ui/about_update_dialog.dart';
import 'package:dtvsteams/ui/downloads_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory globalTempDir;

  setUpAll(() {
    globalTempDir = Directory.systemTemp.createTempSync('dtv_global_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (MethodCall call) async {
      return globalTempDir.path;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.dtvsteams.dtvsteams/storage'), (MethodCall call) async {
      if (call.method == 'getPublicStorageLocations') {
        return <String, String>{
          'downloads': '${globalTempDir.path}/Downloads/dTVSteams',
          'movies': '${globalTempDir.path}/Movies/dTVSteams',
        };
      }
      if (call.method == 'hasStoragePermission') return true;
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.dtvsteams.dtvsteams/storage'), null);
    try {
      if (globalTempDir.existsSync()) globalTempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Top Navbar Responsive Layout Tests', () {
    testWidgets('Top Navbar adapts responsively between ultra-compact (320px) and standard (390px)', (WidgetTester tester) async {
      // 1. Ultra-compact screen (320px width): Brand logo hides 'STEAMS' to eliminate overflow
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(
        home: HomeScreen(autoRefresh: false),
      ));
      for (int i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('dTV').evaluate().isNotEmpty) break;
      }

      // Ensure no overflow errors occurred
      expect(tester.takeException(), isNull);

      // On narrow screen (<370px), 'dTV' logo badge is present, but 'STEAMS' is hidden to save space
      expect(find.text('dTV'), findsWidgets);
      expect(find.text('STEAMS'), findsNothing);

      // Channel dropdown & top buttons are present
      expect(find.byIcon(Icons.arrow_drop_down), findsWidgets);
      expect(find.byIcon(Icons.folder_special), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // 2. Normal phone screen (390px width): Displays full 'dTV STEAMS' brand logo
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('dTV'), findsWidgets);
      expect(find.text('STEAMS'), findsOneWidget);
    });
  });

  group('Download Storage Migration Unit Tests', () {
    late Directory tempDirA;
    late Directory tempDirB;

    setUp(() {
      tempDirA = Directory.systemTemp.createTempSync('dtv_test_a_');
      tempDirB = Directory.systemTemp.createTempSync('dtv_test_b_');
      SettingsManager().resetForTesting();
      DownloadManager().clearForTesting();
    });

    tearDown(() {
      try {
        if (tempDirA.existsSync()) tempDirA.deleteSync(recursive: true);
        if (tempDirB.existsSync()) tempDirB.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('migrateDownloadDirectory copies files, updates item paths and manifests', () async {
      final manager = DownloadManager();
      manager.setDirectoryForTesting(tempDirA.path);

      // Create a dummy video file in directory A
      final testFileA = File('${tempDirA.path}/play_2026-11-21_Ep1_Part1.mp4');
      testFileA.writeAsStringSync('dummy video payload for test');

      final item = DownloadItem(
        episodeId: 'play_2026-11-21',
        episodeTitle: '綜藝玩很大 2026-11-21',
        showId: 'play',
        showName: '綜藝玩很大',
        partLabel: 'Part 1',
        partUrl: 'https://example.com/part1',
        localFilePath: testFileA.path,
        date: '2026-11-21',
        totalBytes: testFileA.lengthSync(),
        downloadedBytes: testFileA.lengthSync(),
        status: DownloadStatus.completed,
      );
      manager.addItemForTesting(item);

      // Perform migration to directory B
      final count = await manager.migrateDownloadDirectory(tempDirB.path);
      expect(count, 1);

      // Verify file moved to directory B
      final expectedFileB = File('${tempDirB.path}/play_2026-11-21_Ep1_Part1.mp4');
      expect(expectedFileB.existsSync(), isTrue);
      expect(expectedFileB.readAsStringSync(), 'dummy video payload for test');

      // Verify original file in directory A was deleted
      expect(testFileA.existsSync(), isFalse);

      // Verify item path updated
      expect(item.localFilePath, expectedFileB.path);
      expect(manager.downloadDirectoryPath, tempDirB.path);

      // Verify manifest.json in directory B
      final manifestB = File('${tempDirB.path}/manifest.json');
      expect(manifestB.existsSync(), isTrue);
      final manifestList = jsonDecode(manifestB.readAsStringSync()) as List<dynamic>;
      expect(manifestList.length, 1);
      expect(manifestList.first['localFilePath'], expectedFileB.path);
    });

    test('SettingsManager tracks customDownloadPath', () async {
      final settings = SettingsManager();
      settings.resetForTesting();
      expect(settings.customDownloadPath, isNull);

      await settings.setCustomDownloadPath('/storage/emulated/0/Download/dTVSteams');
      expect(settings.customDownloadPath, '/storage/emulated/0/Download/dTVSteams');

      await settings.setCustomDownloadPath(null);
      expect(settings.customDownloadPath, isNull);
    });
  });

  group('Download Storage Settings UI Widget Tests', () {
    testWidgets('AboutUpdateDialog displays Download Storage card and change button', (WidgetTester tester) async {
      final updateManager = UpdateManager();
      final settingsManager = SettingsManager();
      final downloadManager = DownloadManager();

      settingsManager.resetForTesting();
      downloadManager.clearForTesting();
      downloadManager.setDirectoryForTesting('/data/user/0/com.dtvsteams/dTVSteams_Downloads');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => AboutUpdateDialog.show(ctx, updateManager),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify Download Storage section is present
      expect(find.text('下載儲存位置 (Download Storage)'), findsOneWidget);
      expect(find.text('預設內部儲存空間'), findsOneWidget);
      expect(find.text('變更位置'), findsOneWidget);

      // Tap '變更位置' button to open picker sheet
      await tester.tap(find.text('變更位置'));
      await tester.pumpAndSettle();

      // Verify options are presented
      expect(find.text('選擇下載儲存位置'), findsOneWidget);
      expect(find.text('預設應用內部儲存'), findsWidgets);
      expect(find.text('自訂資料夾 (系統資料夾選取器)...'), findsOneWidget);
    });

    testWidgets('Displays custom tag and restore button when custom directory is active', (WidgetTester tester) async {
      final updateManager = UpdateManager();
      final settingsManager = SettingsManager();
      final downloadManager = DownloadManager();

      settingsManager.resetForTesting(customDownloadPath: '/storage/emulated/0/Download/dTVSteams');
      downloadManager.clearForTesting();
      downloadManager.setDirectoryForTesting('/storage/emulated/0/Download/dTVSteams');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => AboutUpdateDialog.show(ctx, updateManager),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('自訂儲存目錄'), findsOneWidget);
      expect(find.text('已自訂'), findsOneWidget);
      expect(find.text('還原預設'), findsOneWidget);
      expect(find.text('變更位置'), findsOneWidget);
    });

    testWidgets('DownloadsScreen displays storage change buttons and opens picker sheet', (WidgetTester tester) async {
      final settingsManager = SettingsManager();
      final downloadManager = DownloadManager();

      settingsManager.resetForTesting(customDownloadPath: '/storage/emulated/0/Download/dTVSteams');
      downloadManager.clearForTesting();
      downloadManager.setDirectoryForTesting('/storage/emulated/0/Download/dTVSteams');

      await tester.pumpWidget(const MaterialApp(
        home: DownloadsScreen(),
      ));
      await tester.pumpAndSettle();

      // Check AppBar action button exists
      expect(find.byTooltip('變更下載儲存位置'), findsOneWidget);

      // Check Storage Summary Card buttons exist
      expect(find.text('本機離線空間'), findsOneWidget);
      expect(find.text('還原預設'), findsOneWidget);
      expect(find.text('變更位置'), findsOneWidget);

      // Tap '變更位置' on DownloadsScreen to open picker sheet
      await tester.tap(find.text('變更位置'));
      await tester.pumpAndSettle();

      expect(find.text('選擇下載儲存位置'), findsOneWidget);
      expect(find.text('預設應用內部儲存'), findsWidgets);
    });

    testWidgets('Downloads page list item and green tag do not overflow on narrow (320px) screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final downloadManager = DownloadManager();
      downloadManager.clearForTesting();
      downloadManager.setDirectoryForTesting('/data/user/0/com.dtvsteams/downloads');

      final ep = CatalogEpisode(
        id: 'play_2026-11-21',
        title: '綜藝玩很大 2026-11-21 苗栗超強對決全集',
        date: '2026-11-21',
        url: 'https://example.com/play',
        showId: 'play',
        showName: '綜藝玩很大',
        overview: '超精彩對決',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://example.com/p1'),
          CatalogPart(label: 'Part 2', url: 'https://example.com/p2'),
          CatalogPart(label: 'Part 3', url: 'https://example.com/p3'),
        ],
      );

      final testFile = File('${globalTempDir.path}/test_p1.mp4');
      testFile.writeAsStringSync('dummy video payload');

      final item1 = DownloadItem(
        episodeId: ep.id,
        episodeTitle: ep.title,
        showId: ep.showId,
        showName: ep.showName,
        partLabel: 'Part 1',
        partUrl: 'https://example.com/p1',
        localFilePath: testFile.path,
        date: '2026-11-21',
        totalBytes: 350 * 1024 * 1024,
        downloadedBytes: 350 * 1024 * 1024,
        status: DownloadStatus.completed,
      );
      downloadManager.addItemForTesting(item1);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: YouTubeEpisodeCard(
            episode: ep,
            isDownloadView: true,
            onPlayTapped: () {},
            onPartTapped: (_) {},
            onDeleteTapped: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Ensure no RenderFlex overflow exception
      expect(tester.takeException(), isNull);

      // Verify the green tag is rendered
      expect(find.textContaining('已儲存'), findsOneWidget);
    });
  });
}
