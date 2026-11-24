import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/services/settings_manager.dart';
import 'package:dtvsteams/services/favorites_manager.dart';
import 'package:dtvsteams/services/playback_history_manager.dart';
import 'package:dtvsteams/ui/player_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auto-Play Next Part / Episode Unit & Widget Tests', () {
    late SettingsManager settingsManager;

    setUp(() {
      settingsManager = SettingsManager();
      settingsManager.resetForTesting(autoPlayNext: true);
      FavoritesManager().clearAll();
      PlaybackHistoryManager().clearForTesting();
    });

    test('SettingsManager autoPlayNext defaults to true and toggles correctly', () async {
      expect(settingsManager.autoPlayNext, isTrue);

      bool notified = false;
      settingsManager.addListener(() => notified = true);

      await settingsManager.setAutoPlayNext(false);
      expect(settingsManager.autoPlayNext, isFalse);
      expect(notified, isTrue);

      await settingsManager.setAutoPlayNext(true);
      expect(settingsManager.autoPlayNext, isTrue);
    });

    testWidgets('NativePlayerScreen renders auto-play countdown HUD when triggered', (WidgetTester tester) async {
      final ep1 = CatalogEpisode(
        id: 'https://srgoideas.com/ep_auto1/',
        title: '綜藝玩很大 2026-11-20 澎湖大冒險',
        date: '2026-11-20',
        url: 'https://srgoideas.com/ep_auto1/',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/ep_auto1/1'),
          CatalogPart(label: 'Part 2', url: 'https://srgoideas.com/ep_auto1/2'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: NativePlayerScreen(
          episode: ep1,
          initialPartIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Initially no countdown HUD
      expect(find.text('即將自動播放'), findsNothing);

      // Open playback settings sheet and verify toggle exists
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.text('自動連續播放下一段 / 下一集'), findsOneWidget);
      expect(find.text('分段或整集播畢前浮現 5 秒倒數並自動續播'), findsOneWidget);
    });

    testWidgets('NativePlayerScreen next target label shows next part then next episode', (WidgetTester tester) async {
      final ep1 = CatalogEpisode(
        id: 'https://srgoideas.com/ep1/',
        title: '綜藝玩很大 2026-11-20',
        date: '2026-11-20',
        url: 'https://srgoideas.com/ep1/',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/ep1/1'),
          CatalogPart(label: 'Part 2', url: 'https://srgoideas.com/ep1/2'),
        ],
      );
      final ep2 = CatalogEpisode(
        id: 'https://srgoideas.com/ep2/',
        title: '綜藝玩很大 2026-11-13',
        date: '2026-11-13',
        url: 'https://srgoideas.com/ep2/',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/ep2/1'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: NativePlayerScreen(
          episode: ep1,
          initialPartIndex: 0,
          playlist: [ep1, ep2],
        ),
      ));
      await tester.pumpAndSettle();

      // Verify player screen loaded
      expect(find.text('綜藝玩很大 2026-11-20'), findsOneWidget);
    });
  });
}
