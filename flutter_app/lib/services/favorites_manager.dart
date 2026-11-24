import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../catalog/parser.dart';

class FavoriteRecord {
  final CatalogEpisode episode;
  final DateTime addedAt;

  FavoriteRecord({
    required this.episode,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'episode': episode.toJson(),
        'addedAt': addedAt.toIso8601String(),
      };

  factory FavoriteRecord.fromJson(Map<String, dynamic> json) => FavoriteRecord(
        episode: CatalogEpisode.fromJson(json['episode'] as Map<String, dynamic>),
        addedAt: json['addedAt'] != null
            ? DateTime.tryParse(json['addedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

class FavoritesManager extends ChangeNotifier {
  static final FavoritesManager _instance = FavoritesManager._internal();
  factory FavoritesManager() => _instance;
  FavoritesManager._internal();

  final Map<String, FavoriteRecord> _favorites = {};
  String? _storageFilePath;
  bool _isInitialized = false;

  Map<String, FavoriteRecord> get favorites => Map.unmodifiable(_favorites);
  List<CatalogEpisode> get favoriteEpisodes =>
      _favorites.values.map((f) => f.episode).toList().reversed.toList();
  int get count => _favorites.length;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      _storageFilePath = '${appDocDir.path}/favorites.json';
      await _loadFromDisk();
    } catch (e) {
      debugPrint('[FavoritesManager] init error (using in-memory fallback): $e');
    }
    _isInitialized = true;
    notifyListeners();
  }

  bool isFavorite(String episodeId) {
    return _favorites.containsKey(episodeId);
  }

  Future<bool> toggleFavorite(CatalogEpisode episode) async {
    if (isFavorite(episode.id)) {
      await removeFavorite(episode.id);
      return false;
    } else {
      await addFavorite(episode);
      return true;
    }
  }

  Future<void> addFavorite(CatalogEpisode episode) async {
    _favorites[episode.id] = FavoriteRecord(
      episode: episode,
      addedAt: DateTime.now(),
    );
    notifyListeners();
    await _persistToDisk();
  }

  Future<void> removeFavorite(String episodeId) async {
    if (_favorites.containsKey(episodeId)) {
      _favorites.remove(episodeId);
      notifyListeners();
      await _persistToDisk();
    }
  }

  Future<void> clearAll() async {
    _favorites.clear();
    notifyListeners();
    await _persistToDisk();
  }

  Future<void> _loadFromDisk() async {
    if (_storageFilePath == null) return;
    final file = File(_storageFilePath!);
    if (!await file.exists()) return;
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return;
      final decoded = jsonDecode(content);
      if (decoded is List) {
        _favorites.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final record = FavoriteRecord.fromJson(item);
            _favorites[record.episode.id] = record;
          }
        }
      }
    } catch (e) {
      debugPrint('[FavoritesManager] load error: $e');
    }
  }

  Future<void> _persistToDisk() async {
    if (_storageFilePath == null) return;
    try {
      final list = _favorites.values.map((f) => f.toJson()).toList();
      final content = jsonEncode(list);
      final tempFile = File('$_storageFilePath.tmp');
      await tempFile.writeAsString(content, flush: true);
      await tempFile.rename(_storageFilePath!);
    } catch (e) {
      debugPrint('[FavoritesManager] persist error: $e');
    }
  }
}
