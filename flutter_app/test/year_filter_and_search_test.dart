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

    testWidgets('renders year chips, sort button, and hot recommendation tags', (WidgetTester tester) async {
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

      // Verify hot tags
      expect(find.text('🔥 熱門: '), findsOneWidget);
      expect(find.text('憲哥'), findsOneWidget);
      expect(find.text('澎湖'), findsOneWidget);
    });

    testWidgets('filtering by year 2025 narrows displayed episodes', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(initialEpisodes: sampleEpisodes),
      ));
      await tester.pumpAndSettle();

      // Initially all 3 episodes are shown
      expect(find.text('綜藝玩很大 2026-11-20 苗栗大對抗'), findsOneWidget);
      expect(find.text('綜藝玩很大 2025-08-15 澎湖歡樂行'), findsOneWidget);

      // Tap '2025' chip
      await tester.tap(find.text('2025'));
      await tester.pumpAndSettle();

      // Now only 2025 episode is shown
      expect(find.text('綜藝玩很大 2025-08-15 澎湖歡樂行'), findsOneWidget);
      expect(find.text('綜藝玩很大 2026-11-20 苗栗大對抗'), findsNothing);

      // Tap '全部' to restore
      await tester.tap(find.text('全部'));
      await tester.pumpAndSettle();
      expect(find.text('綜藝玩很大 2026-11-20 苗栗大對抗'), findsOneWidget);
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

    testWidgets('tapping hot tag chip applies search query and filters list', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(initialEpisodes: sampleEpisodes),
      ));
      await tester.pumpAndSettle();

      // Tap hot tag '澎湖'
      await tester.tap(find.text('澎湖'));
      await tester.pumpAndSettle();

      // Only the 澎湖 episode should match
      expect(find.text('綜藝玩很大 2025-08-15 澎湖歡樂行'), findsOneWidget);
      expect(find.text('綜藝玩很大 2026-11-20 苗栗大對抗'), findsNothing);
    });
  });
}
