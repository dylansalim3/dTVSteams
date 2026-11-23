import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Representation of remote release information parsed from GitHub Releases
class AppUpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String releaseTitle;
  final String releaseNotes;
  final String apkDownloadUrl;
  final int apkSizeBytes;
  final String releaseHtmlUrl;
  final DateTime publishedAt;
  final bool hasUpdate;

  AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseTitle,
    required this.releaseNotes,
    required this.apkDownloadUrl,
    required this.apkSizeBytes,
    required this.releaseHtmlUrl,
    required this.publishedAt,
    required this.hasUpdate,
  });

  String get formattedSize {
    if (apkSizeBytes <= 0) return '約 50 MB';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
        'latestVersion': latestVersion,
        'currentVersion': currentVersion,
        'releaseTitle': releaseTitle,
        'releaseNotes': releaseNotes,
        'apkDownloadUrl': apkDownloadUrl,
        'apkSizeBytes': apkSizeBytes,
        'releaseHtmlUrl': releaseHtmlUrl,
        'publishedAt': publishedAt.toIso8601String(),
        'hasUpdate': hasUpdate,
      };

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) => AppUpdateInfo(
        latestVersion: json['latestVersion'] as String? ?? '',
        currentVersion: json['currentVersion'] as String? ?? '',
        releaseTitle: json['releaseTitle'] as String? ?? '',
        releaseNotes: json['releaseNotes'] as String? ?? '',
        apkDownloadUrl: json['apkDownloadUrl'] as String? ?? '',
        apkSizeBytes: (json['apkSizeBytes'] as num?)?.toInt() ?? 0,
        releaseHtmlUrl: json['releaseHtmlUrl'] as String? ?? '',
        publishedAt: json['publishedAt'] != null
            ? DateTime.tryParse(json['publishedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        hasUpdate: json['hasUpdate'] as bool? ?? false,
      );
}

/// Service managing remote update discovery, background downloads, and native Android APK installation.
class UpdateManager extends ChangeNotifier {
  static const String currentAppVersion = '1.0.0';
  static const String githubRepo = 'dylansalim3/dTVSteams';
  static const String latestReleaseEndpoint =
      'https://api.github.com/repos/$githubRepo/releases/latest';

  static const MethodChannel _channel = MethodChannel('com.dtvsteams.dtvsteams/update');

  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _downloadedApkPath;
  AppUpdateInfo? _latestUpdate;
  bool _updateAvailable = false;
  String? _errorMessage;
  DateTime? _lastCheckedAt;
  String? _dismissedVersion;
  bool _initialized = false;

  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;
  String? get downloadedApkPath => _downloadedApkPath;
  AppUpdateInfo? get latestUpdate => _latestUpdate;
  bool get updateAvailable => _updateAvailable;
  String? get errorMessage => _errorMessage;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  String? get dismissedVersion => _dismissedVersion;
  bool get isDownloaded => _downloadedApkPath != null && File(_downloadedApkPath!).existsSync();

  /// Initialize local update state & cache
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        if (json['lastCheckedAt'] != null) {
          _lastCheckedAt = DateTime.tryParse(json['lastCheckedAt'] as String);
        }
        _dismissedVersion = json['dismissedVersion'] as String?;
        if (json['latestUpdate'] != null) {
          _latestUpdate = AppUpdateInfo.fromJson(json['latestUpdate'] as Map<String, dynamic>);
          _updateAvailable = _latestUpdate?.hasUpdate ?? false;
        }
      }

      // Check if previously downloaded APK still exists
      final apkFile = await _getUpdateApkFile();
      if (await apkFile.exists() && (await apkFile.length()) > 1024 * 1024) {
        _downloadedApkPath = apkFile.path;
      }
    } catch (e) {
      debugPrint('[UpdateManager] init error: $e');
    }
    notifyListeners();
  }

  /// Check GitHub releases for newer version.
  /// When [manual] is false, enforces a 12-hour cooldown to avoid API limits.
  Future<AppUpdateInfo?> checkForUpdate({
    bool manual = false,
    http.Client? client,
    String? currentVersionOverride,
  }) async {
    final currentVer = currentVersionOverride ?? currentAppVersion;

    if (!manual && _lastCheckedAt != null) {
      final elapsed = DateTime.now().difference(_lastCheckedAt!);
      if (elapsed < const Duration(hours: 12) && _latestUpdate != null) {
        debugPrint('[UpdateManager] Within 12h cooldown, returning cached update check');
        return _latestUpdate;
      }
    }

    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient.get(
        Uri.parse(latestReleaseEndpoint),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'dTVSteams-Mobile-App',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _errorMessage = '檢查更新失敗 (HTTP ${response.statusCode})';
        _isChecking = false;
        notifyListeners();
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawTag = data['tag_name'] as String? ?? '';
      final cleanTag = rawTag.startsWith('v') || rawTag.startsWith('V')
          ? rawTag.substring(1)
          : rawTag;

      final releaseTitle = data['name'] as String? ?? rawTag;
      final releaseNotes = data['body'] as String? ?? '此版本包含效能優化與問題修正。';
      final releaseHtmlUrl = data['html_url'] as String? ?? 'https://github.com/$githubRepo/releases';
      final publishedAtStr = data['published_at'] as String?;
      final publishedAt = publishedAtStr != null
          ? DateTime.tryParse(publishedAtStr) ?? DateTime.now()
          : DateTime.now();

      // Find APK download asset
      String apkUrl = '';
      int apkSize = 0;
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        final downloadUrl = asset['browser_download_url'] as String? ?? '';
        final size = (asset['size'] as num?)?.toInt() ?? 0;

        if (name.endsWith('.apk')) {
          if (name == 'dTVSteams-release.apk' || name.contains('release')) {
            apkUrl = downloadUrl;
            apkSize = size;
            break;
          }
          if (apkUrl.isEmpty) {
            apkUrl = downloadUrl;
            apkSize = size;
          }
        }
      }

      final hasUpdate = isNewerVersion(cleanTag, currentVer);

      _latestUpdate = AppUpdateInfo(
        latestVersion: cleanTag,
        currentVersion: currentVer,
        releaseTitle: releaseTitle,
        releaseNotes: releaseNotes,
        apkDownloadUrl: apkUrl,
        apkSizeBytes: apkSize,
        releaseHtmlUrl: releaseHtmlUrl,
        publishedAt: publishedAt,
        hasUpdate: hasUpdate,
      );

      _updateAvailable = hasUpdate;
      _lastCheckedAt = DateTime.now();

      await _persistState();
      return _latestUpdate;
    } catch (e) {
      _errorMessage = '網路連線異常，無法連線至更新伺服器: $e';
      return null;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Streams the remote APK file to local cache with live progress tracking
  Future<bool> startDownload({http.Client? client, String? targetPath}) async {
    if (_latestUpdate == null || _latestUpdate!.apkDownloadUrl.isEmpty) {
      _errorMessage = '未找到可用的 APK 安裝包下載連結';
      notifyListeners();
      return false;
    }

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadedBytes = 0;
    _totalBytes = _latestUpdate!.apkSizeBytes;
    _errorMessage = null;
    notifyListeners();

    final targetFile = targetPath != null ? File(targetPath) : await _getUpdateApkFile();
    final tempFile = File('${targetFile.path}.tmp');

    final httpClient = client ?? http.Client();
    IOSink? sink;

    try {
      if (await tempFile.exists()) await tempFile.delete();
      if (await targetFile.exists()) await targetFile.delete();

      final request = http.Request('GET', Uri.parse(_latestUpdate!.apkDownloadUrl));
      request.headers['User-Agent'] = 'dTVSteams-Mobile-App';

      final response = await httpClient.send(request);
      if (response.statusCode != 200) {
        throw Exception('下載失敗 (HTTP ${response.statusCode})');
      }

      if (response.contentLength != null && response.contentLength! > 0) {
        _totalBytes = response.contentLength!;
      }

      sink = tempFile.openWrite();
      await response.stream.listen((chunk) {
        sink?.add(chunk);
        _downloadedBytes += chunk.length;
        if (_totalBytes > 0) {
          _downloadProgress = (_downloadedBytes / _totalBytes).clamp(0.0, 1.0);
        }
        notifyListeners();
      }).asFuture();

      await sink.flush();
      await sink.close();
      sink = null;

      // Rename from .tmp to final .apk
      if (await targetFile.exists()) await targetFile.delete();
      await tempFile.rename(targetFile.path);

      _downloadedApkPath = targetFile.path;
      _downloadProgress = 1.0;
      _isDownloading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '下載過程發生錯誤: $e';
      _isDownloading = false;
      try {
        await sink?.close();
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
      notifyListeners();
      return false;
    }
  }

  /// Checks if the app has permission to install unknown apps on Android 8.0+
  Future<bool> canRequestPackageInstalls() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
        return result ?? true;
      } catch (e) {
        debugPrint('[UpdateManager] canRequestPackageInstalls failed: $e');
        return true;
      }
    }
    return true;
  }

  /// Opens the system settings toggle for "Install Unknown Apps"
  Future<bool> openInstallPermissionSettings() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('openInstallPermissionSettings');
        return result ?? false;
      } catch (e) {
        debugPrint('[UpdateManager] openInstallPermissionSettings failed: $e');
        return false;
      }
    }
    return false;
  }

  /// Launches the native Android package installer with FileProvider URI
  Future<bool> installApk() async {
    if (_downloadedApkPath == null) {
      _errorMessage = '找不到已下載的安裝檔，請重新下載';
      notifyListeners();
      return false;
    }

    final file = File(_downloadedApkPath!);
    if (!file.existsSync()) {
      _errorMessage = '安裝檔遺失，請重新下載';
      _downloadedApkPath = null;
      notifyListeners();
      return false;
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('installApk', {
          'filePath': _downloadedApkPath,
        });
        return result ?? false;
      } catch (e) {
        _errorMessage = '啟動安裝程式失敗: $e';
        notifyListeners();
        return false;
      }
    }
    return false;
  }

  /// Opens the release page or direct download in external web browser as safety net
  Future<bool> openBrowserFallback() async {
    final url = _latestUpdate?.releaseHtmlUrl ?? 'https://github.com/$githubRepo/releases';
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<bool>('openBrowserUrl', {'url': url});
        return result ?? false;
      } catch (e) {
        debugPrint('[UpdateManager] openBrowserFallback failed: $e');
        return false;
      }
    }
    return false;
  }

  /// User dismissed prompt for this version
  void dismissVersion(String version) {
    _dismissedVersion = version;
    _persistState();
    notifyListeners();
  }

  /// Semantic version comparison logic. Returns true if [latest] is strictly newer than [current].
  static bool isNewerVersion(String latest, String current) {
    final cleanLatest = _cleanVersion(latest);
    final cleanCurrent = _cleanVersion(current);

    final latestParts = cleanLatest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final currentParts = cleanCurrent.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    final maxLen = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;

    for (int i = 0; i < maxLen; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;

      if (l > c) return true;
      if (l < c) return false;
    }

    return false;
  }

  static String _cleanVersion(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1);
    }
    // Remove build metadata e.g. +1
    final plusIdx = s.indexOf('+');
    if (plusIdx != -1) {
      s = s.substring(0, plusIdx);
    }
    // Remove pre-release tags e.g. -beta
    final dashIdx = s.indexOf('-');
    if (dashIdx != -1) {
      s = s.substring(0, dashIdx);
    }
    return s;
  }

  Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/update_cache.json');
  }

  Future<File> _getUpdateApkFile() async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/dTVSteams-update.apk');
  }

  Future<void> _persistState() async {
    try {
      final file = await _getCacheFile();
      final map = {
        'lastCheckedAt': _lastCheckedAt?.toIso8601String(),
        'dismissedVersion': _dismissedVersion,
        'latestUpdate': _latestUpdate?.toJson(),
      };
      await file.writeAsString(jsonEncode(map));
    } catch (e) {
      debugPrint('[UpdateManager] _persistState error: $e');
    }
  }
}
