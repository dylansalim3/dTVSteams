import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/catalog/cache.dart';

void main() {
  group('CatalogParser (Pure Dart native port of catalog-core)', () {
    test('parseList returns 10 items from fixture', () {
      final file = File('test/fixtures/list.html');
      final html = file.readAsStringSync();
      final list = CatalogParser.parseList(html);

      expect(list.length, 10);
      expect(list.first.title, contains('2026-10-04 嘉義 命運奪壘賽'));
      expect(list.first.date, '2026-10-04');
      expect(list.first.url, 'https://srgoideas.com/ep1/');
    });

    test('parseParts returns 3 parts from fixture', () {
      final file = File('test/fixtures/episode.html');
      final html = file.readAsStringSync();
      final parts = CatalogParser.parseParts(html, 'https://srgoideas.com/ep1/');

      expect(parts.length, 3);
      expect(parts[0].label, 'Part 1');
      expect(parts[0].url, 'https://srgoideas.com/ep1/');
      expect(parts[1].label, 'Part 2');
      expect(parts[1].url, 'https://srgoideas.com/ep1/2/');
      expect(parts[2].label, 'Part 3');
      expect(parts[2].url, 'https://srgoideas.com/ep1/3/');
    });

    test('parseStreamUrl extracts video mp4 src', () {
      final file = File('test/fixtures/episode.html');
      final html = file.readAsStringSync();
      final streamUrl = CatalogParser.parseStreamUrl(html);

      expect(streamUrl, 'https://example.xyz/vplay-001.mp4?st=abc&e=123');
    });
  });

  group('CatalogCache (Pure Dart native port of cache.ts)', () {
    test('createCache and serialize/deserialize cache', () {
      final episodes = [
        CatalogEpisode(
          id: '1',
          title: 'Test Episode',
          date: '2026-11-13',
          url: 'https://example.com/1',
        ),
      ];

      final cache = CatalogCache.createCache(episodes, '2026-11-13T00:00:00.000Z');
      final jsonStr = CatalogCache.serializeCache(cache);
      final restored = CatalogCache.deserializeCache(jsonStr);

      expect(restored.episodes.length, 1);
      expect(restored.episodes.first.title, 'Test Episode');
      expect(restored.updatedAt, '2026-11-13T00:00:00.000Z');
      expect(restored.error, isNull);
    });

    test('shouldRefresh checks TTL correctly', () {
      const now = 1000000000000;
      final past = DateTime.fromMillisecondsSinceEpoch(now - 100000).toIso8601String();
      final recent = DateTime.fromMillisecondsSinceEpoch(now - 10000).toIso8601String();

      expect(CatalogCache.shouldRefresh(past, 50000, now), isTrue);
      expect(CatalogCache.shouldRefresh(recent, 50000, now), isFalse);
    });
  });
}
