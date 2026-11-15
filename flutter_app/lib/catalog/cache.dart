import 'dart:convert';
import 'parser.dart';

class CachedCatalog {
  final String updatedAt;
  final List<CatalogEpisode> episodes;
  final String? error;

  CachedCatalog({
    required this.updatedAt,
    required this.episodes,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'updatedAt': updatedAt,
        'episodes': episodes.map((e) => e.toJson()).toList(),
        if (error != null) 'error': error,
      };

  factory CachedCatalog.fromJson(Map<String, dynamic> json) {
    final rawEps = json['episodes'];
    if (rawEps is! List) {
      return CachedCatalog(
        updatedAt: '',
        episodes: const [],
        error: 'bad-cache',
      );
    }
    return CachedCatalog(
      updatedAt: json['updatedAt'] as String? ?? '',
      episodes: rawEps.map((e) => CatalogEpisode.fromJson(e as Map<String, dynamic>)).toList(),
      error: json['error'] as String?,
    );
  }
}

class CatalogCache {
  static CachedCatalog createCache(List<CatalogEpisode> episodes, [String? updatedAt]) {
    return CachedCatalog(
      updatedAt: updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      episodes: episodes,
    );
  }

  static String serializeCache(CachedCatalog cache) {
    return json.encode(cache.toJson());
  }

  static CachedCatalog deserializeCache(String jsonStr) {
    try {
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      return CachedCatalog.fromJson(decoded);
    } catch (_) {
      return CachedCatalog(
        updatedAt: '',
        episodes: const [],
        error: 'bad-json',
      );
    }
  }

  static bool shouldRefresh(String updatedAt, int ttlMs, [int? nowMs]) {
    final current = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    try {
      final parsed = DateTime.parse(updatedAt).millisecondsSinceEpoch;
      return (current - parsed) > ttlMs;
    } catch (_) {
      return true;
    }
  }
}
