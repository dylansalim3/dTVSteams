import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../catalog/parser.dart';

enum DownloadStatus { idle, downloading, paused, completed, failed }

class DownloadItem {
  final String episodeId;
  final String episodeTitle;
  final String showId;
  final String showName;
  final String partLabel;
  final String partUrl;
  final String localFilePath;
  final String date;
  int totalBytes;
  int downloadedBytes;
  DownloadStatus status;
  String? error;
  double speedBytesPerSec;

  DownloadItem({
    required this.episodeId,
    required this.episodeTitle,
    this.showId = '',
    this.showName = '',
    required this.partLabel,
    required this.partUrl,
    required this.localFilePath,
    required this.date,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.idle,
    this.error,
    this.speedBytesPerSec = 0.0,
  });

  double get progress => totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';

  String get etaString {
    if (speedBytesPerSec <= 0 || totalBytes <= downloadedBytes) return '';
    final remainingBytes = totalBytes - downloadedBytes;
    final remainingSec = (remainingBytes / speedBytesPerSec).round();
    if (remainingSec < 60) {
      return '剩餘約 $remainingSec 秒';
    } else if (remainingSec < 3600) {
      final m = remainingSec ~/ 60;
      final s = remainingSec % 60;
      return '剩餘約 $m 分 $s 秒';
    } else {
      final h = remainingSec ~/ 3600;
      final m = (remainingSec % 3600) ~/ 60;
      return '剩餘約 $h 小時 $m 分';
    }
  }

