import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PlaybackRecord {
  final String episodeId;
  final String partLabel;
  final int partIndex;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;

  PlaybackRecord({
    required this.episodeId,
    required this.partLabel,
    this.partIndex = 0,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });

  double get progress => durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => progress >= 0.90; // Watched >90% marks as completed

  String get positionFormatted => _formatMs(positionMs);
  String get durationFormatted => _formatMs(durationMs);

  static String _formatMs(int ms) {
    if (ms <= 0) return '00:00';
    final totalSec = ms ~/ 1000;
    final minutes = totalSec ~/ 60;
    final seconds = totalSec % 60;
    final hours = minutes ~/ 60;
    if (hours > 0) {
      final remMin = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${remMin.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'episodeId': episodeId,
        'partLabel': partLabel,
        'partIndex': partIndex,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PlaybackRecord.fromJson(Map<String, dynamic> json) => PlaybackRecord(
        episodeId: json['episodeId'] as String? ?? '',
        partLabel: json['partLabel'] as String? ?? 'Part 1',
        partIndex: (json['partIndex'] as num?)?.toInt() ?? 0,
        positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

class PlaybackHistoryManager extends ChangeNotifier {
  static final PlaybackHistoryManager _instance = PlaybackHistoryManager._internal();
  factory PlaybackHistoryManager() => _instance;
  PlaybackHistoryManager._internal();

  final Map<String, PlaybackRecord> _records = {};
  String? _storageFilePath;
  bool _isInitialized = false;
  DateTime? _lastSavedTime;

  Map<String, PlaybackRecord> get records => Map.unmodifiable(_records);
  bool get isInitialized => _isInitialized;

  String _buildKey(String episodeId, String partLabel) {
    final normPart = partLabel.toLowerCase().replaceAll(' ', '');
    return '${episodeId.trim()}_$normPart';
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _storageFilePath = '${docDir.path}/playback_history.json';
      final file = File(_storageFilePath!);
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final list = json.decode(content) as List<dynamic>;
          for (final raw in list) {
            final rec = PlaybackRecord.fromJson(raw as Map<String, dynamic>);
            _records[_buildKey(rec.episodeId, rec.partLabel)] = rec;
          }
        } catch (e) {
          debugPrint('Error loading playback history: $e');
        }
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('PlaybackHistoryManager init error: $e');
      _isInitialized = true;
    }
  }

  PlaybackRecord? getRecord(String episodeId, String partLabel) {
    final key = _buildKey(episodeId, partLabel);
    if (_records.containsKey(key)) return _records[key];

    // Fallback: match by date in episodeId
    final normPart = partLabel.toLowerCase().replaceAll(' ', '');
    final dateMatch = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(episodeId);
    if (dateMatch != null) {
      final date = dateMatch.group(0)!;
      for (final rec in _records.values) {
        if (rec.partLabel.toLowerCase().replaceAll(' ', '') == normPart &&
            rec.episodeId.contains(date)) {
          return rec;
        }
      }
    }
    return null;
  }

  double getEpisodeProgress(String episodeId, int totalParts) {
    if (totalParts <= 0) return 0.0;
    double sum = 0.0;
    for (int i = 1; i <= totalParts; i++) {
      final rec = getRecord(episodeId, 'Part $i');
      if (rec != null) {
        sum += rec.progress;
      }
    }
    return (sum / totalParts).clamp(0.0, 1.0);
  }

  bool isEpisodeCompleted(String episodeId, int totalParts) {
    if (totalParts <= 0) return false;
    for (int i = 1; i <= totalParts; i++) {
      final rec = getRecord(episodeId, 'Part $i');
      if (rec == null || !rec.isCompleted) return false;
    }
    return true;
  }

  Future<void> savePosition({
    required String episodeId,
    required String partLabel,
    required int partIndex,
    required int positionMs,
    required int durationMs,
    bool forcePersist = false,
  }) async {
    if (episodeId.isEmpty || durationMs <= 0) return;

    final record = PlaybackRecord(
      episodeId: episodeId,
      partLabel: partLabel,
      partIndex: partIndex,
      positionMs: positionMs,
      durationMs: durationMs,
      updatedAt: DateTime.now(),
    );

    final key = _buildKey(episodeId, partLabel);
    _records[key] = record;
    notifyListeners();

    // Throttle disk persistence (every 5 seconds or when forced on pause/dispose)
    final now = DateTime.now();
    if (forcePersist || _lastSavedTime == null || now.difference(_lastSavedTime!).inSeconds >= 5) {
      _lastSavedTime = now;
      await _persistToDisk();
    }
  }

  Future<void> clearRecord(String episodeId, String partLabel) async {
    final key = _buildKey(episodeId, partLabel);
    _records.remove(key);
    await _persistToDisk();
    notifyListeners();
  }

  Future<void> clearAllHistory() async {
    _records.clear();
    await _persistToDisk();
    notifyListeners();
  }

  Future<void> _persistToDisk() async {
    if (_storageFilePath == null) return;
    try {
      final file = File(_storageFilePath!);
      final list = _records.values.map((r) => r.toJson()).toList();
      await file.writeAsString(json.encode(list), flush: true);
    } catch (e) {
      debugPrint('Error saving playback history: $e');
    }
  }

  @visibleForTesting
  void addRecordForTesting(PlaybackRecord record) {
    _records[_buildKey(record.episodeId, record.partLabel)] = record;
    notifyListeners();
  }

  @visibleForTesting
  void clearForTesting() {
    _records.clear();
    notifyListeners();
  }
}
