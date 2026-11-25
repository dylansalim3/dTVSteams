import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/main.dart';
import 'package:dtvsteams/services/search_history_manager.dart';
import 'package:dtvsteams/services/settings_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchHistoryManager Unit Tests', () {
    late SearchHistoryManager manager;

    setUp(() {
      manager = SearchHistoryManager();
      manager.clearForTesting();
    });

    test('addQuery, deduplicates, and limits to maxHistoryCount', () async {
      expect(manager.history, isEmpty);

      await manager.addQuery('憲哥');
      await manager.addQuery('KID');
      await manager.addQuery('澎湖');
      expect(manager.history, ['澎湖', 'KID', '憲哥']);

      // Deduplicate when adding existing query
      await manager.addQuery('KID');
      expect(manager.history, ['KID', '澎湖', '憲哥']);

      // Add more than 10 items
      for (int i = 1; i <= 15; i++) {
        await manager.addQuery('Item $i');
      }
      expect(manager.history.length, SearchHistoryManager.maxHistoryCount);
      expect(manager.history.first, 'Item 15');
    });

    test('removeQuery and clearHistory', () async {
      await manager.addQuery('Tag 1');
      await manager.addQuery('Tag 2');
      expect(manager.history.length, 2);

      await manager.removeQuery('Tag 1');
      expect(manager.history, ['Tag 2']);

      await manager.clearHistory();
      expect(manager.history, isEmpty);
    });
  });

  group('HomeScreen Year Filter & Sort & Search UI Widget Tests', () {
    final sampleEpisodes = [
      CatalogEpisode(
        id: 'ep-2026-1',
        title: '綜藝玩很大 2026-11-20 苗栗大對抗',
        date: '2026-11-20',
        url: 'https://example.com/ep-2026-1',
        parts: [CatalogPart(label: 'Part 1', url: 'https://example.com/1')],
      ),
      CatalogEpisode(
        id: 'ep-2025-1',
        title: '綜藝玩很大 2025-08-15 澎湖歡樂行',
        date: '2025-08-15',
        url: 'https://example.com/ep-2025-1',
        parts: [CatalogPart(label: 'Part 1', url: 'https://example.com/2')],
      ),
      CatalogEpisode(
        id: 'ep-2024-1',
        title: '綜藝玩很大 2024-05-10 金鐘十週年',
        date: '2024-05-10',
        url: 'https://example.com/ep-2024-1',
        parts: [CatalogPart(label: 'Part 1', url: 'https://example.com/3')],
      ),
    ];

    setUp(() {
      SettingsManager().resetForTesting();
      SearchHistoryManager().clearForTesting();
    });

    testWidgets('renders year chips and sort button without recent or hot suggestion row', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(initialEpisodes: sampleEpisodes),
      ));
      await tester.pumpAndSettle();

      // Verify year chips are displayed
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);

      // Verify sort button
      expect(find.text('新到舊'), findsOneWidget);

      // Verify recent and hot tags row is removed
      expect(find.text('🕒 最近: '), findsNothing);
      expect(find.text('🔥 熱門: '), findsNothing);
    });

    testWidgets('filtering by year 2025 narrows displayed episodes', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(initialEpisodes: sampleEpisodes),
      ));
      await tester.pumpAndSettle();

      // Initially all 3 episodes are shown (show name stripped from title since badge shows it)
      expect(find.text('2026-11-20 苗栗大對抗'), findsOneWidget);
      expect(find.text('2025-08-15 澎湖歡樂行'), findsOneWidget);

      // Tap '2025' chip
      await tester.tap(find.text('2025'));
      await tester.pumpAndSettle();

      // Now only 2025 episode is shown
      expect(find.text('2025-08-15 澎湖歡樂行'), findsOneWidget);
      expect(find.text('2026-11-20 苗栗大對抗'), findsNothing);

      // Tap '全部' to restore
      await tester.tap(find.text('全部'));
      await tester.pumpAndSettle();
      expect(find.text('2026-11-20 苗栗大對抗'), findsOneWidget);
    });

    testWidgets('toggling sort order reverses episode sequence', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(initialEpisodes: sampleEpisodes),
      ));
      await tester.pumpAndSettle();

      expect(find.text('新到舊'), findsOneWidget);

      // Tap sort button to switch to '舊到新'
      await tester.tap(find.text('新到舊'));
      await tester.pumpAndSettle();

      expect(find.text('舊到新'), findsOneWidget);
    });

    testWidgets('entering search query filters episode list', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(initialEpisodes: sampleEpisodes),
      ));
      await tester.pumpAndSettle();

      // Enter search query '澎湖'
      await tester.enterText(find.byType(TextField), '澎湖');
      await tester.pumpAndSettle();

      // Only the 澎湖 episode should match
      expect(find.text('2025-08-15 澎湖歡樂行'), findsOneWidget);
      expect(find.text('2026-11-20 苗栗大對抗'), findsNothing);
    });

    test('CatalogParser.stripShowNameFromTitle removes redundant show title when badge is shown', () {
      expect(
        CatalogParser.stripShowNameFromTitle('綜藝玩很大 2026-11-08 台北 搗蛋鬼到你家', showName: '綜藝玩很大'),
        equals('2026-11-08 台北 搗蛋鬼到你家'),
      );
      expect(
        CatalogParser.stripShowNameFromTitle('【綜藝玩很大】高雄 世紀爭霸戰', showName: '綜藝玩很大'),
        equals('高雄 世紀爭霸戰'),
      );
      expect(
        CatalogParser.stripShowNameFromTitle('飢餓遊戲 - 2026-11-22 飢餓指數特別企劃', showName: '飢餓遊戲'),
        equals('2026-11-22 飢餓指數特別企劃'),
      );
      expect(
        CatalogParser.stripShowNameFromTitle('綜藝玩很大', showName: '綜藝玩很大'),
        equals('綜藝玩很大'),
      );
      expect(
        CatalogParser.stripShowNameFromTitle('綜藝玩很大 2026-11-08 台北', showName: ''),
        equals('綜藝玩很大 2026-11-08 台北'),
      );
    });
  });
}
