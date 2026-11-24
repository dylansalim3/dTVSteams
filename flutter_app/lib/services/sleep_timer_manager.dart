import 'dart:async';
import 'package:flutter/foundation.dart';

enum SleepTimerMode {
  off,
  min15,
  min30,
  min45,
  min60,
  endOfPart,
  endOfEpisode,
}

extension SleepTimerModeExtension on SleepTimerMode {
  String get label {
    switch (this) {
      case SleepTimerMode.off:
        return '關閉';
      case SleepTimerMode.min15:
        return '15 分鐘';
      case SleepTimerMode.min30:
        return '30 分鐘';
      case SleepTimerMode.min45:
        return '45 分鐘';
      case SleepTimerMode.min60:
        return '60 分鐘';
      case SleepTimerMode.endOfPart:
        return '播完當前分段停止';
      case SleepTimerMode.endOfEpisode:
        return '播完整集所有分段停止';
    }
  }

  int get initialSeconds {
    switch (this) {
      case SleepTimerMode.min15:
        return 15 * 60;
      case SleepTimerMode.min30:
        return 30 * 60;
      case SleepTimerMode.min45:
        return 45 * 60;
      case SleepTimerMode.min60:
        return 60 * 60;
      default:
        return 0;
    }
  }
}

/// Manages playback sleep timer across the app.
class SleepTimerManager extends ChangeNotifier {
  static final SleepTimerManager _instance = SleepTimerManager._internal();
  factory SleepTimerManager() => _instance;
  SleepTimerManager._internal();

  SleepTimerMode _mode = SleepTimerMode.off;
  int _remainingSeconds = 0;
  Timer? _ticker;
  VoidCallback? onExpired;

  SleepTimerMode get mode => _mode;
  int get remainingSeconds => _remainingSeconds;
  bool get isActive => _mode != SleepTimerMode.off;

  String get badgeText {
    if (!isActive) return '';
    if (_mode == SleepTimerMode.endOfPart) return '分段';
    if (_mode == SleepTimerMode.endOfEpisode) return '整集';
    final mins = (_remainingSeconds / 60).ceil();
    return '${mins}m';
  }

  String get formattedTime {
    if (!isActive) return '';
    if (_mode == SleepTimerMode.endOfPart) return '播完當前分段後停止';
    if (_mode == SleepTimerMode.endOfEpisode) return '播完整集所有分段後停止';
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void setTimer(SleepTimerMode newMode) {
    _ticker?.cancel();
    _mode = newMode;
    _remainingSeconds = newMode.initialSeconds;

    if (newMode == SleepTimerMode.off) {
      notifyListeners();
      return;
    }

    if (_remainingSeconds > 0) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 1) {
          _remainingSeconds--;
          notifyListeners();
        } else {
          _remainingSeconds = 0;
          _triggerExpired();
        }
      });
    }

    notifyListeners();
  }

  void extend15Minutes() {
    _ticker?.cancel();
    if (_mode == SleepTimerMode.off || _remainingSeconds <= 0) {
      _mode = SleepTimerMode.min15;
      _remainingSeconds = 15 * 60;
    } else {
      _remainingSeconds += 15 * 60;
    }

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _remainingSeconds = 0;
        _triggerExpired();
      }
    });

    notifyListeners();
  }

  void cancelTimer() {
    _ticker?.cancel();
    _mode = SleepTimerMode.off;
    _remainingSeconds = 0;
    notifyListeners();
  }

  void onPartFinished({required bool isLastPart}) {
    if (_mode == SleepTimerMode.endOfPart) {
      _triggerExpired();
    } else if (_mode == SleepTimerMode.endOfEpisode && isLastPart) {
      _triggerExpired();
    }
  }

  void _triggerExpired() {
    _ticker?.cancel();
    _mode = SleepTimerMode.off;
    _remainingSeconds = 0;
    notifyListeners();
    onExpired?.call();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
