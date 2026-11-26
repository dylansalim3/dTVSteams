import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PipManager {
  static const MethodChannel _channel = MethodChannel('com.dtvsteams.dtvsteams/pip');
  static final PipManager _instance = PipManager._internal();
  factory PipManager() => _instance;

  PipManager._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final ValueNotifier<bool> isInPipMode = ValueNotifier<bool>(false);
  void Function(String action)? onPipAction;
  bool? _lastReportedPlaying;

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPipModeChanged') {
      isInPipMode.value = call.arguments as bool? ?? false;
    } else if (call.method == 'onPipAction') {
      final action = call.arguments as String?;
      if (action != null && action.isNotEmpty) {
        onPipAction?.call(action);
      }
    }
  }

  /// Check if device supports Android Picture-in-Picture
  Future<bool> isPipSupported() async {
    if (kIsWeb) return false;
    try {
      final supported = await _channel.invokeMethod<bool>('isPipSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request immediately entering Picture-in-Picture mode
  Future<bool> enterPip({bool? isPlaying}) async {
    if (kIsWeb) return false;
    if (isPlaying != null) {
      _lastReportedPlaying = isPlaying;
    }
    try {
      final entered = await _channel.invokeMethod<bool>(
        'enterPip',
        isPlaying == null ? null : {'isPlaying': isPlaying},
      );
      return entered ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Keep Android PiP RemoteActions synced with the player's playing state
  Future<void> setPlaybackState(bool isPlaying) async {
    if (kIsWeb) return;
    if (_lastReportedPlaying == isPlaying) return;
    _lastReportedPlaying = isPlaying;
    try {
      await _channel.invokeMethod('setPipPlaybackState', {'isPlaying': isPlaying});
    } catch (_) {}
  }

  /// Configure whether app automatically enters PiP on home/minimize gesture
  Future<void> setAutoPip(bool enabled) async {
    if (kIsWeb) return;
    if (!enabled) {
      _lastReportedPlaying = null;
    }
    try {
      await _channel.invokeMethod('setAutoPip', {'enabled': enabled});
    } catch (_) {}
  }
}
