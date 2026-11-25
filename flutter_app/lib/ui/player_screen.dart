import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../catalog/parser.dart';
import '../services/download_manager.dart';
import '../services/favorites_manager.dart';
import '../services/pip_manager.dart';
import '../services/playback_bridge.dart';
import '../services/playback_history_manager.dart';
import '../services/settings_manager.dart';
import '../services/sleep_timer_manager.dart';
import 'app_tokens.dart';
import 'downloads_screen.dart';
import 'history_screen.dart';
import 'share_dialog.dart';
import 'sleep_timer_sheet.dart';

enum VideoScaleMode {
  fit, // 適應 (Fit / Contain)
  fill, // 填滿裁剪 (Fill / Cover)
  stretch, // 拉伸 (Stretch / Fill)
}

class NativePlayerScreen extends StatefulWidget {
  final CatalogEpisode episode;
  final int initialPartIndex;
  final File? localFile;
  final List<CatalogEpisode>? playlist;

  const NativePlayerScreen({
    super.key,
    required this.episode,
    this.initialPartIndex = 0,
    this.localFile,
    this.playlist,
  });

  @override
  State<NativePlayerScreen> createState() => _NativePlayerScreenState();
}

class _NativePlayerScreenState extends State<NativePlayerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late CatalogEpisode _currentEpisode;
  late int _currentPartIndex;
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showOsd = true;
  Timer? _osdTimer;
  double _playbackSpeed = 1.0;
  final List<double> _availableSpeeds = [1.0, 1.25, 1.5, 2.0];
  bool _isAutoAdvancing = false;

  // Auto-play next part/episode countdown state
  bool _showAutoPlayHud = false;
  int _autoPlayCountdown = 5;
  Timer? _autoPlayCountdownTimer;
  bool _autoPlayDismissedForThisPart = false;

  final DownloadManager _downloadManager = DownloadManager();
  final PlaybackHistoryManager _historyManager = PlaybackHistoryManager();
  final FavoritesManager _favoritesManager = FavoritesManager();
  final PipManager _pipManager = PipManager();
  final SettingsManager _settingsManager = SettingsManager();
  final PlaybackBridge _playbackBridge = PlaybackBridge();
  final SleepTimerManager _sleepTimerManager = SleepTimerManager();
  bool _isExiting = false;

  // Vertical swipe brightness & volume state
  double _currentBrightness = 0.5;
  double _currentVolume = 1.0;
  bool _showBrightnessHud = false;
  bool _showVolumeHud = false;
  Timer? _hudFadeTimer;
  bool _isVerticalDragging = false;
  bool _isDragLeft = false;
  double _dragStartY = 0;
  double _dragStartValue = 0;

  // Double-tap seek state
  bool _showSeekFeedback = false;
  bool _isSeekingForward = false;
  int _accumulatedSeekSeconds = 0;
  Timer? _seekFeedbackTimer;
  Timer? _singleTapDebounce;
  int _lastTapTime = 0;
  Offset _lastTapPosition = Offset.zero;

  // Press-and-hold 2x fast forward state
  bool _isFastForwarding = false;
  bool _showFastForwardHud = false;
  double _preFastForwardSpeed = 1.0;
  Timer? _longPressTimer;
  bool _isPointerDown = false;
  Offset _pointerDownPos = Offset.zero;

  // Video aspect ratio scale mode
  VideoScaleMode _scaleMode = VideoScaleMode.fit;

  // Screen lock anti-touch state
  bool _isScreenLocked = false;
  bool _showUnlockHint = false;
  Timer? _unlockHintTimer;

  // Audio-only radio mode state (Feature 11)
  bool _isAudioOnlyMode = false;
  late AnimationController _vinylAnimationController;
  late AnimationController _waveformAnimationController;

  // Skip intro & smart stall fallback state (Feature 12)
  bool _skipIntroDismissedForThisPart = false;
  bool _showStallFallbackHud = false;
  bool _completionCleanupShownForThisPart = false;
  DateTime? _bufferingStartTime;

  Future<void> _safeSeekTo(VideoPlayerController? controller, Duration target) async {
    if (controller == null || _isExiting || !mounted) return;
    try {
      if (!controller.value.isInitialized || controller.value.hasError) return;
      await controller.seekTo(target);
    } catch (e) {
      debugPrint('[Player] seekTo ignored error: $e');
    }
  }

  Future<void> _safeSetPlaybackSpeed(VideoPlayerController? controller, double speed) async {
    if (controller == null || _isExiting || !mounted) return;
    try {
      if (!controller.value.isInitialized || controller.value.hasError) return;
      await controller.setPlaybackSpeed(speed);
    } catch (e) {
      debugPrint('[Player] setPlaybackSpeed ignored error: $e');
    }
  }

  bool get _canShowSkipIntro {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return false;
    if (_isScreenLocked || _skipIntroDismissedForThisPart || _isAudioOnlyMode) return false;
    final pos = c.value.position;
    return pos >= Duration.zero && pos <= const Duration(seconds: 60) && c.value.isPlaying;
  }

  void _skipIntro() {
    final c = _controller;
    if (c == null) return;
    final cur = c.value.position;
    final dur = c.value.duration;
    final target = cur + const Duration(seconds: 30);
    _safeSeekTo(c, dur > Duration.zero && target > dur ? dur : target);
    setState(() {
      _skipIntroDismissedForThisPart = true;
    });
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏩ 已為您跳過片頭 30 秒'),
        duration: Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _vinylAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _waveformAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _currentEpisode = widget.episode;
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _currentPartIndex = widget.initialPartIndex;
    _pipManager.isInPipMode.addListener(_onPipUpdate);
    _pipManager.setAutoPip(true);
    _downloadManager.addListener(_onDownloadUpdate);
    _historyManager.init();
    _settingsManager.init();
    _settingsManager.addListener(_onSettingsUpdate);
    _sleepTimerManager.addListener(_onSleepTimerUpdate);
    _sleepTimerManager.onExpired = _onSleepTimerExpired;
    _playbackBridge.getScreenBrightness().then((b) {
      if (mounted) setState(() => _currentBrightness = b);
    });
    _initPlayerForPart(_currentPartIndex);
  }

  CatalogEpisode? get _nextEpisode {
    final list = widget.playlist;
    if (list == null || list.isEmpty) return null;
    final curIdx = list.indexWhere((e) => e.id == _currentEpisode.id);
    if (curIdx >= 0 && curIdx + 1 < list.length) {
      return list[curIdx + 1];
    }
    return null;
  }

  bool get _hasNextPartOrEpisode {
    if (_currentPartIndex + 1 < _currentEpisode.parts.length) return true;
    return _nextEpisode != null;
  }

  String get _nextPlayTargetLabel {
    if (_currentPartIndex + 1 < _currentEpisode.parts.length) {
      return '下一段：${_currentEpisode.parts[_currentPartIndex + 1].label}';
    }
    final nextEp = _nextEpisode;
    if (nextEp != null) {
      return '下一集：${nextEp.title}';
    }
    return '';
  }

  void _startAutoPlayCountdown() {
    if (_showAutoPlayHud || !_settingsManager.autoPlayNext || _isScreenLocked || _autoPlayDismissedForThisPart) {
      return;
    }
    if (!_hasNextPartOrEpisode) return;

    _autoPlayCountdownTimer?.cancel();
    setState(() {
      _showAutoPlayHud = true;
      _autoPlayCountdown = 5;
    });

    _autoPlayCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_autoPlayCountdown <= 1) {
        timer.cancel();
        _proceedAutoPlayNext();
      } else {
        setState(() {
          _autoPlayCountdown--;
        });
      }
    });
  }

  void _cancelAutoPlayCountdown({bool permanentForThisPart = true}) {
    _autoPlayCountdownTimer?.cancel();
    _autoPlayCountdownTimer = null;
    if (mounted) {
      setState(() {
        _showAutoPlayHud = false;
        if (permanentForThisPart) {
          _autoPlayDismissedForThisPart = true;
        }
      });
    }
  }

  void _proceedAutoPlayNext() {
    _autoPlayCountdownTimer?.cancel();
    _autoPlayCountdownTimer = null;
    if (mounted) {
      setState(() {
        _showAutoPlayHud = false;
      });
    }

    if (_currentPartIndex + 1 < _currentEpisode.parts.length) {
      final nextPartIndex = _currentPartIndex + 1;
      _isAutoAdvancing = true;
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.playlist_play, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('自動為您播放：${_currentEpisode.parts[nextPartIndex].label}'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFFE50914),
          ),
        );
      }
      _switchPart(nextPartIndex);
    } else if (_nextEpisode != null) {
      final nextEp = _nextEpisode!;
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.skip_next, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('自動為您播放下一集：${nextEp.title}')),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFE50914),
          ),
        );
      }
      _switchToEpisode(nextEp, 0);
    } else {
      if (mounted) setState(() {});
    }
  }

  void _switchToEpisode(CatalogEpisode nextEpisode, int partIndex) {
    _persistCurrentPosition(force: true);
    _cancelAutoPlayCountdown(permanentForThisPart: false);
    setState(() {
      _currentEpisode = nextEpisode;
      _currentPartIndex = partIndex;
      _autoPlayDismissedForThisPart = false;
      _skipIntroDismissedForThisPart = false;
      _completionCleanupShownForThisPart = false;
      _isAutoAdvancing = false;
    });
    _initPlayerForPart(partIndex, forceLiveResolve: true);
  }

  void _onSleepTimerUpdate() {
    if (mounted) setState(() {});
  }

  void _onSleepTimerExpired() {
    if (!mounted || _isExiting) return;
    _controller?.pause();
    _syncPlaybackState();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('睡眠定時已到達，播放已暫停'),
        duration: const Duration(seconds: 8),
        backgroundColor: const Color(0xFF262626),
        action: SnackBarAction(
          label: '+15 分鐘',
          textColor: const Color(0xFFE50914),
          onPressed: () {
            _sleepTimerManager.extend15Minutes();
            _controller?.play();
            _syncPlaybackState();
          },
        ),
      ),
    );
    setState(() {});
  }

  void _onSettingsUpdate() {
    if (mounted) {
      _syncPlaybackState();
      setState(() {});
    }
  }

  void _syncPlaybackState() {
    if (_isExiting) {
      _playbackBridge.setKeepScreenOn(false);
      _playbackBridge.stopBackgroundPlay();
      return;
    }

    final isPlaying = _controller?.value.isPlaying ?? false;

    // 1. Keep Screen Awake
    if (isPlaying && _settingsManager.keepScreenAwake) {
      _playbackBridge.setKeepScreenOn(true);
    } else {
      _playbackBridge.setKeepScreenOn(false);
    }

    // 2. Background Audio Service (Keeps CPU awake & media notification on lock screen)
    if (isPlaying && _settingsManager.backgroundPlay) {
      final parts = widget.episode.parts;
      final partLabel = parts.isNotEmpty && _currentPartIndex < parts.length
          ? parts[_currentPartIndex].label
          : '播放中';
      _playbackBridge.startBackgroundPlay(
        title: widget.episode.title,
        part: partLabel,
      );
    } else {
      _playbackBridge.stopBackgroundPlay();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_isExiting) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // If background play is disabled AND not in PiP mode, pause video playback
      if (!_settingsManager.backgroundPlay && !_pipManager.isInPipMode.value) {
        _controller?.pause();
      }
    }
  }

  void _onPipUpdate() {
    if (mounted) setState(() {});
  }

  void _onDownloadUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _checkAndResumeHistory(VideoPlayerController controller, CatalogPart? part) async {
    if (part == null) return;
    final rec = _historyManager.getRecord(widget.episode.id, part.label);
    if (rec != null && rec.positionMs > 5000 && !rec.isCompleted && rec.positionMs < controller.value.duration.inMilliseconds - 3000) {
      await controller.seekTo(Duration(milliseconds: rec.positionMs));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已為您從上次進度 ${rec.positionFormatted} 繼續播放'),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF262626),
            action: SnackBarAction(
              label: '從頭播放',
              textColor: const Color(0xFFE50914),
              onPressed: () => controller.seekTo(Duration.zero),
            ),
          ),
        );
      }
    }
  }

  void _persistCurrentPosition({bool force = false}) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final parts = widget.episode.parts;
    final currentPart = parts.isNotEmpty && _currentPartIndex < parts.length ? parts[_currentPartIndex] : null;
    if (currentPart != null && controller.value.duration.inMilliseconds > 0) {
      _historyManager.savePosition(
        episodeId: widget.episode.id,
        partLabel: currentPart.label,
        partIndex: _currentPartIndex,
        positionMs: controller.value.position.inMilliseconds,
        durationMs: controller.value.duration.inMilliseconds,
        episodeTitle: widget.episode.title,
        thumbnailUrl: widget.episode.poster.isNotEmpty ? widget.episode.poster : widget.episode.backdrop,
        showName: widget.episode.showName,
        episode: widget.episode,
        forcePersist: force,
      );
    }
  }

  void _resetOsdTimer() {
    _osdTimer?.cancel();
    if (_showOsd && (_controller?.value.isPlaying ?? false)) {
      _osdTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && (_controller?.value.isPlaying ?? false)) {
          setState(() => _showOsd = false);
        }
      });
    }
  }

  void _toggleOsd() {
    if (_isScreenLocked) {
      _showUnlockPrompt();
      return;
    }
    setState(() {
      _showOsd = !_showOsd;
      if (_showOsd) {
        _resetOsdTimer();
      }
    });
  }

  void _lockScreen() {
    HapticFeedback.mediumImpact();
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _singleTapDebounce?.cancel();
    _singleTapDebounce = null;
    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer = null;
    setState(() {
      _isScreenLocked = true;
      _showOsd = false;
      _showFastForwardHud = false;
      _showSeekFeedback = false;
      _isSeekingForward = false;
      _accumulatedSeekSeconds = 0;
      _showBrightnessHud = false;
      _showVolumeHud = false;
    });
    _osdTimer?.cancel();
    _showUnlockPrompt();
  }

  void _unlockScreen() {
    HapticFeedback.lightImpact();
    _unlockHintTimer?.cancel();
    setState(() {
      _isScreenLocked = false;
      _showUnlockHint = false;
      _showOsd = true;
    });
    _resetOsdTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔓 螢幕已解鎖 (Screen Unlocked)'),
        duration: Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showUnlockPrompt() {
    _unlockHintTimer?.cancel();
    setState(() => _showUnlockHint = true);
    _unlockHintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showUnlockHint = false);
    });
  }

  Future<void> _initPlayerForPart(int partIndex, {bool forceLiveResolve = true}) async {
    _osdTimer?.cancel();
    final oldController = _controller;
    oldController?.removeListener(_videoPlayerListener);

    setState(() {
      _controller = null;
      _isLoading = true;
      _errorMessage = null;
      _showOsd = true;
    });

    if (oldController != null) {
      await oldController.dispose();
    }

    final parts = widget.episode.parts;
    final part = parts.isNotEmpty && partIndex < parts.length ? parts[partIndex] : null;

    // Check if offline local file is provided or already downloaded
    File? fileToPlay;
    if (widget.localFile != null && partIndex == widget.initialPartIndex && widget.localFile!.existsSync()) {
      fileToPlay = widget.localFile;
    } else if (part != null) {
      final downloaded = _downloadManager.getLocalFile(
        widget.episode.id,
        part.label,
        showId: widget.episode.showId,
        title: widget.episode.title,
      );
      if (downloaded != null && downloaded.existsSync()) {
        fileToPlay = downloaded;
      }
    }

    if (fileToPlay != null) {
      try {
        final controller = VideoPlayerController.file(fileToPlay);
        await controller.initialize();
        if (!mounted || _isExiting) {
          await controller.dispose();
          return;
        }
        await _checkAndResumeHistory(controller, part);
        controller.addListener(_videoPlayerListener);
        await controller.setPlaybackSpeed(_playbackSpeed);
        if (!mounted || _isExiting) {
          await controller.dispose();
          return;
        }
        await controller.play();

        if (mounted) {
          setState(() {
            _controller = controller;
            _isLoading = false;
            _isAutoAdvancing = false;
          });
          _resetOsdTimer();
        }
        return;
      } catch (e) {
        debugPrint('Playing local file error, falling back to online: $e');
      }
    }

    String? targetStreamUrl;

    // 1. Live Self-Healing Stream Token Resolution
    if (part != null && part.url.isNotEmpty && forceLiveResolve) {
      try {
        final res = await http.get(
          Uri.parse(part.url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14; sdk_gphone64_x86_64)',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final parsed = CatalogParser.parseStreamUrl(res.body);
          if (parsed != null && parsed.isNotEmpty) {
            targetStreamUrl = parsed;
          }
        }
      } catch (e) {
        debugPrint('Live resolve notice: $e');
      }
    }

    // 2. Fallback to cached streamUrl if live scraping failed or skipped
    if (targetStreamUrl == null || targetStreamUrl.isEmpty) {
      if (part?.streamUrl.isNotEmpty == true) {
        targetStreamUrl = part!.streamUrl;
      } else if (part?.fallbackStreamUrl.isNotEmpty == true) {
        targetStreamUrl = part!.fallbackStreamUrl;
      }
    }

    if (targetStreamUrl == null || targetStreamUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '尚未取得可播放之串流連結\n請檢查網路連線或稍後重試';
        });
      }
      return;
    }

    // 3. Initialize ExoPlayer with streaming headers
    try {
      final uri = Uri.parse(targetStreamUrl);
      final controller = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: const {
          'Referer': 'https://srgoideas.com/',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; sdk_gphone64_x86_64)',
        },
      );

      await controller.initialize();
      if (!mounted || _isExiting) {
        await controller.dispose();
        return;
      }
      await _checkAndResumeHistory(controller, part);
      controller.addListener(_videoPlayerListener);
      await controller.setPlaybackSpeed(_playbackSpeed);
      if (!mounted || _isExiting) {
        await controller.dispose();
        return;
      }
      await controller.play();

      if (mounted) {
        setState(() {
          _controller = controller;
          _isLoading = false;
          _isAutoAdvancing = false;
        });
        _resetOsdTimer();
      }
    } catch (e) {
      if (!forceLiveResolve && part != null && part.url.isNotEmpty) {
        return _initPlayerForPart(partIndex, forceLiveResolve: true);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '串流初始化失敗：$e\n(可能是過期權杖或網路波動，點擊下方重新解析並播放)';
        });
      }
    }
  }

  void _videoPlayerListener() {
    final controller = _controller;
    if (controller == null || !mounted || !controller.value.isInitialized) return;

    _syncPlaybackState();

    // Track real-time playback position
    if (controller.value.isPlaying) {
      _persistCurrentPosition(force: false);
    }

    // Autoplay next part/episode countdown when near end or finished
    if (!_isAutoAdvancing && controller.value.duration > const Duration(seconds: 2)) {
      final isFinished = controller.value.isCompleted ||
          (controller.value.position >= controller.value.duration - const Duration(milliseconds: 700));

      final remaining = controller.value.duration - controller.value.position;
      final isNearEnd = isFinished ||
          (controller.value.duration > const Duration(seconds: 8) && remaining <= const Duration(seconds: 5) && controller.value.isPlaying);

      if (isFinished) {
        // Offer quick cleanup for offline downloaded file once watched to completion
        if (!_completionCleanupShownForThisPart) {
          final parts = _currentEpisode.parts;
          final finishedPart = parts.isNotEmpty && _currentPartIndex < parts.length ? parts[_currentPartIndex] : null;
          if (finishedPart != null &&
              _downloadManager.isDownloaded(_currentEpisode.id, finishedPart.label,
                  showId: _currentEpisode.showId, title: _currentEpisode.title)) {
            _completionCleanupShownForThisPart = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已看完「${finishedPart.label}」，可清理離線檔以節省空間'),
                duration: const Duration(seconds: 4),
                backgroundColor: const Color(0xFF1E1E1E),
                action: SnackBarAction(
                  label: '刪除檔案',
                  textColor: const Color(0xFFE50914),
                  onPressed: () => _downloadManager.deleteDownload(_currentEpisode.id, finishedPart.label),
                ),
              ),
            );
          }
        }

        final isLastPart = _currentPartIndex >= _currentEpisode.parts.length - 1;
        if (_sleepTimerManager.isActive &&
            (_sleepTimerManager.mode == SleepTimerMode.endOfPart ||
             (_sleepTimerManager.mode == SleepTimerMode.endOfEpisode && isLastPart))) {
          _sleepTimerManager.onPartFinished(isLastPart: isLastPart);
          return;
        }
      }

      if (_showAutoPlayHud && controller.value.position < controller.value.duration - const Duration(seconds: 6)) {
        _cancelAutoPlayCountdown(permanentForThisPart: false);
      }

      if (isNearEnd && _settingsManager.autoPlayNext && !_isScreenLocked && !_autoPlayDismissedForThisPart && !_showAutoPlayHud) {
        if (_hasNextPartOrEpisode) {
          _startAutoPlayCountdown();
          return;
        }
      }
    }

    if (_isAudioOnlyMode) {
      if (controller.value.isPlaying) {
        if (!_vinylAnimationController.isAnimating) {
          _vinylAnimationController.repeat();
          _waveformAnimationController.repeat(reverse: true);
        }
      } else {
        if (_vinylAnimationController.isAnimating) {
          _vinylAnimationController.stop();
          _waveformAnimationController.stop();
        }
      }
    }

    // Stall detection watchdog (Feature 12)
    if (controller.value.isBuffering && controller.value.isPlaying) {
      _bufferingStartTime ??= DateTime.now();
      if (DateTime.now().difference(_bufferingStartTime!).inSeconds >= 4 && !_showStallFallbackHud) {
        _showStallFallbackHud = true;
      }
    } else {
      _bufferingStartTime = null;
      if (_showStallFallbackHud && controller.value.isPlaying && !controller.value.isBuffering) {
        _showStallFallbackHud = false;
      }
    }

    setState(() {});
  }

  void _switchPart(int newIndex) {
    if (newIndex == _currentPartIndex && _controller != null) return;
    _persistCurrentPosition(force: true);
    _cancelAutoPlayCountdown(permanentForThisPart: false);
    setState(() {
      _currentPartIndex = newIndex;
      _autoPlayDismissedForThisPart = false;
      _skipIntroDismissedForThisPart = false;
      _completionCleanupShownForThisPart = false;
      _showStallFallbackHud = false;
      _bufferingStartTime = null;
      _isAutoAdvancing = false;
    });
    _initPlayerForPart(newIndex, forceLiveResolve: true);
  }

  void _cyclePlaybackSpeed() {
    final curIdx = _availableSpeeds.indexOf(_playbackSpeed);
    final nextIdx = (curIdx + 1) % _availableSpeeds.length;
    final nextSpeed = _availableSpeeds[nextIdx];
    setState(() => _playbackSpeed = nextSpeed);
    _controller?.setPlaybackSpeed(nextSpeed);
    _resetOsdTimer();
  }

  void _cycleScaleMode() {
    setState(() {
      switch (_scaleMode) {
        case VideoScaleMode.fit:
          _scaleMode = VideoScaleMode.fill;
          break;
        case VideoScaleMode.fill:
          _scaleMode = VideoScaleMode.stretch;
          break;
        case VideoScaleMode.stretch:
          _scaleMode = VideoScaleMode.fit;
          break;
      }
    });

    final name = switch (_scaleMode) {
      VideoScaleMode.fit => '畫面比例：原始適應 (Fit)',
      VideoScaleMode.fill => '畫面比例：全螢幕填滿裁剪 (Fill)',
      VideoScaleMode.stretch => '畫面比例：全螢幕拉伸 (Stretch)',
    };

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(name),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _resetOsdTimer();
  }

  IconData get _scaleModeIcon => switch (_scaleMode) {
        VideoScaleMode.fit => Icons.fit_screen,
        VideoScaleMode.fill => Icons.crop_free,
        VideoScaleMode.stretch => Icons.aspect_ratio,
      };

  String get _scaleModeTooltip => switch (_scaleMode) {
        VideoScaleMode.fit => '畫面比例：適應 (Fit)',
        VideoScaleMode.fill => '畫面比例：填滿 (Fill)',
        VideoScaleMode.stretch => '畫面比例：拉伸 (Stretch)',
      };

  Widget _buildScaledVideoPlayer(VideoPlayerController controller) {
    final videoAspect = controller.value.aspectRatio > 0 ? controller.value.aspectRatio : (16 / 9);

    switch (_scaleMode) {
      case VideoScaleMode.fit:
        return AspectRatio(
          aspectRatio: videoAspect,
          child: VideoPlayer(controller),
        );
      case VideoScaleMode.fill:
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width > 0 ? controller.value.size.width : 1920,
              height: controller.value.size.height > 0 ? controller.value.size.height : 1080,
              child: VideoPlayer(controller),
            ),
          ),
        );
      case VideoScaleMode.stretch:
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.fill,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width > 0 ? controller.value.size.width : 1920,
              height: controller.value.size.height > 0 ? controller.value.size.height : 1080,
              child: VideoPlayer(controller),
            ),
          ),
        );
    }
  }

  void _toggleAudioOnlyMode() {
    setState(() {
      _isAudioOnlyMode = !_isAudioOnlyMode;
    });
    if (_isAudioOnlyMode) {
      if (_controller?.value.isPlaying == true) {
        _vinylAnimationController.repeat();
        _waveformAnimationController.repeat(reverse: true);
      }
    } else {
      _vinylAnimationController.stop();
      _waveformAnimationController.stop();
    }
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isAudioOnlyMode
              ? '🎧 已開啟純音頻聽劇模式 (節省 70%+ 電量與流量)'
              : '📺 已返回視訊播放模式',
        ),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildRadioPlayerView(VideoPlayerController? controller) {
    final isPlaying = controller?.value.isPlaying ?? false;
    final part = _currentEpisode.parts.isNotEmpty && _currentPartIndex < _currentEpisode.parts.length
        ? _currentEpisode.parts[_currentPartIndex]
        : null;
    final partLabel = part?.label ?? 'Part ${_currentPartIndex + 1}';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            Color(0xFF23161A),
            Color(0xFF0F0F10),
            Colors.black,
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Audio mode pill badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.headphones, color: Color(0xFFE50914), size: 14),
                        SizedBox(width: 6),
                        Text(
                          '純音頻聽劇模式 · 70%+ 極致省電',
                          style: TextStyle(
                            color: Color(0xFFFF8B8F),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Vinyl Disc Artwork with album cover
                  RotationTransition(
                    turns: _vinylAnimationController,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF141414),
                        border: Border.all(color: Colors.white24, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: isPlaying ? const Color(0xFFE50914).withValues(alpha: 0.25) : Colors.black54,
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12, width: 3),
                            image: _currentEpisode.poster.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_currentEpisode.poster),
                                    fit: BoxFit.cover,
                                    onError: (err, stack) {},
                                  )
                                : null,
                          ),
                          child: _currentEpisode.poster.isEmpty
                              ? const Icon(Icons.music_note, color: Colors.white38, size: 48)
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Animated Waveform Bars
                  AnimatedBuilder(
                    animation: _waveformAnimationController,
                    builder: (context, _) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(11, (index) {
                          final animVal = _waveformAnimationController.value;
                          final offset = (index * 0.18) % 1.0;
                          final factor = isPlaying ? ((animVal + offset) % 1.0) : 0.15;
                          final barHeight = 8.0 + (factor * 26.0);
                          return Container(
                            width: 4,
                            height: barHeight,
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? (index == 5 ? const Color(0xFFE50914) : const Color(0xFFFF5252))
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Episode Title
                  Text(
                    _currentEpisode.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Part & Date Subtitle
                  Text(
                    '${_currentEpisode.date} · $partLabel · 綜藝玩很大',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Radio Quick Action Controls: -15s, Play/Pause, +15s
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // -15s
                      IconButton(
                        tooltip: '快退 15 秒',
                        iconSize: 32,
                        icon: const Icon(Icons.fast_rewind, color: Colors.white),
                        onPressed: () {
                          if (controller == null) return;
                          final cur = controller.value.position;
                          final target = cur - const Duration(seconds: 15);
                          controller.seekTo(target > Duration.zero ? target : Duration.zero);
                        },
                      ),
                      const SizedBox(width: 16),

                      // Play/Pause Big Button
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE50914),
                        ),
                        child: IconButton(
                          iconSize: 38,
                          color: Colors.white,
                          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: () {
                            if (controller == null) return;
                            if (isPlaying) {
                              controller.pause();
                              _vinylAnimationController.stop();
                              _waveformAnimationController.stop();
                            } else {
                              controller.play();
                              _vinylAnimationController.repeat();
                              _waveformAnimationController.repeat(reverse: true);
                            }
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 16),

                      // +15s
                      IconButton(
                        tooltip: '快進 15 秒',
                        iconSize: 32,
                        icon: const Icon(Icons.fast_forward, color: Colors.white),
                        onPressed: () {
                          if (controller == null) return;
                          final cur = controller.value.position;
                          final dur = controller.value.duration;
                          final target = cur + const Duration(seconds: 15);
                          controller.seekTo(target < dur ? target : dur);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Return to video button
                  OutlinedButton.icon(
                    onPressed: _toggleAudioOnlyMode,
                    icon: const Icon(Icons.videocam, color: Colors.white70, size: 16),
                    label: const Text(
                      '返回視訊模式 (Return to Video)',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleExitPlayer() async {
    if (_isExiting) return;
    _isExiting = true;

    // 0. Immediately restore native top status bar and bottom navigation buttons synchronously
    AppSystemUi.restoreNormalChrome();

    // 1. Instantly silence and pause audio/video
    try {
      await _controller?.pause();
    } catch (_) {}

    // Disable screen wakelock and background audio immediately
    try {
      await _playbackBridge.setKeepScreenOn(false);
      await _playbackBridge.stopBackgroundPlay();
      await _playbackBridge.setScreenBrightness(-1.0);
    } catch (_) {}

    // 2. Disable Auto-PiP immediately so system back gesture doesn't trigger PiP
    try {
      await _pipManager.setAutoPip(false);
    } catch (_) {}

    // 3. Persist current watch history
    _persistCurrentPosition(force: true);

    // 4. Re-assert system navigation/status bar after native bridge calls complete
    AppSystemUi.restoreNormalChrome();
  }

  @override
  void dispose() {
    _isExiting = true;
    AppSystemUi.restoreNormalChrome();
    _playbackBridge.setKeepScreenOn(false);
    _playbackBridge.stopBackgroundPlay();
    _playbackBridge.setScreenBrightness(-1.0);
    _hudFadeTimer?.cancel();
    _settingsManager.removeListener(_onSettingsUpdate);
    _sleepTimerManager.removeListener(_onSleepTimerUpdate);
    if (_sleepTimerManager.onExpired == _onSleepTimerExpired) {
      _sleepTimerManager.onExpired = null;
    }
    _seekFeedbackTimer?.cancel();
    _singleTapDebounce?.cancel();
    _longPressTimer?.cancel();
    _unlockHintTimer?.cancel();
    _autoPlayCountdownTimer?.cancel();
    _vinylAnimationController.dispose();
    _waveformAnimationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    AppSystemUi.restoreNormalChrome();
    _persistCurrentPosition(force: true);
    _pipManager.setAutoPip(false);
    _pipManager.isInPipMode.removeListener(_onPipUpdate);
    _downloadManager.removeListener(_onDownloadUpdate);
    _osdTimer?.cancel();
    _controller?.removeListener(_videoPlayerListener);
    try {
      _controller?.pause();
    } catch (_) {}
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
      setState(() => _showOsd = true);
      _osdTimer?.cancel();
    } else {
      c.play();
      _resetOsdTimer();
    }
    _syncPlaybackState();
    setState(() {});
  }

  void _showPlaybackSettingsSheet() {
    _osdTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final bottomInset = mediaQuery.padding.bottom;
        final maxSheetHeight = mediaQuery.size.height * 0.75;
        return ListenableBuilder(
          listenable: _settingsManager,
          builder: (ctx, _) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: true,
                bottom: true,
                minimum: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 6, 18, (bottomInset + 16) / 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.tune, color: Color(0xFFE50914), size: 20),
                              SizedBox(width: 8),
                              Text(
                                '播放偏好設定 (Settings)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Material(
                            color: const Color(0xFF2A2A2A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                SwitchListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  activeColor: const Color(0xFFE50914),
                                  title: const Text('背景播放 (鎖定螢幕繼續播放音訊)',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: const Text('螢幕關閉鎖定或切換應用時，背景繼續播放聲音',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                                  value: _settingsManager.backgroundPlay,
                                  onChanged: (val) => _settingsManager.setBackgroundPlay(val),
                                ),
                                const Divider(color: Colors.white12, height: 1),
                                SwitchListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  activeColor: const Color(0xFFE50914),
                                  title: const Text('播放中防止裝置休眠 (保持螢幕常亮)',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: const Text('影片播放中螢幕不會因逾時自動變暗或關閉',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                                  value: _settingsManager.keepScreenAwake,
                                  onChanged: (val) => _settingsManager.setKeepScreenAwake(val),
                                ),
                                const Divider(color: Colors.white12, height: 1),
                                SwitchListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  activeColor: const Color(0xFFE50914),
                                  title: const Text('自動連續播放下一段 / 下一集',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: const Text('分段或整集播畢前浮現 5 秒倒數並自動續播',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                                  value: _settingsManager.autoPlayNext,
                                  onChanged: (val) => _settingsManager.setAutoPlayNext(val),
                                ),
                                const Divider(color: Colors.white12, height: 1),
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  leading: Icon(
                                    _sleepTimerManager.isActive ? Icons.alarm_on : Icons.timer_outlined,
                                    size: 20,
                                    color: _sleepTimerManager.isActive ? const Color(0xFFE50914) : Colors.white70,
                                  ),
                                  title: const Text('睡眠定時器 (Sleep Timer)',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    _sleepTimerManager.isActive
                                        ? '倒數中：${_sleepTimerManager.formattedTime}'
                                        : '定時自動暫停並停止背景音訊服務',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _sleepTimerManager.isActive ? const Color(0xFFE50914) : Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    showSleepTimerSheet(context, onTimerChanged: () => setState(() {}));
                                  },
                                ),
                                const Divider(color: Colors.white12, height: 1),
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  leading: Icon(_scaleModeIcon, color: const Color(0xFFE50914), size: 20),
                                  title: const Text('畫面比例縮放 (Aspect Ratio)',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    _scaleModeTooltip,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _cycleScaleMode();
                                  },
                                ),
                                const Divider(color: Colors.white12, height: 1),
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  leading: const Icon(Icons.history, color: Color(0xFFE50914), size: 20),
                                  title: const Text('觀看歷史紀錄 (Watch History)',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: const Text(
                                    '查看歷史播放清單與中斷點進度',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white60, fontSize: 11),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                                    );
                                  },
                                ),
                                const Divider(color: Colors.white12, height: 1),
                                ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  leading: const Icon(Icons.lock_outline_rounded, color: Color(0xFFE50914), size: 20),
                                  title: const Text('螢幕鎖定防誤觸 (Screen Lock)',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: const Text(
                                    '鎖定所有控制項與手勢，防止誤觸',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white60, fontSize: 11),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _lockScreen();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) _resetOsdTimer();
    });
  }

  void _seekRelative(int seconds) {
    if (_isScreenLocked || _isExiting || !mounted) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.hasError) return;
    final dur = c.value.duration;
    if (dur <= Duration.zero) return;
    final target = c.value.position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > dur ? dur : target);
    _safeSeekTo(c, clamped);
    _resetOsdTimer();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_isScreenLocked) {
      _isPointerDown = false;
      return;
    }
    _isPointerDown = true;
    _pointerDownPos = event.localPosition;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _isPointerDown && !_isVerticalDragging && !_showSeekFeedback) {
        final c = _controller;
        if (c != null && c.value.isInitialized && c.value.isPlaying) {
          _preFastForwardSpeed = _playbackSpeed;
          _isFastForwarding = true;
          _safeSetPlaybackSpeed(c, 2.0);
          HapticFeedback.lightImpact();
          _singleTapDebounce?.cancel();
          _singleTapDebounce = null;
          setState(() {
            _showFastForwardHud = true;
          });
        }
      }
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if ((event.localPosition - _pointerDownPos).distance > 12) {
      _longPressTimer?.cancel();
      _longPressTimer = null;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _isPointerDown = false;
    _longPressTimer?.cancel();
    _longPressTimer = null;
    if (_isFastForwarding) {
      _isFastForwarding = false;
      _safeSetPlaybackSpeed(_controller, _preFastForwardSpeed);
      if (mounted) {
        setState(() {
          _showFastForwardHud = false;
        });
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _isPointerDown = false;
    _longPressTimer?.cancel();
    _longPressTimer = null;
    if (_isFastForwarding) {
      _isFastForwarding = false;
      _safeSetPlaybackSpeed(_controller, _preFastForwardSpeed);
      if (mounted) {
        setState(() {
          _showFastForwardHud = false;
        });
      }
    }
  }

  void _handleScreenTapDown(TapDownDetails details, double screenWidth) {
    if (_isScreenLocked) {
      _showUnlockPrompt();
      return;
    }
    if (_isFastForwarding || screenWidth <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final pos = details.localPosition;
    final isDoubleTap = (now - _lastTapTime < 380) && ((pos - _lastTapPosition).distance < 120);

    if (isDoubleTap) {
      _singleTapDebounce?.cancel();
      _singleTapDebounce = null;
      _longPressTimer?.cancel();
      _longPressTimer = null;
      _lastTapTime = 0;

      final isLeft = pos.dx < screenWidth * 0.45;
      final isRight = pos.dx > screenWidth * 0.55;

      if (isLeft) {
        _triggerDoubleTapSeek(forward: false);
      } else if (isRight) {
        _triggerDoubleTapSeek(forward: true);
      } else {
        _toggleOsd();
      }
    } else {
      _lastTapTime = now;
      _lastTapPosition = pos;
      _singleTapDebounce?.cancel();
      _singleTapDebounce = Timer(const Duration(milliseconds: 260), () {
        if (mounted && !_isPointerDown && !_isFastForwarding && !_isVerticalDragging) {
          _toggleOsd();
        }
      });
    }
  }

  void _triggerDoubleTapSeek({required bool forward}) {
    if (!mounted || _isExiting || _isScreenLocked) return;
    _longPressTimer?.cancel();
    _longPressTimer = null;

    if (_showSeekFeedback && _isSeekingForward == forward) {
      _accumulatedSeekSeconds += 10;
    } else {
      _accumulatedSeekSeconds = 10;
      _isSeekingForward = forward;
    }

    _seekRelative(forward ? 10 : -10);

    setState(() {
      _showSeekFeedback = true;
    });

    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showSeekFeedback = false;
          _isSeekingForward = false;
          _accumulatedSeekSeconds = 0;
        });
      }
    });
  }

  void _onVerticalDragStart(DragStartDetails details, double screenWidth) {
    if (_isScreenLocked) return;
    _longPressTimer?.cancel();
    _longPressTimer = null;
    final pos = details.localPosition;
    _dragStartY = pos.dy;
    _isDragLeft = pos.dx < screenWidth * 0.45;
    _isVerticalDragging = false;

    if (_isDragLeft) {
      _dragStartValue = _currentBrightness;
    } else if (pos.dx > screenWidth * 0.55) {
      _dragStartValue = _currentVolume;
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, double screenHeight) {
    final deltaY = _dragStartY - details.localPosition.dy;
    if (!_isVerticalDragging && deltaY.abs() < 10) {
      return;
    }

    _isVerticalDragging = true;
    _singleTapDebounce?.cancel();
    _singleTapDebounce = null;

    final change = deltaY / (screenHeight * 0.65);
    final newValue = (_dragStartValue + change).clamp(0.0, 1.0);

    if (_isDragLeft) {
      _currentBrightness = newValue;
      _playbackBridge.setScreenBrightness(newValue);
      _showBrightnessHud = true;
      _showVolumeHud = false;
    } else {
      _currentVolume = newValue;
      _controller?.setVolume(newValue);
      _showVolumeHud = true;
      _showBrightnessHud = false;
    }

    _resetHudFadeTimer();
    setState(() {});
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isVerticalDragging) {
      _resetHudFadeTimer();
    }
    _isVerticalDragging = false;
  }

  void _resetHudFadeTimer() {
    _hudFadeTimer?.cancel();
    _hudFadeTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showBrightnessHud = false;
          _showVolumeHud = false;
        });
      }
    });
  }

  Widget _buildVerticalHud({
    required bool isLeft,
    required double value,
    required IconData icon,
    required String label,
  }) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: (isLeft ? _showBrightnessHud : _showVolumeHud) ? 1.0 : 0.0,
        child: Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white24, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 12),
              Container(
                width: 6,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 6,
                  height: 100 * value,
                  decoration: BoxDecoration(
                    color: isLeft ? const Color(0xFFFFCC00) : const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${(value * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFastForwardHud() {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _showFastForwardHud ? 1.0 : 0.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.bolt, color: Color(0xFFFFCC00), size: 20),
              SizedBox(width: 6),
              Text(
                '2X 快進中',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.fast_forward, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoPlayHud() {
    final nextTarget = _nextPlayTargetLabel;
    final progress = (5 - _autoPlayCountdown) / 5.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular Countdown Timer
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 3.2,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                ),
                Text(
                  '$_autoPlayCountdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Target info
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.bolt, color: Color(0xFFE50914), size: 14),
                    SizedBox(width: 4),
                    Text(
                      '即將自動播放',
                      style: TextStyle(
                        color: Color(0xFFE50914),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  nextTarget,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Action Buttons
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _proceedAutoPlayNext,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, size: 16),
                SizedBox(width: 2),
                Text('播放', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '取消自動播放',
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _cancelAutoPlayCountdown(permanentForThisPart: true),
          ),
        ],
      ),
    );
  }

  void _triggerDownloadCurrentPart() {
    final parts = widget.episode.parts;
    if (parts.isEmpty || _currentPartIndex >= parts.length) return;
    final part = parts[_currentPartIndex];

    if (_downloadManager.isDownloaded(widget.episode.id, part.label,
        showId: widget.episode.showId, title: widget.episode.title)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已下載至本機：${widget.episode.title} - ${part.label}'),
          action: SnackBarAction(
            label: '前往下載庫',
            textColor: const Color(0xFFE50914),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    if (_downloadManager.isDownloading(widget.episode.id, part.label,
        showId: widget.episode.showId, title: widget.episode.title)) {
      final item = _downloadManager.getItem(widget.episode.id, part.label,
          showId: widget.episode.showId, title: widget.episode.title);
      final pct = item?.progressPercentage ?? '';
      final dlStr = _downloadManager.formatBytes(item?.downloadedBytes ?? 0);
      final totStr = item != null && item.totalBytes > 0 ? _downloadManager.formatBytes(item.totalBytes) : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在下載中 ($pct $dlStr / $totStr)：${part.label}'),
          action: SnackBarAction(
            label: '查看進度',
            textColor: const Color(0xFFE50914),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('開始下載 ${widget.episode.title} - ${part.label}'),
        backgroundColor: AppColors.accent,
        action: SnackBarAction(
          label: '查看進度',
          textColor: AppColors.textPrimary,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DownloadsScreen()),
            );
          },
        ),
      ),
    );
    _downloadManager.startDownload(widget.episode, part).then((ok) {
      if (!ok && mounted) {
        final failedItem = _downloadManager.getItem(
          widget.episode.id,
          part.label,
          showId: widget.episode.showId,
          title: widget.episode.title,
        );
        if (failedItem?.status == DownloadStatus.failed) {
          messenger.removeCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text('下載失敗 (${part.label})：${failedItem?.error ?? "請稍後重試"}'),
              backgroundColor: AppColors.warningSurface,
              action: SnackBarAction(
                label: '重試',
                textColor: AppColors.warning,
                onPressed: () => _downloadManager.startDownload(widget.episode, part),
              ),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final parts = _currentEpisode.parts;
    final currentPart = parts.isNotEmpty && _currentPartIndex < parts.length
        ? parts[_currentPartIndex]
        : null;

    final controller = _controller;
    final isInitialized = controller != null && controller.value.isInitialized;
    final isPlaying = isInitialized && controller.value.isPlaying;
    final position = isInitialized ? controller.value.position : Duration.zero;
    final duration = isInitialized ? controller.value.duration : Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final isCurPartDownloaded = currentPart != null &&
        _downloadManager.isDownloaded(_currentEpisode.id, currentPart.label,
            showId: _currentEpisode.showId, title: _currentEpisode.title);
    final isCurPartDownloading = currentPart != null &&
        _downloadManager.isDownloading(_currentEpisode.id, currentPart.label,
            showId: _currentEpisode.showId, title: _currentEpisode.title);
    final downloadItem = currentPart != null
        ? _downloadManager.getItem(_currentEpisode.id, currentPart.label,
            showId: _currentEpisode.showId, title: _currentEpisode.title)
        : null;

    if (_pipManager.isInPipMode.value) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          _handleExitPlayer();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: isInitialized
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9,
                    child: VideoPlayer(controller),
                  )
                : const SizedBox(),
          ),
        ),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _handleExitPlayer();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.space): _togglePlayPause,
            const SingleActivator(LogicalKeyboardKey.select): _togglePlayPause,
            const SingleActivator(LogicalKeyboardKey.enter): _togglePlayPause,
            const SingleActivator(LogicalKeyboardKey.mediaPlayPause): _togglePlayPause,
            const SingleActivator(LogicalKeyboardKey.mediaPlay): () => controller?.play(),
            const SingleActivator(LogicalKeyboardKey.mediaPause): () => controller?.pause(),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _seekRelative(-10),
            const SingleActivator(LogicalKeyboardKey.mediaRewind): () => _seekRelative(-10),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () => _seekRelative(10),
            const SingleActivator(LogicalKeyboardKey.mediaFastForward): () => _seekRelative(10),
            const SingleActivator(LogicalKeyboardKey.arrowUp): _toggleOsd,
            const SingleActivator(LogicalKeyboardKey.arrowDown): _toggleOsd,
            const SingleActivator(LogicalKeyboardKey.escape): _handleExitPlayer,
            const SingleActivator(LogicalKeyboardKey.gameButtonB): _handleExitPlayer,
          },
        child: Focus(
          autofocus: true,
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: _onPointerCancel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _handleScreenTapDown(details, MediaQuery.of(context).size.width),
              onVerticalDragStart: (details) => _onVerticalDragStart(details, MediaQuery.of(context).size.width),
              onVerticalDragUpdate: (details) => _onVerticalDragUpdate(details, MediaQuery.of(context).size.height),
              onVerticalDragEnd: _onVerticalDragEnd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video Surface View (Backed by native Android Media3 ExoPlayer)
                  Center(
                    child: _isAudioOnlyMode
                        ? _buildRadioPlayerView(controller)
                        : (isInitialized
                            ? _buildScaledVideoPlayer(controller)
                            : (_isLoading
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(color: Color(0xFFE50914)),
                                      SizedBox(height: 16),
                                      Text(
                                        '正在連線即時串流... (Connecting live stream)',
                                        style: TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ],
                                  )
                                : Container(color: Colors.black))),
                  ),

                // Error Overlay with Self-Healing Action
                if (_errorMessage != null)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
                          const SizedBox(height: 14),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () => _initPlayerForPart(_currentPartIndex, forceLiveResolve: true),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text(
                              '重新解析並重試 (Retry)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Animated Double-Tap Seek Feedback Overlay
                if (_showSeekFeedback)
                  Positioned(
                    key: const ValueKey('seek_feedback_overlay'),
                    top: 0,
                    bottom: 0,
                    left: _isSeekingForward ? null : 0,
                    right: _isSeekingForward ? 0 : null,
                    width: MediaQuery.of(context).size.width * 0.42,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: _isSeekingForward ? const Alignment(0.8, 0.0) : const Alignment(-0.8, 0.0),
                            radius: 1.2,
                            colors: [
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isSeekingForward ? Icons.fast_forward : Icons.fast_rewind,
                              color: Colors.white,
                              size: 42,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24, width: 0.8),
                              ),
                              child: Text(
                                '${_isSeekingForward ? "+" : "-"}$_accumulatedSeekSeconds 秒',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Vertical Brightness Capsule HUD (Left)
                Positioned(
                  left: 32,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildVerticalHud(
                      isLeft: true,
                      value: _currentBrightness,
                      icon: _currentBrightness > 0.6
                          ? Icons.brightness_high
                          : (_currentBrightness > 0.25 ? Icons.brightness_medium : Icons.brightness_low),
                      label: '亮度',
                    ),
                  ),
                ),

                // Vertical Volume Capsule HUD (Right)
                Positioned(
                  right: 32,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildVerticalHud(
                      isLeft: false,
                      value: _currentVolume,
                      icon: _currentVolume == 0
                          ? Icons.volume_off
                          : (_currentVolume > 0.5 ? Icons.volume_up : Icons.volume_down),
                      label: '音量',
                    ),
                  ),
                ),

                // Top Fast-Forward 2X Capsule HUD
                if (_showFastForwardHud)
                  Positioned(
                    top: 28,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildFastForwardHud(),
                    ),
                  ),

                // Animated OSD Controls
                AnimatedOpacity(
                  key: const ValueKey('osd_controls_overlay'),
                  opacity: (_showOsd && !_isScreenLocked) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_showOsd || _isScreenLocked,
                    child: Stack(
                      children: [
                        // Left-side Floating Lock Button
                        Positioned(
                          left: 20,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.65),
                                border: Border.all(color: Colors.white24, width: 1),
                              ),
                              child: IconButton(
                                tooltip: '鎖定螢幕 (防誤觸)',
                                icon: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 22),
                                onPressed: _lockScreen,
                              ),
                            ),
                          ),
                        ),
                        // Top Gradient Header
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: SafeArea(
                              bottom: false,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isPortraitOrNarrow = constraints.maxWidth < 600;
                                  final backBtn = IconButton(
                                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                                    onPressed: () {
                                      _handleExitPlayer();
                                      if (mounted) {
                                        Navigator.of(context).maybePop();
                                      }
                                    },
                                  );
                                  final titleWidget = Text(
                                    _currentEpisode.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );

                                  final secondaryActions = <Widget>[
                                    // Download Button in OSD
                                    IconButton(
                                      tooltip: isCurPartDownloaded
                                          ? '已下載'
                                          : (isCurPartDownloading ? '下載中' : '下載此分段'),
                                      icon: isCurPartDownloading
                                          ? SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                value: downloadItem?.progress,
                                                strokeWidth: 2.5,
                                                color: const Color(0xFFE50914),
                                              ),
                                            )
                                          : Icon(
                                              isCurPartDownloaded ? Icons.download_done : Icons.download,
                                              color: isCurPartDownloaded ? const Color(0xFF46D369) : Colors.white,
                                              size: 22,
                                            ),
                                      onPressed: _triggerDownloadCurrentPart,
                                    ),

                                    // PiP (Picture-in-Picture) Button in OSD
                                    IconButton(
                                      tooltip: '子母畫面 (Picture-in-Picture)',
                                      icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white, size: 22),
                                      onPressed: () => _pipManager.enterPip(),
                                    ),

                                    // Aspect Ratio Scale Mode Button in OSD
                                    IconButton(
                                      tooltip: _scaleModeTooltip,
                                      icon: Icon(_scaleModeIcon, color: Colors.white, size: 22),
                                      onPressed: _cycleScaleMode,
                                    ),

                                    const SizedBox(width: 4),

                                    // Speed Toggle Chip
                                    GestureDetector(
                                      onTap: _cyclePlaybackSpeed,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: Text(
                                          '${_playbackSpeed}x',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 4),

                                    // Sleep Timer Button in OSD
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        IconButton(
                                          tooltip: _sleepTimerManager.isActive
                                              ? '睡眠定時器 (剩餘 ${_sleepTimerManager.badgeText})'
                                              : '睡眠定時器 (Sleep Timer)',
                                          icon: Icon(
                                            _sleepTimerManager.isActive ? Icons.alarm_on : Icons.timer_outlined,
                                            color: _sleepTimerManager.isActive ? const Color(0xFFE50914) : Colors.white,
                                            size: 22,
                                          ),
                                          onPressed: () => showSleepTimerSheet(context, onTimerChanged: () => setState(() {})),
                                        ),
                                        if (_sleepTimerManager.isActive)
                                          Positioned(
                                            right: 4,
                                            top: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE50914),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _sleepTimerManager.badgeText,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),

                                    // Audio-Only Radio Mode Button in OSD (Feature 11)
                                    IconButton(
                                      tooltip: _isAudioOnlyMode
                                          ? '切換回視訊播放模式 (Video)'
                                          : '切換純音頻聽劇模式 (Audio-Only)',
                                      icon: Icon(
                                        _isAudioOnlyMode ? Icons.headphones : Icons.headphones_outlined,
                                        color: _isAudioOnlyMode ? const Color(0xFFE50914) : Colors.white,
                                        size: 22,
                                      ),
                                      onPressed: _toggleAudioOnlyMode,
                                    ),

                                    // Playback Settings Button in OSD
                                    IconButton(
                                      tooltip: '播放偏好設定 (背景播放 / 防止休眠)',
                                      icon: const Icon(Icons.tune, color: Colors.white, size: 22),
                                      onPressed: _showPlaybackSettingsSheet,
                                    ),

                                    // Share Button in OSD (QR Code & Link)
                                    IconButton(
                                      tooltip: '分享此集影片 (QR Code / 連結)',
                                      icon: const Icon(Icons.share_outlined, color: Colors.white, size: 22),
                                      onPressed: () {
                                        showShareDialog(
                                          context,
                                          _currentEpisode,
                                          partIndex: _currentPartIndex,
                                          localFilePath: widget.localFile?.path,
                                        );
                                      },
                                    ),

                                    // Favorite Button in OSD (Watch Later)
                                    ListenableBuilder(
                                      listenable: _favoritesManager,
                                      builder: (context, _) {
                                        final isFav = _favoritesManager.isFavorite(_currentEpisode.id);
                                        return IconButton(
                                          tooltip: isFav ? '已收藏 (點擊取消)' : '加入收藏',
                                          icon: Icon(
                                            isFav ? Icons.favorite : Icons.favorite_border,
                                            color: isFav ? const Color(0xFFE50914) : Colors.white,
                                            size: 22,
                                          ),
                                          onPressed: () async {
                                            final added = await _favoritesManager.toggleFavorite(_currentEpisode);
                                            HapticFeedback.lightImpact();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).removeCurrentSnackBar();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(added ? '❤️ 已加入收藏清單' : '已從收藏清單移除'),
                                                  duration: const Duration(milliseconds: 1200),
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ];

                                  final lockBtn = IconButton(
                                    tooltip: '鎖定螢幕 (防誤觸)',
                                    icon: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 22),
                                    onPressed: _lockScreen,
                                  );

                                  if (isPortraitOrNarrow) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            backBtn,
                                            const SizedBox(width: 4),
                                            Expanded(child: titleWidget),
                                            lockBtn,
                                          ],
                                        ),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(children: secondaryActions),
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      backBtn,
                                      const SizedBox(width: 8),
                                      Expanded(child: titleWidget),
                                      ...secondaryActions,
                                      lockBtn,
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // Bottom Gradient Controls
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              16,
                              20,
                              MediaQuery.of(context).padding.bottom + 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.92)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              bottom: true,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Parts Selector
                                  if (parts.length > 1) ...[
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          const Text(
                                            '分段 (Parts):',
                                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          ...List.generate(parts.length, (idx) {
                                            final p = parts[idx];
                                            final isSelected = idx == _currentPartIndex;
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 8.0),
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(4),
                                                onTap: () => _switchPart(idx),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? const Color(0xFFE50914)
                                                        : Colors.white.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: isSelected ? const Color(0xFFE50914) : Colors.white24,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    p.label,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],

                                  // Seek Progress Slider
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: const Color(0xFFE50914),
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: const Color(0xFFE50914),
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      trackHeight: 3.0,
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                    ),
                                    child: Slider(
                                      value: progress,
                                      onChanged: (val) {
                                        if (duration > Duration.zero) {
                                          final targetMs = (val * duration.inMilliseconds).round();
                                          _safeSeekTo(_controller, Duration(milliseconds: targetMs));
                                          _resetOsdTimer();
                                        }
                                      },
                                    ),
                                  ),

                                  // Playback Controls Row
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                          color: Colors.white,
                                          size: 34,
                                        ),
                                        onPressed: _togglePlayPause,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.replay_10, color: Colors.white70, size: 24),
                                        onPressed: () => _seekRelative(-10),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.forward_10, color: Colors.white70, size: 24),
                                        onPressed: () => _seekRelative(10),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: const Color(0xFFE50914)),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          '1080p FHD',
                                          style: TextStyle(
                                            color: Color(0xFFE50914),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Floating Auto-Play Next Part/Episode Countdown HUD
                if (_showAutoPlayHud && !_isScreenLocked)
                  Positioned(
                    bottom: _showOsd ? 110 : 36,
                    left: 20,
                    right: 20,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: _buildAutoPlayHud(),
                    ),
                  ),

                // Floating Skip Intro Pill (Feature 12)
                if (_canShowSkipIntro && !_showAutoPlayHud)
                  Positioned(
                    bottom: _showOsd ? 110 : 36,
                    right: 20,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _skipIntro,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white30, width: 1),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 8, spreadRadius: 1),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '跳過片頭 (30s)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.fast_forward, color: Color(0xFFE50914), size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Smart Buffering Stall / CDN Fallback HUD (Feature 12)
                if (_showStallFallbackHud && !_isScreenLocked)
                  Positioned(
                    top: 50,
                    left: 24,
                    right: 24,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E).withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.7), width: 1),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 12),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_tethering_error_rounded, color: Colors.orangeAccent, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              '網路卡頓緩衝中...',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE50914),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                setState(() => _showStallFallbackHud = false);
                                _initPlayerForPart(_currentPartIndex, forceLiveResolve: true);
                              },
                              child: const Text('⚡ 換線重試', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.white60),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _showStallFallbackHud = false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Screen Locked Unlock Hint Overlay
                if (_isScreenLocked)
                  AnimatedOpacity(
                    opacity: _showUnlockHint ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_showUnlockHint,
                      child: Stack(
                        children: [
                          // Center Floating Unlock Capsule
                          Center(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(30),
                                onTap: _unlockScreen,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: const Color(0xFFE50914), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_rounded, color: Color(0xFFE50914), size: 22),
                                      SizedBox(width: 8),
                                      Text(
                                        '點擊解鎖螢幕',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Left-side Floating Unlock Button
                          Positioned(
                            left: 20,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.8),
                                  border: Border.all(color: const Color(0xFFE50914), width: 1.5),
                                ),
                                child: IconButton(
                                  tooltip: '解除螢幕鎖定',
                                  icon: const Icon(Icons.lock_rounded, color: Color(0xFFE50914), size: 24),
                                  onPressed: _unlockScreen,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
}

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
