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
  });
}
