import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages application-wide playback preferences, persisting to local disk.
class SettingsManager extends ChangeNotifier {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  bool _backgroundPlay = true; // Default ON: Background play & lock screen audio
  bool _keepScreenAwake = true; // Default ON: Prevent sleep during playback

  bool get backgroundPlay => _backgroundPlay;
  bool get keepScreenAwake => _keepScreenAwake;

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

  Future<void> _persist() async {
    try {
      if (_settingsFile == null) {
        final docDir = await getApplicationDocumentsDirectory();
        _settingsFile = File('${docDir.path}/app_settings.json');
      }
      final data = {
        'backgroundPlay': _backgroundPlay,
        'keepScreenAwake': _keepScreenAwake,
      };
      await _settingsFile!.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[SettingsManager] persist error: $e');
    }
  }

  @visibleForTesting
  void resetForTesting({bool backgroundPlay = true, bool keepScreenAwake = true}) {
    _backgroundPlay = backgroundPlay;
    _keepScreenAwake = keepScreenAwake;
    _initialized = true;
  }
}