  Map<String, dynamic> toJson() => {
        'episodeId': episodeId,
        'episodeTitle': episodeTitle,
        'showId': showId,
        'showName': showName,
        'partLabel': partLabel,
        'partUrl': partUrl,
        'localFilePath': localFilePath,
        'date': date,
        'totalBytes': totalBytes,
        'downloadedBytes': downloadedBytes,
        'status': status.name,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    final title = json['episodeTitle'] as String? ?? '';
    final epId = json['episodeId'] as String? ?? '';
    final path = json['localFilePath'] as String? ?? '';
    var sId = json['showId'] as String? ?? '';
    var sName = json['showName'] as String? ?? '';
    if (sId.isEmpty) {
      sId = CatalogParser.detectShowId('$title $epId $path');
    }
    if (sName.isEmpty) {
      sName = CatalogParser.detectShowName('$title $epId $path $sId');
    }

    return DownloadItem(
      episodeId: epId,
      episodeTitle: title,
      showId: sId,
      showName: sName,
      partLabel: json['partLabel'] as String? ?? 'Part 1',
      partUrl: json['partUrl'] as String? ?? '',
      localFilePath: path,
      date: json['date'] as String? ?? '',
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.idle,
      ),
    );
  }
}

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final Map<String, DownloadItem> _items = {};
  final Map<String, http.Client> _activeClients = {};
  final Set<String> _inFlightStarts = {};
  String? _downloadDirectoryPath;
  bool _isInitialized = false;

  Map<String, DownloadItem> get items => Map.unmodifiable(_items);
  String get downloadDirectoryPath => _downloadDirectoryPath ?? '';
  bool get isInitialized => _isInitialized;

  List<DownloadItem> get activeDownloads {
    final seen = <String>{};
    final list = <DownloadItem>[];
    for (final item in _items.values) {
      if (item.status == DownloadStatus.downloading) {
        if (seen.add(item.localFilePath)) {
          list.add(item);
        }
      }
    }
    return list;
  }

  List<DownloadItem> get completedDownloads {
    final seen = <String>{};
    final list = <DownloadItem>[];
    for (final item in _items.values) {
      if (item.status == DownloadStatus.completed) {
        if (seen.add(item.localFilePath)) {
          list.add(item);
        }
      }
    }
    return list;
  }

  List<DownloadItem> get failedDownloads {
    final seen = <String>{};
    final list = <DownloadItem>[];
    for (final item in _items.values) {
      if (item.status == DownloadStatus.failed || item.status == DownloadStatus.paused) {
        if (seen.add(item.localFilePath)) {
          list.add(item);
        }
      }
    }
    return list;
  }

  String _buildKey(String episodeId, String partLabel) => '${episodeId}_$partLabel';

  String _normalizeId(String id) {
    var s = id.trim();
    try {
      s = Uri.decodeComponent(s);
    } catch (_) {}
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s.toLowerCase();
  }

  /// Unified matcher to locate a DownloadItem across various ID schemes (URL vs Date_Title)
  DownloadItem? _findItem(
    String episodeId,
    String partLabel, {
    String? showId,
    String? localFilePath,
    String? date,
    String? title,
  }) {
    final directKey = _buildKey(episodeId, partLabel);
    if (_items.containsKey(directKey)) {
      return _items[directKey];
    }

    final normPart = partLabel.toLowerCase().replaceAll(' ', '');

    // 1. Exact local file path match (most authoritative on disk)
    if (localFilePath != null && localFilePath.isNotEmpty) {
      for (final item in _items.values) {
        if (item.localFilePath == localFilePath) {
          _items[directKey] = item;
          return item;
        }
      }
    }

    // 2. Normalized episodeId match (URL percent-decode & trailing-slash agnostic)
    final normEpId = _normalizeId(episodeId);
    if (normEpId.isNotEmpty) {
      for (final item in _items.values) {
        if (item.partLabel.toLowerCase().replaceAll(' ', '') != normPart) continue;
        if (_normalizeId(item.episodeId) == normEpId) {
          _items[directKey] = item;
          return item;
        }
      }
    }

    // 3. Match by showId + date + partLabel (NEVER match date alone across different shows!)
    var effectiveShowId = (showId != null && showId.isNotEmpty)
        ? showId
        : CatalogParser.detectShowId('$episodeId ${title ?? ''}');

    String? epDate = date;
    if (epDate == null || epDate.isEmpty) {
      final match = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(episodeId);
      if (match != null) epDate = match.group(0);
    }

    if (epDate != null && epDate.isNotEmpty && effectiveShowId.isNotEmpty) {
      for (final item in _items.values) {
        if (item.partLabel.toLowerCase().replaceAll(' ', '') != normPart) continue;

        final itemShowId = item.showId.isNotEmpty
            ? item.showId
            : CatalogParser.detectShowId('${item.episodeTitle} ${item.episodeId} ${item.localFilePath}');

        // Strict guard: MUST belong to the SAME show!
        if (itemShowId.isNotEmpty && itemShowId != effectiveShowId) {
          continue;
        }

        if (item.date == epDate || item.episodeId.contains(epDate) || item.localFilePath.contains(epDate)) {
          _items[directKey] = item;
          return item;
        }
      }
    }

    return null;
  }

  @visibleForTesting
  void addItemForTesting(DownloadItem item) {
    _items[_buildKey(item.episodeId, item.partLabel)] = item;
    notifyListeners();
  }

  @visibleForTesting
  void clearForTesting() {
    _items.clear();
    _activeClients.clear();
    _inFlightStarts.clear();
    notifyListeners();
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${docDir.path}/dTVSteams_Downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      _downloadDirectoryPath = downloadDir.path;

      // 1. Load existing manifest.json if exists & deduplicate entries
      final manifestFile = File('${downloadDir.path}/manifest.json');
      if (await manifestFile.exists()) {
        try {
          final content = await manifestFile.readAsString();
          final list = json.decode(content) as List<dynamic>;
          final seenPaths = <String>{};
          for (final raw in list) {
            final item = DownloadItem.fromJson(raw as Map<String, dynamic>);
            final file = File(item.localFilePath);
            if (await file.exists()) {
              if (seenPaths.contains(item.localFilePath)) {
                // Skip duplicate entry for the exact same file
                continue;
              }
              seenPaths.add(item.localFilePath);

              final len = await file.length();
              item.downloadedBytes = len;
              if (item.totalBytes <= 0) item.totalBytes = len;
              item.status = DownloadStatus.completed;

              final key = _buildKey(item.episodeId, item.partLabel);
              _items[key] = item;
            }
          }
        } catch (e) {
          debugPrint('Error parsing manifest: $e');
        }
      }

      // 2. Scan download directory for any unindexed mp4 files on disk
      await _scanDirectoryForFiles(downloadDir);

      // 3. Immediately persist clean, deduplicated manifest to disk
      await _saveManifest();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('DownloadManager init error: $e');
      _isInitialized = true;
    }
  }

  /// Scans download directory to register any video files on disk
  Future<void> _scanDirectoryForFiles(Directory downloadDir) async {
    try {
      final entities = downloadDir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.mp4')) {
          final fileName = entity.uri.pathSegments.last;
          final fileSize = entity.lengthSync();
          if (fileSize <= 0) continue;

          // Parse pattern: ({showId}_)?{date}_{sanitizedTitle}_{partLabel}.mp4
          final matchWithShow = RegExp(r'^([a-z_]+)_([0-9]{4}-[0-9]{2}-[0-9]{2})_(.+)_(Part\s*\d+)\.mp4$', caseSensitive: false)
              .firstMatch(fileName);
          final matchWithoutShow = RegExp(r'^([0-9]{4}-[0-9]{2}-[0-9]{2})_(.+)_(Part\s*\d+)\.mp4$', caseSensitive: false)
              .firstMatch(fileName);

          String showId = '';
          String date = '';
          String title = fileName.replaceAll('.mp4', '');
          String partLabel = 'Part 1';

          if (matchWithShow != null) {
            showId = matchWithShow.group(1) ?? '';
            date = matchWithShow.group(2) ?? '';
            title = (matchWithShow.group(3) ?? '').replaceAll('_', ' ');
            partLabel = (matchWithShow.group(4) ?? 'Part 1').replaceAll('_', ' ');
          } else if (matchWithoutShow != null) {
            date = matchWithoutShow.group(1) ?? '';
            title = (matchWithoutShow.group(2) ?? '').replaceAll('_', ' ');
            partLabel = (matchWithoutShow.group(3) ?? 'Part 1').replaceAll('_', ' ');
            showId = CatalogParser.detectShowId(title);
          }

          final showName = CatalogParser.detectShowName('$title $showId');

          // Check if already registered by localFilePath or date+part
          final existing = _findItem(
            '',
            partLabel,
            showId: showId,
            localFilePath: entity.path,
            date: date,
            title: title,
          );
          if (existing != null) {
            continue;
          }

          final epId = date.isNotEmpty ? '${date}_$title' : title;
          final item = DownloadItem(
            episodeId: epId,
            episodeTitle: title,
            showId: showId,
            showName: showName,
            partLabel: partLabel,
            partUrl: '',
            localFilePath: entity.path,
            date: date,
            totalBytes: fileSize,
            downloadedBytes: fileSize,
            status: DownloadStatus.completed,
          );

          _items[_buildKey(epId, partLabel)] = item;
        }
      }
    } catch (e) {
      debugPrint('Scan directory error: $e');
    }
  }

  Future<void> refreshDisk() async {
    if (_downloadDirectoryPath == null) return;
    await _scanDirectoryForFiles(Directory(_downloadDirectoryPath!));
    await _saveManifest();
    notifyListeners();
  }

  Future<void> _saveManifest() async {
    if (_downloadDirectoryPath == null) return;
    try {
      final manifestFile = File('$_downloadDirectoryPath/manifest.json');
      final seen = <String>{};
      final list = <Map<String, dynamic>>[];
      for (final item in _items.values) {
        if (item.status == DownloadStatus.completed) {
          if (seen.add(item.localFilePath)) {
            list.add(item.toJson());
          }
        }
      }
      manifestFile.writeAsStringSync(json.encode(list), flush: true);
    } catch (e) {
      debugPrint('Save manifest error: $e');
    }
  }

  bool isDownloaded(String episodeId, String partLabel, {String? showId, String? title}) {
    final item = _findItem(episodeId, partLabel, showId: showId, title: title);
    if (item == null || item.status != DownloadStatus.completed) return false;
    return File(item.localFilePath).existsSync();
  }

  bool isDownloading(String episodeId, String partLabel, {String? showId, String? title}) {
    final item = _findItem(episodeId, partLabel, showId: showId, title: title);
    return item?.status == DownloadStatus.downloading;
  }

  DownloadItem? getItem(String episodeId, String partLabel, {String? showId, String? title}) {
    return _findItem(episodeId, partLabel, showId: showId, title: title);
  }

  File? getLocalFile(String episodeId, String partLabel, {String? showId, String? title}) {
    final item = _findItem(episodeId, partLabel, showId: showId, title: title);
    if (item != null && item.status == DownloadStatus.completed) {
      final f = File(item.localFilePath);
      if (f.existsSync()) return f;
    }
    return null;
  }

  void cancelDownload(String episodeId, String partLabel, {String? showId, String? title}) {
    final item = _findItem(episodeId, partLabel, showId: showId, title: title);
    final key = _buildKey(episodeId, partLabel);
    _activeClients.remove(key)?.close();
    if (item != null) {
      _activeClients.remove(_buildKey(item.episodeId, item.partLabel))?.close();
      if (item.status == DownloadStatus.downloading) {
        item.status = DownloadStatus.paused;
        item.speedBytesPerSec = 0;
        notifyListeners();
      }
    }
  }

  Future<void> finalizeDownload(String episodeId, String partLabel, {String? showId, String? title}) async {
    final item = _findItem(episodeId, partLabel, showId: showId, title: title);
    cancelDownload(episodeId, partLabel, showId: showId, title: title);

    if (item != null) {
      final file = File(item.localFilePath);
      if (file.existsSync()) {
        final len = file.lengthSync();
        if (len > 0) {
          item.downloadedBytes = len;
          item.totalBytes = len;
          item.status = DownloadStatus.completed;
          await _saveManifest();
          notifyListeners();
        }
      }
    }
  }

  Future<void> startDownload(CatalogEpisode episode, CatalogPart part, {int? maxBytes}) async {
    // Synchronous mutex to prevent race condition from double-tapping or multiple triggers
    final startLockKey = '${episode.date}_${episode.id}_${part.label}';
    if (_inFlightStarts.contains(startLockKey)) {
      debugPrint('startDownload already in flight for $startLockKey');
      return;
    }
    _inFlightStarts.add(startLockKey);

    try {
      await init();

      final showId = episode.showId.isNotEmpty ? episode.showId : CatalogParser.detectShowId('${episode.title} ${episode.id}');
      final showName = episode.showName.isNotEmpty ? episode.showName : CatalogParser.detectShowName('${episode.title} ${episode.id}');

      final sanitizedTitle = episode.title
          .replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final showPrefix = showId.isNotEmpty ? '${showId}_' : '';
      final filename = '$showPrefix${episode.date}_${sanitizedTitle}_${part.label}.mp4';
      final targetPath = '$_downloadDirectoryPath/$filename';
      final targetFile = File(targetPath);

      // Check if already downloaded or existing file on disk is complete
      final existingItem = _findItem(
        episode.id,
        part.label,
        showId: showId,
        localFilePath: targetPath,
        date: episode.date,
        title: episode.title,
      );
      if (isDownloaded(episode.id, part.label, showId: showId, title: episode.title) ||
          (existingItem != null && existingItem.status == DownloadStatus.completed && targetFile.existsSync()) ||
          (targetFile.existsSync() && targetFile.lengthSync() > 1024 * 1024 && existingItem?.status == DownloadStatus.completed)) {
        debugPrint('Episode ${episode.title} - ${part.label} is already downloaded.');
        if (existingItem != null) {
          existingItem.status = DownloadStatus.completed;
          _items[_buildKey(episode.id, part.label)] = existingItem;
          await _saveManifest();
          notifyListeners();
        }
        return;
      }

      if (isDownloading(episode.id, part.label, showId: showId, title: episode.title)) {
        debugPrint('Already downloading: ${episode.id} - ${part.label}');
        return;
      }

      final key = _buildKey(episode.id, part.label);
      int existingBytes = 0;
      if (targetFile.existsSync()) {
        existingBytes = targetFile.lengthSync();
      }

      var downloadItem = existingItem ?? _items[key];
      if (downloadItem == null) {
        downloadItem = DownloadItem(
          episodeId: episode.id,
          episodeTitle: episode.title,
          showId: showId,
          showName: showName,
          partLabel: part.label,
          partUrl: part.url,
          localFilePath: targetPath,
          date: episode.date,
          downloadedBytes: existingBytes,
          status: DownloadStatus.downloading,
        );
        _items[key] = downloadItem;
      } else {
        downloadItem.status = DownloadStatus.downloading;
        downloadItem.downloadedBytes = existingBytes;
        downloadItem.error = null;
        _items[key] = downloadItem;
      }
      final DownloadItem currentItem = downloadItem;
      notifyListeners();
      notifyListeners();

      final client = http.Client();
      _activeClients[key] = client;

      try {
        // 1. Resolve live direct MP4 stream URL
        String? streamUrl;
        if (part.url.isNotEmpty) {
          try {
            final res = await http.get(
              Uri.parse(part.url),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Linux; Android 14; sdk_gphone64_x86_64)',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              },
            ).timeout(const Duration(seconds: 8));
            if (res.statusCode == 200) {
              streamUrl = CatalogParser.parseStreamUrl(res.body);
            }
          } catch (_) {}
        }

        if (streamUrl == null || streamUrl.isEmpty) {
          if (part.streamUrl.isNotEmpty) {
            streamUrl = part.streamUrl;
          } else if (part.fallbackStreamUrl.isNotEmpty) {
            streamUrl = part.fallbackStreamUrl;
          }
        }

        if (streamUrl == null || streamUrl.isEmpty) {
          throw Exception('無法取得下載串流權杖');
        }

        // 2. Prepare HTTP request with Range support for resuming
        final request = http.Request('GET', Uri.parse(streamUrl));
        request.headers.addAll({
          'Referer': 'https://srgoideas.com/',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; sdk_gphone64_x86_64)',
        });

        if (existingBytes > 0) {
          request.headers['Range'] = 'bytes=$existingBytes-';
        }

        final streamedResponse = await client.send(request);

        if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 206) {
          throw Exception('下載連線失敗: HTTP ${streamedResponse.statusCode}');
        }

        FileMode writeMode = FileMode.write;
        int startOffset = 0;

        if (streamedResponse.statusCode == 206) {
          // Resuming from partial download
          writeMode = FileMode.append;
          startOffset = existingBytes;
          currentItem.totalBytes = startOffset + (streamedResponse.contentLength ?? 0);
        } else {
          // Starting fresh
          writeMode = FileMode.write;
          startOffset = 0;
          currentItem.totalBytes = streamedResponse.contentLength ?? 0;
        }

        final sink = targetFile.openWrite(mode: writeMode);
        int received = startOffset;
        var lastNotifyTime = DateTime.now();
        int lastNotifyBytes = received;

        late StreamSubscription<List<int>> subscription;
        final completer = Completer<void>();

        subscription = streamedResponse.stream.listen(
          (chunk) {
            sink.add(chunk);
            received += chunk.length;
            currentItem.downloadedBytes = received;

            final now = DateTime.now();
            final ms = now.difference(lastNotifyTime).inMilliseconds;
            // Throttle updates: every 400ms or 500KB
            if (ms >= 400 || (received - lastNotifyBytes) > 500 * 1024) {
              if (ms > 0) {
                currentItem.speedBytesPerSec = (received - lastNotifyBytes) / (ms / 1000.0);
              }
              lastNotifyTime = now;
              lastNotifyBytes = received;
              notifyListeners();
            }

            if (maxBytes != null && received >= maxBytes) {
              subscription.cancel();
              if (!completer.isCompleted) completer.complete();
            }
          },
          onError: (err) {
            if (!completer.isCompleted) completer.completeError(err);
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );

        await completer.future;

        await sink.flush();
        await sink.close();
        client.close();
        _activeClients.remove(key);

        currentItem.downloadedBytes = received;
        if (currentItem.totalBytes <= 0 || received >= currentItem.totalBytes) {
          currentItem.totalBytes = received;
        }
        currentItem.speedBytesPerSec = 0.0;
        currentItem.status = DownloadStatus.completed;
        await _saveManifest();
        notifyListeners();
      } catch (e) {
        debugPrint('Download interrupted/failed: $e');
        _activeClients.remove(key);
        currentItem.speedBytesPerSec = 0.0;

        // Check if task was paused by user or completed via maxBytes
        if (currentItem.status != DownloadStatus.paused && currentItem.status != DownloadStatus.completed) {
          currentItem.status = DownloadStatus.failed;
          currentItem.error = e.toString();
        }
        // Note: We preserve the partial file on disk so the user can RESUME anytime!
        notifyListeners();
      }
    } finally {
      _inFlightStarts.remove(startLockKey);
    }
  }

  Future<void> deleteDownload(String episodeId, String partLabel, {String? showId, String? title}) async {
    final item = _findItem(episodeId, partLabel, showId: showId, title: title);
    cancelDownload(episodeId, partLabel, showId: showId, title: title);

    if (item != null) {
      final filePath = item.localFilePath;
      final file = File(filePath);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
      _items.removeWhere((k, v) => v.localFilePath == filePath || v == item);
      await _saveManifest();
      notifyListeners();
    }
  }

  /// One-click batch download all un-downloaded parts of an episode sequentially
  Future<void> startBatchDownload(CatalogEpisode episode) async {
    for (final part in episode.parts) {
      if (!isDownloaded(episode.id, part.label, showId: episode.showId, title: episode.title) &&
          !isDownloading(episode.id, part.label, showId: episode.showId, title: episode.title)) {
        await startDownload(episode, part);
      }
    }
  }

  /// Purges all downloaded files and clears the manifest
  Future<void> deleteAllDownloads() async {
    final clients = List<http.Client>.from(_activeClients.values);
    for (final c in clients) {
      c.close();
    }
    _activeClients.clear();

    final filePaths = _items.values.map((e) => e.localFilePath).toSet();
    for (final path in filePaths) {
      try {
        final f = File(path);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (_) {}
    }

    _items.clear();
    await _saveManifest();
    notifyListeners();
  }

  /// Auto-clean single watched downloaded file to free up storage
  Future<bool> cleanupWatchedDownload(String episodeId, String partLabel, {String? showId, String? title}) async {
    final item = _findItem(episodeId, partLabel, showId: showId, title: title);
    if (item != null && item.status == DownloadStatus.completed) {
      await deleteDownload(episodeId, partLabel, showId: showId, title: title);
      return true;
    }
    return false;
  }

  int get totalDownloadedBytes {
    final seen = <String>{};
    int total = 0;
    for (final item in _items.values) {
      if (item.status == DownloadStatus.completed || item.status == DownloadStatus.downloading) {
        if (seen.add(item.localFilePath)) {
          total += item.downloadedBytes;
        }
      }
    }
    return total;
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes > 0) ? (bytes.bitLength - 1) ~/ 10 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    final numVal = bytes / (1 << (i * 10));
    return '${numVal.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 KB/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}
