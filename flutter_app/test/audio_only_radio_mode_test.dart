import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/services/settings_manager.dart';
import 'package:dtvsteams/services/favorites_manager.dart';
import 'package:dtvsteams/services/playback_history_manager.dart';
import 'package:dtvsteams/ui/player_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 11: Audio-Only Radio Mode Unit & Widget Tests', () {
    setUp(() {
      SettingsManager().resetForTesting();
      FavoritesManager().clearAll();
      PlaybackHistoryManager().clearForTesting();
    });

    testWidgets('NativePlayerScreen toggles into audio-only radio mode and shows vinyl view and returns', (WidgetTester tester) async {
      final ep = CatalogEpisode(
        id: 'https://srgoideas.com/ep_radio/',
        title: '綜藝玩很大 2026-11-20 澎湖廣播特輯',
        date: '2026-11-20',
        url: 'https://srgoideas.com/ep_radio/',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://srgoideas.com/ep_radio/1'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: NativePlayerScreen(
          episode: ep,
          initialPartIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Initially in video mode: radio badge should not be present
      expect(find.text('純音頻聽劇模式 · 70%+ 極致省電'), findsNothing);

      // Verify headphone icon button exists in top OSD
      final headphoneBtnFinder = find.byIcon(Icons.headphones_outlined);
      expect(headphoneBtnFinder, findsOneWidget);

      // Tap headphone icon to enter Audio-Only Radio Mode
      await tester.tap(headphoneBtnFinder);
      await tester.pumpAndSettle();

      // Radio Player view is now mounted
      expect(find.text('純音頻聽劇模式 · 70%+ 極致省電'), findsOneWidget);
      expect(find.text('綜藝玩很大 2026-11-20 澎湖廣播特輯'), findsWidgets);
      expect(find.text('返回視訊模式 (Return to Video)'), findsOneWidget);

      // Verify quick audio controls: fast rewind, play/pause, fast forward
      expect(find.byIcon(Icons.fast_rewind), findsOneWidget);
      expect(find.byIcon(Icons.fast_forward), findsOneWidget);

      // Tap '返回視訊模式' button to return to normal video mode
      await tester.tap(find.text('返回視訊模式 (Return to Video)'));
      await tester.pumpAndSettle();

      // Radio badge is gone
      expect(find.text('純音頻聽劇模式 · 70%+ 極致省電'), findsNothing);
    });
  });
}
