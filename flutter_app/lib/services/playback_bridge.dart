import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to native Android WindowManager and Foreground Audio Service.
class PlaybackBridge {
  static const MethodChannel _channel = MethodChannel('com.dtvsteams.dtvsteams/playback');
  static final PlaybackBridge _instance = PlaybackBridge._internal();
  factory PlaybackBridge() => _instance;
  PlaybackBridge._internal();

  bool _isScreenAwake = false;
  bool _isBackgroundServiceRunning = false;

  bool get isScreenAwake => _isScreenAwake;
  bool get isBackgroundServiceRunning => _isBackgroundServiceRunning;

  /// Prevents the device screen from dimming/sleeping while playback is active.
  Future<void> setKeepScreenOn(bool enabled) async {
    if (_isScreenAwake == enabled) return;
    _isScreenAwake = enabled;
    try {
      await _channel.invokeMethod('setKeepScreenOn', {'enabled': enabled});
    } catch (e) {
      debugPrint('[PlaybackBridge] setKeepScreenOn error: $e');
    }
  }

  /// Starts the Android Foreground MediaPlayback Service with a notification
  /// and acquires a CPU WakeLock so audio continues uninterrupted when locked.
  Future<void> startBackgroundPlay({required String title, required String part}) async {
    _isBackgroundServiceRunning = true;
    try {
      await _channel.invokeMethod('startBackgroundPlay', {
        'title': title,
        'part': part,
      });
    } catch (e) {
      debugPrint('[PlaybackBridge] startBackgroundPlay error: $e');
    }
  }

  /// Stops the Android Foreground MediaPlayback Service and releases WakeLock.
  Future<void> stopBackgroundPlay() async {
    _isBackgroundServiceRunning = false;
    try {
      await _channel.invokeMethod('stopBackgroundPlay');
    } catch (e) {
      debugPrint('[PlaybackBridge] stopBackgroundPlay error: $e');
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _isScreenAwake = false;
    _isBackgroundServiceRunning = false;
  }
}
