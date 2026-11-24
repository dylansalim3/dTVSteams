import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages recently searched keywords with local persistence.
class SearchHistoryManager extends ChangeNotifier {
  static final SearchHistoryManager _instance = SearchHistoryManager._internal();
  factory SearchHistoryManager() => _instance;
  SearchHistoryManager._internal();

  static const int maxHistoryCount = 10;
  static const List<String> defaultHotTags = [
    '憲哥',
    'KID',
    '澎湖',
    '飢餓遊戲',
    '金鐘',
    '日本',
    '週年',
    '黃隊',
  ];

  final List<String> _history = [];
  String? _storageFilePath;
  bool _isInitialized = false;

  List<String> get history => List.unmodifiable(_history);
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      _storageFilePath = '${appDocDir.path}/search_history.json';
      await _loadFromDisk();
    } catch (e) {
      debugPrint('[SearchHistoryManager] init error (using in-memory fallback): $e');
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> addQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _history.remove(trimmed);
    _history.insert(0, trimmed);
    if (_history.length > maxHistoryCount) {
      _history.removeRange(maxHistoryCount, _history.length);
    }

    notifyListeners();
    await _persist();
  }

  Future<void> removeQuery(String query) async {
    if (_history.remove(query)) {
      notifyListeners();
      await _persist();
    }
  }

  Future<void> clearHistory() async {
    if (_history.isNotEmpty) {
      _history.clear();
      notifyListeners();
      await _persist();
    }
  }

  Future<void> _loadFromDisk() async {
    if (_storageFilePath == null) return;
    try {
      final file = File(_storageFilePath!);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> list = jsonDecode(content);
          _history.clear();
          for (final item in list) {
            if (item is String && item.isNotEmpty) {
              _history.add(item);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SearchHistoryManager] loadFromDisk error: $e');
    }
  }

  Future<void> _persist() async {
    if (_storageFilePath == null) return;
    try {
      final file = File(_storageFilePath!);
      await file.writeAsString(jsonEncode(_history));
    } catch (e) {
      debugPrint('[SearchHistoryManager] persist error: $e');
    }
  }

  @visibleForTesting
  void clearForTesting() {
    _history.clear();
    _isInitialized = true;
    notifyListeners();
  }
}
