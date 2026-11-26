import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/services/pip_manager.dart';
import 'package:dtvsteams/ui/player_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativePlayerScreen Back Button Teardown Tests', () {
    const pipChannel = MethodChannel('com.dtvsteams.dtvsteams/pip');
    final List<MethodCall> pipCalls = [];

    setUp(() {
      pipCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pipChannel, (MethodCall call) async {
        pipCalls.add(call);
        if (call.method == 'isPipSupported') return true;
        if (call.method == 'enterPip') return true;
        if (call.method == 'setAutoPip') return true;
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pipChannel, null);
    });

    testWidgets('Tapping back button triggers complete teardown, pauses player and disables auto-pip', (WidgetTester tester) async {
      final testEp = CatalogEpisode(
        id: 'https://example.com/player_back_test',
        title: '綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家',
        date: '2026-11-08',
        url: 'https://example.com/player_back_test',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://example.com/part1', streamUrl: 'https://example.com/stream.m3u8'),
        ],
      );

      bool popped = false;

      await tester.pumpWidget(MaterialApp(
        home: Navigator(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => NativePlayerScreen(
                          episode: testEp,
                          initialPartIndex: 0,
                        ),
                      ),
                    ).then((_) {
                      popped = true;
                    });
                  },
                  child: const Text('Open Player'),
                ),
              ),
            );
          },
        ),
      ));

      // Open player
      await tester.tap(find.text('Open Player'));
      await tester.pumpAndSettle();

      // Verify Player Screen and back arrow are displayed
      expect(find.byType(NativePlayerScreen), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Verify AutoPiP was enabled on entry
      expect(pipCalls.any((c) => c.method == 'setAutoPip' && c.arguments['enabled'] == true), isTrue);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Verify route was popped and NativePlayerScreen is no longer present
      expect(popped, isTrue);
      expect(find.byType(NativePlayerScreen), findsNothing);

      // Verify AutoPiP was immediately disabled on exit
      expect(pipCalls.last.method, 'setAutoPip');
      expect(pipCalls.last.arguments['enabled'], isFalse);
    });

    testWidgets('System bars stay visible while play/pause controls show, hide only when controls hide, and restore on exit',
        (WidgetTester tester) async {
      final List<MethodCall> platformCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        platformCalls.add(call);
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      final testEp = CatalogEpisode(
        id: 'https://example.com/player_sysui_test',
        title: '綜藝玩很大 2026-11-08 台北 系統欄測試',
        date: '2026-11-08',
        url: 'https://example.com/player_sysui_test',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://example.com/part1', streamUrl: 'https://example.com/stream.m3u8'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => NativePlayerScreen(episode: testEp, initialPartIndex: 0),
                    ),
                  );
                },
                child: const Text('Launch Video'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Launch Video'));
      await tester.pumpAndSettle();

      // 1. Controls are initially visible -> native system bars MUST NOT be hidden yet
      expect(
        platformCalls.any((c) =>
            c.method == 'SystemChrome.setEnabledSystemUIMode' &&
            c.arguments == 'SystemUiMode.immersiveSticky'),
        isFalse,
      );

      // 2. Toggle OSD off (using keyboard down shortcut / _toggleOsd) -> enters immersiveSticky
      platformCalls.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(
        platformCalls.any((c) =>
            c.method == 'SystemChrome.setEnabledSystemUIMode' &&
            c.arguments == 'SystemUiMode.immersiveSticky'),
        isTrue,
        reason: 'platformCalls: ${platformCalls.map((c) => '${c.method}(${c.arguments})').toList()}',
      );

      bool hasNormalBarsRestored(List<MethodCall> calls) {
        final manual = calls.any((c) =>
            c.method == 'SystemChrome.setEnabledSystemUIMode' &&
            c.arguments == 'SystemUiMode.manual');
        final overlays = calls.any((c) =>
            c.method == 'SystemChrome.setEnabledSystemUIOverlays' &&
            c.arguments is List &&
            (c.arguments as List).contains('SystemUiOverlay.top') &&
            (c.arguments as List).contains('SystemUiOverlay.bottom'));
        return manual || overlays;
      }

      // 3. Toggle OSD back on (controls visible again) -> restores top+bottom overlays while still in player
      platformCalls.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(
        hasNormalBarsRestored(platformCalls),
        isTrue,
        reason: 'platformCalls: ${platformCalls.map((c) => '${c.method}(${c.arguments})').toList()}',
      );
      expect(
        platformCalls.any((c) => c.arguments == 'SystemUiMode.edgeToEdge'),
        isFalse,
      );

      // 4. Hide controls again -> immersiveSticky, then show + exit via back button -> restores normal overlays
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        platformCalls.lastWhere((c) => c.method == 'SystemChrome.setEnabledSystemUIMode').arguments,
        'SystemUiMode.immersiveSticky',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      platformCalls.clear();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(platformCalls.any((c) => c.arguments == 'SystemUiMode.edgeToEdge'), isFalse);
      expect(hasNormalBarsRestored(platformCalls), isTrue);
    });

    testWidgets('PipManager forwards playback state, enters PiP with state, and dispatches native PiP play/pause actions',
        (WidgetTester tester) async {
      final pipManager = PipManager();
      final List<String> receivedActions = [];
      pipManager.onPipAction = receivedActions.add;
      addTearDown(() => pipManager.onPipAction = null);

      await pipManager.setAutoPip(false);
      pipCalls.clear();

      await pipManager.setPlaybackState(true);
      await pipManager.setPlaybackState(true); // Deduplicated identical state
      await pipManager.setPlaybackState(false);
      await pipManager.enterPip(isPlaying: true);

      expect(
        pipCalls.where((c) => c.method == 'setPipPlaybackState').map((c) => c.arguments['isPlaying']).toList(),
        [true, false],
      );
      final enterCall = pipCalls.lastWhere((c) => c.method == 'enterPip');
      expect(enterCall.arguments, {'isPlaying': true});

      // Simulate native BroadcastReceiver invoking onPipAction from PiP RemoteAction
      const codec = StandardMethodCodec();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.dtvsteams.dtvsteams/pip',
        codec.encodeMethodCall(const MethodCall('onPipAction', 'pause')),
        (_) {},
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'com.dtvsteams.dtvsteams/pip',
        codec.encodeMethodCall(const MethodCall('onPipAction', 'play')),
        (_) {},
      );
      await tester.pump();

      expect(receivedActions, ['pause', 'play']);

      // Verify tapping OSD PiP icon sends current playing state into enterPip
      final testEp = CatalogEpisode(
        id: 'https://example.com/player_pip_button_test',
        title: '綜藝玩很大 2026-11-08 台北 PiP 按鈕測試',
        date: '2026-11-08',
        url: 'https://example.com/player_pip_button_test',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://example.com/part1', streamUrl: 'https://example.com/stream.m3u8'),
        ],
      );
      await tester.pumpWidget(MaterialApp(
        home: NativePlayerScreen(episode: testEp, initialPartIndex: 0),
      ));
      await tester.pump();
      pipCalls.clear();

      await tester.tap(find.byIcon(Icons.picture_in_picture_alt));
      await tester.pump();

      expect(pipCalls.any((c) => c.method == 'enterPip' && c.arguments['isPlaying'] == false), isTrue);
      expect(find.byKey(const ValueKey('player_time_display')), findsOneWidget);
      expect(find.byIcon(Icons.replay_10), findsNothing);
      expect(find.byIcon(Icons.forward_10), findsNothing);
      expect(find.textContaining('1080p'), findsNothing);
    });
  });
}
