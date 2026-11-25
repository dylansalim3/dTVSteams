import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../catalog/parser.dart';
import 'settings_manager.dart';

enum DownloadStatus { idle, downloading, paused, completed, failed }

class DownloadItem {
  final String episodeId;
  final String episodeTitle;
  final String showId;
  final String showName;
  final String partLabel;
  final String partUrl;
  String localFilePath;
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
        if (error != null && error!.isNotEmpty) 'error': error,
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
      error: json['error'] as String?,
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

  bool get isUsingCustomDirectory {
    final custom = SettingsManager().customDownloadPath;
    return custom != null && custom.isNotEmpty;
  }

  Future<String> getDefaultDownloadDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    return '${docDir.path}/dTVSteams_Downloads';
  }

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

  @visibleForTesting
  void setDirectoryForTesting(String path) {
    _downloadDirectoryPath = path;
    _isInitialized = true;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await SettingsManager().init();
      final defaultPath = await getDefaultDownloadDirectory();
      final customPath = SettingsManager().customDownloadPath;

      Directory downloadDir;
      if (customPath != null && customPath.isNotEmpty) {
        try {
          downloadDir = Directory(customPath);
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
        } catch (e) {
          debugPrint('DownloadManager custom dir failed, fallback: $e');
          downloadDir = Directory(defaultPath);
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
        }
      } else {
        downloadDir = Directory(defaultPath);
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
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
            final dedupKey = item.localFilePath.isNotEmpty
                ? item.localFilePath
                : _buildKey(item.episodeId, item.partLabel);
            if (!seenPaths.add(dedupKey)) {
              continue;
            }

            final file = item.localFilePath.isNotEmpty ? File(item.localFilePath) : null;
            final exists = file != null && await file.exists();
            if (item.status == DownloadStatus.failed || item.status == DownloadStatus.paused) {
              item.downloadedBytes = exists ? await file.length() : 0;
              _items[_buildKey(item.episodeId, item.partLabel)] = item;
            } else if (exists) {
              final len = await file.length();
              if (len <= 0) continue;
              item.downloadedBytes = len;
              if (item.totalBytes <= 0) item.totalBytes = len;
              item.status = DownloadStatus.completed;
              _items[_buildKey(item.episodeId, item.partLabel)] = item;
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
        if (item.status == DownloadStatus.completed ||
            item.status == DownloadStatus.failed ||
            item.status == DownloadStatus.paused) {
          final dedupKey = item.localFilePath.isNotEmpty
              ? item.localFilePath
              : _buildKey(item.episodeId, item.partLabel);
          if (seen.add(dedupKey)) {
            list.add(item.toJson());
          }
        }
      }
      manifestFile.writeAsStringSync(json.encode(list), flush: true);
    } catch (e) {
      debugPrint('Save manifest error: $e');
    }
  }

  /// Migrates all downloaded videos and manifest to [targetPath].
  /// Returns the count of files successfully migrated.
  Future<int> migrateDownloadDirectory(String targetPath) async {
    await init();
    final defaultPath = await getDefaultDownloadDirectory();

    final targetDir = Directory(targetPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final oldDirPath = _downloadDirectoryPath;
    if (oldDirPath == null || oldDirPath == targetPath) {
      if (targetPath == defaultPath) {
        await SettingsManager().setCustomDownloadPath(null);
      } else {
        await SettingsManager().setCustomDownloadPath(targetPath);
      }
      notifyListeners();
      return 0;
    }

    final oldDir = Directory(oldDirPath);
    int migratedCount = 0;

    // 1. Migrate items tracked in memory
    for (final item in _items.values) {
      final oldFile = File(item.localFilePath);
      final fileName = oldFile.uri.pathSegments.isNotEmpty
          ? oldFile.uri.pathSegments.last
          : item.localFilePath.split(Platform.pathSeparator).last;
      final newFilePath = '$targetPath/$fileName';
      final newFile = File(newFilePath);

      if (await oldFile.exists()) {
        try {
          if (!await newFile.exists() || await newFile.length() != await oldFile.length()) {
            await oldFile.copy(newFilePath);
          }
          if (await newFile.exists() && await newFile.length() == await oldFile.length()) {
            try {
              await oldFile.delete();
            } catch (_) {}
            item.localFilePath = newFilePath;
            migratedCount++;
          }
        } catch (e) {
          debugPrint('Error migrating item ${oldFile.path}: $e');
        }
      } else {
        item.localFilePath = newFilePath;
      }
    }

    // 2. Scan old directory for any unindexed .mp4 files on disk and move them
    if (await oldDir.exists()) {
      try {
        final entities = oldDir.listSync();
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.mp4')) {
            final fileName = entity.uri.pathSegments.last;
            final newFilePath = '$targetPath/$fileName';
            final newFile = File(newFilePath);
            try {
              if (!await newFile.exists()) {
                await entity.copy(newFilePath);
              }
              if (await newFile.exists()) {
                await entity.delete();
              }
            } catch (e) {
              debugPrint('Error moving unindexed file ${entity.path}: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error scanning oldDir during migration: $e');
      }
    }

    // 3. Update active directory path
    _downloadDirectoryPath = targetPath;

    // 4. Save manifest in new directory
    await _saveManifest();

    // 5. Remove old manifest file
    try {
      final oldManifest = File('$oldDirPath/manifest.json');
      if (await oldManifest.exists()) {
        await oldManifest.delete();
      }
    } catch (_) {}

    // 6. Persist custom path in SettingsManager
    if (targetPath == defaultPath) {
      await SettingsManager().setCustomDownloadPath(null);
    } else {
      await SettingsManager().setCustomDownloadPath(targetPath);
    }

    // 7. Rescan the new directory to ensure all files are registered
    await _scanDirectoryForFiles(targetDir);
    await _saveManifest();

    notifyListeners();
    return migratedCount;
  }

  /// Resets download storage back to the default app documents directory.
  Future<int> resetToDefaultDownloadDirectory() async {
    final defaultPath = await getDefaultDownloadDirectory();
    return await migrateDownloadDirectory(defaultPath);
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

  bool isFailed(String episodeId, String partLabel, {String? showId, String? title}) {
    final item = _findItem(episodeId, partLabel, showId: showId, title: title);
    return item?.status == DownloadStatus.failed || item?.status == DownloadStatus.paused;
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

  bool _isValidPartialFile(File file) {
    if (!file.existsSync()) return false;
    final len = file.lengthSync();
    if (len < 1024) return false;
    try {
      final raf = file.openSync(mode: FileMode.read);
      try {
        final headerBytes = raf.readSync(64);
        final head = String.fromCharCodes(headerBytes).trimLeft().toLowerCase();
        if (head.startsWith('<html') ||
            head.startsWith('<!doc') ||
            head.startsWith('<?xml') ||
            head.startsWith('{')) {
          return false;
        }
      } finally {
        raf.closeSync();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  int _deleteFileQuietly(File file) {
    if (!file.existsSync()) return 0;
    try {
      final len = file.lengthSync();
      file.deleteSync();
      return len;
    } catch (_) {
      return 0;
    }
  }

  String _formatDownloadError(Object err) {
    if (err is _DownloadHttpException) {
      if (err.statusCode == 403 || err.statusCode == 410) {
        return '下載連結已失效 (HTTP ${err.statusCode})，請重試以重新取得網址';
      }
      if (err.statusCode == 404) {
        return '伺服器找不到此影片檔案 (HTTP 404)';
      }
      if (err.statusCode == 416) {
        return '續傳範圍無效 (HTTP 416)，請重試從頭下載';
      }
      return '伺服器連線異常 (HTTP ${err.statusCode})';
    }
    if (err is TimeoutException) {
      return '下載連線逾時，請檢查網路狀態後重試';
    }
    if (err is SocketException) {
      return '網路連線中斷，請確認連線後重試';
    }
    if (err is FileSystemException) {
      final msg = err.message.toLowerCase();
      if (msg.contains('space') || err.osError?.errorCode == 28) {
        return '裝置儲存空間不足，請釋出空間後再試';
      }
      return '無法寫入儲存空間：${err.message}';
    }
    final raw = err.toString().replaceFirst('Exception: ', '');
    return raw.isNotEmpty ? raw : '下載失敗，請稍後重試';
  }

  bool _shouldRetryError(Object err) {
    if (err is FileSystemException) {
      final msg = err.message.toLowerCase();
      if (msg.contains('space') || err.osError?.errorCode == 28) return false;
    }
    if (err is _DownloadHttpException) {
      return err.statusCode == 416 ||
          err.statusCode == 403 ||
          err.statusCode == 410 ||
          err.statusCode >= 500 ||
          err.statusCode == 429;
    }
    return err is TimeoutException || err is SocketException || err is HttpException;
  }

  Future<bool> startDownload(
    CatalogEpisode episode,
    CatalogPart part, {
    int? maxBytes,
    http.Client? client,
    Duration retryDelay = const Duration(milliseconds: 600),
  }) async {
    // Synchronous mutex to prevent race condition from double-tapping or multiple triggers
    final startLockKey = '${episode.date}_${episode.id}_${part.label}';
    if (_inFlightStarts.contains(startLockKey)) {
      debugPrint('startDownload already in flight for $startLockKey');
      return false;
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
          existingItem.error = null;
          _items[_buildKey(episode.id, part.label)] = existingItem;
          await _saveManifest();
          notifyListeners();
        }
        return true;
      }

      if (isDownloading(episode.id, part.label, showId: showId, title: episode.title)) {
        debugPrint('Already downloading: ${episode.id} - ${part.label}');
        return false;
      }

      final key = _buildKey(episode.id, part.label);
      if (targetFile.existsSync() && !_isValidPartialFile(targetFile)) {
        _deleteFileQuietly(targetFile);
      }
      int existingBytes = targetFile.existsSync() ? targetFile.lengthSync() : 0;

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

      const int maxAttempts = 3;
      Object? lastError;

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        if (currentItem.status == DownloadStatus.paused) {
          return false;
        }

        final activeClient = client ?? http.Client();
        _activeClients[key] = activeClient;
        IOSink? sink;

        try {
          // 1. Resolve live direct MP4 stream URL (fresh resolve on retry handles expired CDN tokens)
          String? streamUrl;
          if (part.url.isNotEmpty) {
            try {
              final res = await activeClient
                  .get(
                    Uri.parse(part.url),
                    headers: {
                      'User-Agent': 'Mozilla/5.0 (Linux; Android 14; sdk_gphone64_x86_64)',
                      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    },
                  )
                  .timeout(const Duration(seconds: 8));
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
            throw Exception('無法取得下載串流位址');
          }

          // Re-check partial file validity before sending Range request
          if (targetFile.existsSync() && !_isValidPartialFile(targetFile)) {
            _deleteFileQuietly(targetFile);
            existingBytes = 0;
            currentItem.downloadedBytes = 0;
          } else {
            existingBytes = targetFile.existsSync() ? targetFile.lengthSync() : 0;
          }

          final request = http.Request('GET', Uri.parse(streamUrl));
          request.headers.addAll({
            'Referer': 'https://srgoideas.com/',
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14; sdk_gphone64_x86_64)',
          });
          if (existingBytes > 0) {
            request.headers['Range'] = 'bytes=$existingBytes-';
          }

          final streamedResponse = await activeClient.send(request).timeout(const Duration(seconds: 20));

          if (streamedResponse.statusCode == 416) {
            // Partial file exceeds/mismatches remote content length: clear partial and restart cleanly from 0
            await streamedResponse.stream.drain<void>().catchError((_) {});
            _deleteFileQuietly(targetFile);
            existingBytes = 0;
            currentItem.downloadedBytes = 0;
            currentItem.totalBytes = 0;
            throw const _DownloadHttpException(416);
          }

          if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 206) {
            await streamedResponse.stream.drain<void>().catchError((_) {});
            throw _DownloadHttpException(streamedResponse.statusCode);
          }

          final FileMode writeMode = streamedResponse.statusCode == 206 ? FileMode.append : FileMode.write;
          final int startOffset = streamedResponse.statusCode == 206 ? existingBytes : 0;
          if (streamedResponse.statusCode == 206) {
            currentItem.totalBytes = startOffset + (streamedResponse.contentLength ?? 0);
          } else {
            currentItem.totalBytes = streamedResponse.contentLength ?? 0;
          }

          sink = targetFile.openWrite(mode: writeMode);
          int received = startOffset;
          var lastNotifyTime = DateTime.now();
          int lastNotifyBytes = received;

          late StreamSubscription<List<int>> subscription;
          final completer = Completer<void>();

          subscription = streamedResponse.stream.listen(
            (chunk) {
              sink?.add(chunk);
              received += chunk.length;
              currentItem.downloadedBytes = received;

              final now = DateTime.now();
              final ms = now.difference(lastNotifyTime).inMilliseconds;
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
          sink = null;
          _activeClients.remove(key);
          if (client == null) {
            activeClient.close();
          }

          currentItem.downloadedBytes = received;
          if (currentItem.totalBytes <= 0 || received >= currentItem.totalBytes) {
            currentItem.totalBytes = received;
          }
          currentItem.speedBytesPerSec = 0.0;
          currentItem.error = null;
          currentItem.status = DownloadStatus.completed;
          await _saveManifest();
          notifyListeners();
          return true;
        } catch (e) {
          lastError = e;
          debugPrint('Download attempt $attempt/$maxAttempts failed: $e');
          try {
            await sink?.close();
          } catch (_) {}
          _activeClients.remove(key);
          if (client == null) {
            try {
              activeClient.close();
            } catch (_) {}
          }
          currentItem.speedBytesPerSec = 0.0;

          if (currentItem.status == DownloadStatus.paused) {
            await _saveManifest();
            notifyListeners();
            return false;
          }

          if (attempt < maxAttempts && _shouldRetryError(e)) {
            if (retryDelay > Duration.zero) {
              await Future.delayed(retryDelay * attempt);
            }
            continue;
          }
          break;
        }
      }

      if (currentItem.status != DownloadStatus.paused && currentItem.status != DownloadStatus.completed) {
        currentItem.status = DownloadStatus.failed;
        currentItem.error = _formatDownloadError(lastError ?? Exception('未知錯誤'));
        currentItem.downloadedBytes = targetFile.existsSync() ? targetFile.lengthSync() : 0;
        await _saveManifest();
        notifyListeners();
      }
      return false;
    } finally {
      _inFlightStarts.remove(startLockKey);
    }
  }

  Future<int> deleteDownload(String episodeId, String partLabel, {String? showId, String? title}) async {
    final item = _findItem(episodeId, partLabel, showId: showId, title: title);
    cancelDownload(episodeId, partLabel, showId: showId, title: title);

    int freedBytes = 0;
    if (item != null) {
      final filePath = item.localFilePath;
      if (filePath.isNotEmpty) {
        freedBytes += _deleteFileQuietly(File(filePath));
        freedBytes += _deleteFileQuietly(File('$filePath.tmp'));
      }
      _items.removeWhere((k, v) =>
          v == item || (filePath.isNotEmpty && v.localFilePath == filePath));
      await _saveManifest();
      notifyListeners();
    }
    return freedBytes;
  }

  /// Deletes all parts (completed, downloading, paused, failed, and partial files) for [episode].
  /// Returns the total freed disk bytes.
  Future<int> deleteEpisodeDownloads(CatalogEpisode episode) async {
    int freedBytes = 0;
    final showId = episode.showId.isNotEmpty
        ? episode.showId
        : CatalogParser.detectShowId('${episode.title} ${episode.id}');

    for (final p in episode.parts) {
      final item = _findItem(episode.id, p.label, showId: showId, title: episode.title);
      if (item != null) {
        freedBytes += await deleteDownload(
          episode.id,
          p.label,
          showId: showId,
          title: episode.title,
        );
      }
    }

    // Catch any tracked items whose partLabel wasn't in episode.parts
    final remainingKeys = <String>[];
    final normEpId = _normalizeId(episode.id);
    for (final entry in _items.entries) {
      final it = entry.value;
      final sameId = _normalizeId(it.episodeId) == normEpId || it.episodeId == episode.id;
      final sameShowDate = showId.isNotEmpty &&
          it.showId == showId &&
          episode.date.isNotEmpty &&
          it.date == episode.date;
      if (sameId || sameShowDate) {
        remainingKeys.add(entry.key);
      }
    }
    for (final k in remainingKeys) {
      final it = _items[k];
      if (it != null) {
        freedBytes += await deleteDownload(it.episodeId, it.partLabel, showId: it.showId, title: it.episodeTitle);
      }
    }

    return freedBytes;
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

  /// Purges all downloaded/partial/failed files and clears the manifest.
  /// Returns total freed disk bytes.
  Future<int> deleteAllDownloads() async {
    final clients = List<http.Client>.from(_activeClients.values);
    for (final c in clients) {
      try {
        c.close();
      } catch (_) {}
    }
    _activeClients.clear();

    int freedBytes = 0;
    final filePaths = _items.values.map((e) => e.localFilePath).where((p) => p.isNotEmpty).toSet();
    for (final path in filePaths) {
      freedBytes += _deleteFileQuietly(File(path));
      freedBytes += _deleteFileQuietly(File('$path.tmp'));
    }

    _items.clear();
    await _saveManifest();
    notifyListeners();
    return freedBytes;
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
      if (item.status == DownloadStatus.completed ||
          item.status == DownloadStatus.downloading ||
          item.status == DownloadStatus.failed ||
          item.status == DownloadStatus.paused) {
        final dedupKey = item.localFilePath.isNotEmpty
            ? item.localFilePath
            : _buildKey(item.episodeId, item.partLabel);
        if (seen.add(dedupKey)) {
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

class _DownloadHttpException implements Exception {
  final int statusCode;
  const _DownloadHttpException(this.statusCode);

  @override
  String toString() => 'HTTP $statusCode';
}
