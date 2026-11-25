import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dtvsteams/services/update_manager.dart';
import 'package:dtvsteams/ui/about_update_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateManager Unit Tests', () {
    test('Semantic version comparison logic (isNewerVersion)', () {
      expect(UpdateManager.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(UpdateManager.isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(UpdateManager.isNewerVersion('2.0.0', '1.99.99'), isTrue);
      expect(UpdateManager.isNewerVersion('v1.0.1', '1.0.0'), isTrue);
      expect(UpdateManager.isNewerVersion('V1.2.0', '1.1.0'), isTrue);

      // Same versions
      expect(UpdateManager.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(UpdateManager.isNewerVersion('v1.0.0', '1.0.0'), isFalse);

      // Older versions
      expect(UpdateManager.isNewerVersion('0.9.9', '1.0.0'), isFalse);
      expect(UpdateManager.isNewerVersion('1.0.0', '1.0.1'), isFalse);
      expect(UpdateManager.isNewerVersion('1.0.0', '2.0.0'), isFalse);
    });

    test('checkForUpdate parses GitHub release JSON successfully', () async {
      final mockReleaseJson = jsonEncode({
        'tag_name': 'v1.1.0',
        'name': 'v1.1.0: Remote In-App Update Engine',
        'body': '- Auto remote update\n- Native APK installer',
        'html_url': 'https://github.com/dylansalim3/dTVSteams/releases/tag/v1.1.0',
        'published_at': '2026-11-23T20:00:00Z',
        'assets': [
          {
            'name': 'checksums-sha256.txt',
            'browser_download_url': 'https://example.com/checksums.txt',
            'size': 120,
          },
          {
            'name': 'dTVSteams-release.apk',
            'browser_download_url': 'https://example.com/dTVSteams-release.apk',
            'size': 53400000,
          },
        ],
      });

      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('releases/latest'));
        expect(request.headers['User-Agent'], equals('dTVSteams-Mobile-App'));
        return http.Response(mockReleaseJson, 200);
      });

      final manager = UpdateManager();
      final info = await manager.checkForUpdate(
        manual: true,
        client: mockClient,
        currentVersionOverride: '1.0.0',
      );

      expect(info, isNotNull);
      expect(info!.latestVersion, equals('1.1.0'));
      expect(info.hasUpdate, isTrue);
      expect(info.apkDownloadUrl, equals('https://example.com/dTVSteams-release.apk'));
      expect(info.apkSizeBytes, equals(53400000));
      expect(info.formattedSize, contains('50.9 MB'));
      expect(info.releaseNotes, contains('Auto remote update'));
      expect(manager.updateAvailable, isTrue);
      expect(manager.errorMessage, isNull);
    });

    test('checkForUpdate detects when app is already at latest version', () async {
      final mockReleaseJson = jsonEncode({
        'tag_name': 'v1.0.0',
        'name': 'v1.0.0',
        'body': 'Initial stable release',
        'html_url': 'https://github.com/dylansalim3/dTVSteams/releases/tag/v1.0.0',
        'assets': [],
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockReleaseJson, 200);
      });

      final manager = UpdateManager();
      final info = await manager.checkForUpdate(
        manual: true,
        client: mockClient,
        currentVersionOverride: '1.0.0',
      );

      expect(info, isNotNull);
      expect(info!.hasUpdate, isFalse);
      expect(manager.updateAvailable, isFalse);
    });

    test('checkForUpdate handles HTTP error gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Rate limit exceeded', 403);
      });

      final manager = UpdateManager();
      final info = await manager.checkForUpdate(
        manual: true,
        client: mockClient,
      );

      expect(info, isNull);
      expect(manager.errorMessage, contains('403'));
      expect(manager.updateAvailable, isFalse);
    });

    test('dismissVersion persists dismissed tag', () {
      final manager = UpdateManager();
      manager.dismissVersion('1.2.0');
      expect(manager.dismissedVersion, equals('1.2.0'));
    });

    test('init reads dynamic native version from MethodChannel', () async {
      const channel = MethodChannel('com.dtvsteams.dtvsteams/update');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getAppVersion') {
          return {'versionName': '1.0.4', 'versionCode': 5};
        }
        return null;
      });

      final manager = UpdateManager();
      await manager.init();
      expect(UpdateManager.currentAppVersion, '1.0.4');
      expect(UpdateManager.currentAppVersionCode, 5);
    });

    test('checkForUpdate awaits delayed init() so native version prevents false update prompt', () async {
      const channel = MethodChannel('com.dtvsteams.dtvsteams/update');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getAppVersion') {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return {'versionName': '1.0.11', 'versionCode': 12};
        }
        return null;
      });

      final mockReleaseJson = jsonEncode({
        'tag_name': 'v1.0.9',
        'name': 'v1.0.9',
        'body': 'Older release',
        'html_url': 'https://github.com/dylansalim3/dTVSteams/releases/tag/v1.0.9',
        'assets': [],
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockReleaseJson, 200);
      });

      final manager = UpdateManager();
      // Start init() without awaiting, immediately call checkForUpdate() just like HomeScreen.initState
      manager.init();
      final info = await manager.checkForUpdate(manual: true, client: mockClient);

      expect(info, isNotNull);
      expect(info!.currentVersion, equals('1.0.11'));
      expect(info.hasUpdate, isFalse);
      expect(manager.updateAvailable, isFalse);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });

  group('AboutUpdateDialog Widget Tests', () {
    testWidgets('Renders About & Updates sheet with current version and manual check button',
        (WidgetTester tester) async {
      final manager = UpdateManager();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => AboutUpdateDialog.show(ctx, manager),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('關於與版本更新'), findsOneWidget);
      expect(find.textContaining('目前安裝版本'), findsOneWidget);
      expect(find.text('檢查更新'), findsOneWidget);
      expect(find.text('開啟 GitHub 發布頁'), findsOneWidget);

      final sheetBox = tester.getRect(find.text('關於與版本更新'));
      expect(sheetBox.top, greaterThanOrEqualTo(100.0));
    });
  });
}
