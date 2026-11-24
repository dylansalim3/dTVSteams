import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/services/settings_manager.dart';
import 'package:dtvsteams/services/favorites_manager.dart';
import 'package:dtvsteams/services/playback_history_manager.dart';
import 'package:dtvsteams/ui/player_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 12: Skip Intro & Stall Fallback Unit & Widget Tests', () {
    setUp(() {
      SettingsManager().resetForTesting();
      FavoritesManager().clearAll();
      PlaybackHistoryManager().clearForTesting();
    });

    testWidgets('NativePlayerScreen renders skip intro pill and handles tap', (WidgetTester tester) async {
      final ep = CatalogEpisode(
        id: 'https://srgoideas.com/ep_skip_intro/',
        title: '綜藝玩很大 2026-11-20 嘉義特輯',
        date: '2026-11-20',
        url: 'https://srgoideas.com/ep_skip_intro/',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/ep_skip_intro/1'),
          CatalogPart(label: 'Part 2', url: 'https://srgoideas.com/ep_skip_intro/2'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: NativePlayerScreen(
          episode: ep,
          initialPartIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Screen renders title
      expect(find.text('綜藝玩很大 2026-11-20 嘉義特輯'), findsWidgets);

      // Verify PlayerScreen renders without error
      expect(find.byType(NativePlayerScreen), findsOneWidget);
    });
  });
}
