import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/services/favorites_manager.dart';
import 'package:dtvsteams/ui/favorites_screen.dart';

void main() {
  group('FavoritesManager Unit Tests', () {
    late FavoritesManager manager;
    late CatalogEpisode sampleEpisode;

    setUp(() {
      manager = FavoritesManager();
      manager.clearAll();
      sampleEpisode = CatalogEpisode(
        id: 'ep-test-fav-1',
        title: '【綜藝玩很大】台北 旗艦大對決',
        date: '2026-11-20',
        url: 'https://example.com/ep-fav-1',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://example.com/p1.mp4'),
          CatalogPart(label: 'Part 2', url: 'https://example.com/p2.mp4'),
        ],
      );
    });

    tearDown(() {
      manager.clearAll();
    });

    test('initial favorites state is empty', () {
      expect(manager.count, equals(0));
      expect(manager.favoriteEpisodes, isEmpty);
      expect(manager.isFavorite(sampleEpisode.id), isFalse);
    });

    test('addFavorite and isFavorite work correctly', () async {
      await manager.addFavorite(sampleEpisode);
      expect(manager.count, equals(1));
      expect(manager.isFavorite(sampleEpisode.id), isTrue);
      expect(manager.favoriteEpisodes.first.title, contains('台北 旗艦大對決'));
    });

    test('toggleFavorite toggles favorite status', () async {
      final added = await manager.toggleFavorite(sampleEpisode);
      expect(added, isTrue);
      expect(manager.isFavorite(sampleEpisode.id), isTrue);

      final removed = await manager.toggleFavorite(sampleEpisode);
      expect(removed, isFalse);
      expect(manager.isFavorite(sampleEpisode.id), isFalse);
      expect(manager.count, equals(0));
    });

    test('clearAll removes all favorite records', () async {
      await manager.addFavorite(sampleEpisode);
      final ep2 = CatalogEpisode(
        id: 'ep-test-fav-2',
        title: '【綜藝玩很大】台南 美食大戰',
        date: '2026-11-21',
        url: 'https://example.com/ep-fav-2',
      );
      await manager.addFavorite(ep2);
      expect(manager.count, equals(2));

      await manager.clearAll();
      expect(manager.count, equals(0));
      expect(manager.favoriteEpisodes, isEmpty);
    });
  });

  group('FavoritesScreen Widget Tests', () {
    late FavoritesManager manager;

    setUp(() {
      manager = FavoritesManager();
      manager.clearAll();
    });

    tearDown(() {
      manager.clearAll();
    });

    testWidgets('renders empty state when there are no favorites', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FavoritesScreen(),
        ),
      );

      expect(find.text('我的收藏 (Favorites)'), findsOneWidget);
      expect(find.text('尚未加入任何收藏'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsWidgets);
    });

    testWidgets('renders favorite episode cards when items exist', (tester) async {
      final ep = CatalogEpisode(
        id: 'ep-widget-fav',
        title: '【綜藝玩很大】高雄 世紀爭霸戰',
        date: '2026-11-22',
        url: 'https://example.com/ep-fav-widget',
        parts: [
          CatalogPart(label: 'Part 1', url: 'https://example.com/p1.mp4'),
        ],
      );
      await manager.addFavorite(ep);

      await tester.pumpWidget(
        const MaterialApp(
          home: FavoritesScreen(),
        ),
      );

      expect(find.text('我的收藏 (Favorites)'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // badge count
      expect(find.text('【綜藝玩很大】高雄 世紀爭霸戰'), findsOneWidget);
    });
  });
}
