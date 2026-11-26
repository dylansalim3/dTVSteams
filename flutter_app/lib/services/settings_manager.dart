import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../ui/app_themes.dart';
import '../ui/app_tokens.dart';

/// Manages application-wide playback and appearance preferences, persisting to disk.
class SettingsManager extends ChangeNotifier {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  bool _backgroundPlay = true; // Default ON: Background play & lock screen audio
  bool _keepScreenAwake = true; // Default ON: Prevent sleep during playback
  bool _autoPlayNext = true; // Default ON: Auto-play next part/episode countdown
  String? _customDownloadPath; // Null means default app storage
  String _themeId = AppThemes.defaultThemeId;

  bool get backgroundPlay => _backgroundPlay;
  bool get keepScreenAwake => _keepScreenAwake;
  bool get autoPlayNext => _autoPlayNext;
  String? get customDownloadPath => _customDownloadPath;
  String get themeId => _themeId;
  AppThemePalette get activeTheme => AppThemes.byId(_themeId);

  File? _settingsFile;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      _settingsFile = File('${docDir.path}/app_settings.json');
      if (await _settingsFile!.exists()) {
        final content = await _settingsFile!.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        if (json.containsKey('backgroundPlay')) {
          _backgroundPlay = json['backgroundPlay'] as bool? ?? true;
        }
        if (json.containsKey('keepScreenAwake')) {
          _keepScreenAwake = json['keepScreenAwake'] as bool? ?? true;
        }
        if (json.containsKey('autoPlayNext')) {
          _autoPlayNext = json['autoPlayNext'] as bool? ?? true;
        }
        if (json.containsKey('customDownloadPath')) {
          _customDownloadPath = json['customDownloadPath'] as String?;
        }
        if (json.containsKey('themeId')) {
          final loadedId = json['themeId'] as String?;
          _themeId = AppThemes.byId(loadedId).id;
          AppColors.setThemeById(_themeId);
        }
      }
    } catch (e) {
      debugPrint('[SettingsManager] init error: $e');
    } finally {
      _initialized = true;
    }
  }

  Future<void> setBackgroundPlay(bool value) async {
    if (_backgroundPlay == value) return;
    _backgroundPlay = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setKeepScreenAwake(bool value) async {
    if (_keepScreenAwake == value) return;
    _keepScreenAwake = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setAutoPlayNext(bool value) async {
    if (_autoPlayNext == value) return;
    _autoPlayNext = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setCustomDownloadPath(String? path) async {
    if (_customDownloadPath == path) return;
    _customDownloadPath = path;
    notifyListeners();
    await _persist();
  }

  Future<void> setThemeId(String id) async {
    final normalized = AppThemes.byId(id).id;
    if (_themeId == normalized) return;
    _themeId = normalized;
    AppColors.setThemeById(_themeId);
    AppSystemUi.restoreNormalChrome();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      if (_settingsFile == null) {
        final docDir = await getApplicationDocumentsDirectory();
        _settingsFile = File('${docDir.path}/app_settings.json');
      }
      final data = {
        'backgroundPlay': _backgroundPlay,
        'keepScreenAwake': _keepScreenAwake,
        'autoPlayNext': _autoPlayNext,
        'customDownloadPath': _customDownloadPath,
        'themeId': _themeId,
      };
      await _settingsFile!.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[SettingsManager] persist error: $e');
    }
  }

  @visibleForTesting
  void resetForTesting({
    bool backgroundPlay = true,
    bool keepScreenAwake = true,
    bool autoPlayNext = true,
    String? customDownloadPath,
    String themeId = AppThemes.defaultThemeId,
  }) {
    _backgroundPlay = backgroundPlay;
    _keepScreenAwake = keepScreenAwake;
    _autoPlayNext = autoPlayNext;
    _customDownloadPath = customDownloadPath;
    _themeId = AppThemes.byId(themeId).id;
    AppColors.setThemeById(_themeId);
    _initialized = true;
    notifyListeners();
  }
}
