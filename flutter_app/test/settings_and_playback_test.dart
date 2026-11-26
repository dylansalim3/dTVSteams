import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/services/playback_bridge.dart';
import 'package:dtvsteams/services/settings_manager.dart';
import 'package:dtvsteams/services/update_manager.dart';
import 'package:dtvsteams/ui/about_update_dialog.dart';
import 'package:dtvsteams/ui/player_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsManager Unit Tests', () {
    test('Default values are enabled (true)', () {
      final manager = SettingsManager();
      manager.resetForTesting();
      expect(manager.backgroundPlay, isTrue);
      expect(manager.keepScreenAwake, isTrue);
    });

    test('Toggling settings updates values and notifies listeners', () async {
      final manager = SettingsManager();
      manager.resetForTesting();

      int notifyCount = 0;
      manager.addListener(() => notifyCount++);

      await manager.setBackgroundPlay(false);
      expect(manager.backgroundPlay, isFalse);
      expect(notifyCount, 1);

      await manager.setKeepScreenAwake(false);
      expect(manager.keepScreenAwake, isFalse);
      expect(notifyCount, 2);

      // Re-setting to same value does not notify needlessly
      await manager.setBackgroundPlay(false);
      expect(notifyCount, 2);
    });
  });

  group('PlaybackBridge Unit Tests', () {
    const channel = MethodChannel('com.dtvsteams.dtvsteams/playback');
    final List<MethodCall> calls = [];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('setKeepScreenOn dispatches method call to platform channel', () async {
      final bridge = PlaybackBridge();
      bridge.resetForTesting();

      await bridge.setKeepScreenOn(true);
      expect(calls.length, 1);
      expect(calls.first.method, 'setKeepScreenOn');
      expect(calls.first.arguments, {'enabled': true});
      expect(bridge.isScreenAwake, isTrue);

      await bridge.setKeepScreenOn(false);
      expect(calls.length, 2);
      expect(calls.last.method, 'setKeepScreenOn');
      expect(calls.last.arguments, {'enabled': false});
      expect(bridge.isScreenAwake, isFalse);
    });

    test('startBackgroundPlay and stopBackgroundPlay dispatch to native service', () async {
      final bridge = PlaybackBridge();
      bridge.resetForTesting();

      await bridge.startBackgroundPlay(title: '綜藝玩很大 2026-11-21', part: 'Part 1');
      expect(calls.any((c) => c.method == 'startBackgroundPlay'), isTrue);
      final startCall = calls.firstWhere((c) => c.method == 'startBackgroundPlay');
      expect(startCall.arguments['title'], '綜藝玩很大 2026-11-21');
      expect(startCall.arguments['part'], 'Part 1');
      expect(bridge.isBackgroundServiceRunning, isTrue);

      await bridge.stopBackgroundPlay();
      expect(calls.any((c) => c.method == 'stopBackgroundPlay'), isTrue);
      expect(bridge.isBackgroundServiceRunning, isFalse);
    });

    test('startBackgroundPlay and stopBackgroundPlay deduplicate redundant platform calls', () async {
      final bridge = PlaybackBridge();
      bridge.resetForTesting();

      // Stopping when not running is a no-op
      await bridge.stopBackgroundPlay();
      expect(calls, isEmpty);

      // Repeated start with same title/part only dispatches once
      await bridge.startBackgroundPlay(title: '綜藝玩很大 2026-11-21', part: 'Part 1');
      await bridge.startBackgroundPlay(title: '綜藝玩很大 2026-11-21', part: 'Part 1');
      expect(calls.where((c) => c.method == 'startBackgroundPlay').length, 1);

      // Repeated stop only dispatches once
      await bridge.stopBackgroundPlay();
      await bridge.stopBackgroundPlay();
      expect(calls.where((c) => c.method == 'stopBackgroundPlay').length, 1);
    });
  });

  group('Settings UI Integration Tests', () {
    testWidgets('AboutUpdateDialog displays playback preference toggles', (WidgetTester tester) async {
      final updateManager = UpdateManager();
      final settingsManager = SettingsManager();
      settingsManager.resetForTesting();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => AboutUpdateDialog.show(ctx, updateManager),
              child: const Text('Open Settings'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('播放偏好設定 (Settings)'), findsOneWidget);
      expect(find.text('背景播放 (鎖定螢幕繼續播放音訊)'), findsOneWidget);
      expect(find.text('播放時保持螢幕常亮 (防止休眠)'), findsOneWidget);
      expect(find.text('自動連續播放下一段 / 下一集'), findsOneWidget);

      // Verify switches are toggled on by default (background play, keep awake, auto play next)
      expect(find.byType(Switch), findsNWidgets(3));
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches[0].value, isTrue);
      expect(switches[1].value, isTrue);
      expect(switches[2].value, isTrue);

      // Tap to toggle background play off
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(settingsManager.backgroundPlay, isFalse);

      // Verify SafeArea has top: true for status bar and notch clearance
      final safeAreas = tester.widgetList<SafeArea>(find.byType(SafeArea)).toList();
      final sheetSafeArea = safeAreas.firstWhere((sa) => sa.top == true && sa.bottom == true);
      expect(sheetSafeArea.top, isTrue);
      expect(sheetSafeArea.bottom, isTrue);
      expect(sheetSafeArea.minimum.top, greaterThanOrEqualTo(8.0));
    });

    testWidgets('PlayerScreen top OSD header includes settings tune button', (WidgetTester tester) async {
      final testEp = CatalogEpisode(
        id: 'https://srgoideas.com/tune_test/',
        title: '綜藝玩很大 2026-11-21 苗栗 歡樂無限',
        date: '2026-11-21',
        url: 'https://srgoideas.com/tune_test/',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/tune_test/1'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: NativePlayerScreen(episode: testEp, initialPartIndex: 0),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify tune/settings button is rendered in player OSD
      expect(find.byIcon(Icons.tune), findsOneWidget);

      // Tap tune button to open playback settings bottom sheet
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('播放偏好設定 (Settings)'), findsOneWidget);
      expect(find.text('背景播放 (鎖定螢幕繼續播放音訊)'), findsOneWidget);
      expect(find.text('播放中防止裝置休眠 (保持螢幕常亮)'), findsOneWidget);
    });

    testWidgets('Portrait PlayerScreen omits green/red engine text, avoids overflow, and handles double-tap fast forward safely',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testEp = CatalogEpisode(
        id: 'https://srgoideas.com/portrait_test/',
        title: '綜藝玩很大 2026-11-21 超長標題測試在窄螢幕下不會溢出或換行顯示異常',
        date: '2026-11-21',
        url: 'https://srgoideas.com/portrait_test/',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/portrait_test/1'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: NativePlayerScreen(episode: testEp, initialPartIndex: 0),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('ExoPlayer 1080p Engine'), findsNothing);
      expect(find.textContaining('本機離線播放'), findsNothing);

      // Simulate double-tap on the right side (fast forward)
      const rightTapPos = Offset(330, 420);
      await tester.tapAt(rightTapPos);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(rightTapPos);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('+10 秒'), findsOneWidget);

      // Wait for seek feedback timer (700ms) to expire cleanly
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('+10 秒'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
