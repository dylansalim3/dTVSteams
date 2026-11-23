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

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPipModeChanged') {
      isInPipMode.value = call.arguments as bool? ?? false;
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
  Future<bool> enterPip() async {
    if (kIsWeb) return false;
    try {
      final entered = await _channel.invokeMethod<bool>('enterPip');
      return entered ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Configure whether app automatically enters PiP on home/minimize gesture
  Future<void> setAutoPip(bool enabled) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('setAutoPip', {'enabled': enabled});
    } catch (_) {}
  }
}
