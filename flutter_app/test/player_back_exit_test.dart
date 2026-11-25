import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
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
  });
}
