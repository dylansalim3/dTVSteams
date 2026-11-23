import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../catalog/parser.dart';
import '../services/download_manager.dart';
import '../services/pip_manager.dart';
import '../services/playback_history_manager.dart';
import 'downloads_screen.dart';

class NativePlayerScreen extends StatefulWidget {
  final CatalogEpisode episode;
  final int initialPartIndex;
  final File? localFile;

  const NativePlayerScreen({
    super.key,
    required this.episode,
    this.initialPartIndex = 0,
    this.localFile,
  });

  @override
  State<NativePlayerScreen> createState() => _NativePlayerScreenState();
}

class _NativePlayerScreenState extends State<NativePlayerScreen> {
  late int _currentPartIndex;
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showOsd = true;
  Timer? _osdTimer;
  double _playbackSpeed = 1.0;
  final List<double> _availableSpeeds = [1.0, 1.25, 1.5, 2.0];
  bool _isAutoAdvancing = false;
  final DownloadManager _downloadManager = DownloadManager();
  final PlaybackHistoryManager _historyManager = PlaybackHistoryManager();
  final PipManager _pipManager = PipManager();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _currentPartIndex = widget.initialPartIndex;
    _pipManager.isInPipMode.addListener(_onPipUpdate);
    _pipManager.setAutoPip(true);
    _downloadManager.addListener(_onDownloadUpdate);
    _historyManager.init();
    _initPlayerForPart(_currentPartIndex);
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
    setState(() {
      _showOsd = !_showOsd;
      if (_showOsd) {
        _resetOsdTimer();
      }
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
      final downloaded = _downloadManager.getLocalFile(widget.episode.id, part.label);
      if (downloaded != null && downloaded.existsSync()) {
        fileToPlay = downloaded;
      }
    }

    if (fileToPlay != null) {
      try {
        final controller = VideoPlayerController.file(fileToPlay);
        await controller.initialize();
        await _checkAndResumeHistory(controller, part);
        controller.addListener(_videoPlayerListener);
        await controller.setPlaybackSpeed(_playbackSpeed);
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
      await _checkAndResumeHistory(controller, part);
      controller.addListener(_videoPlayerListener);
      await controller.setPlaybackSpeed(_playbackSpeed);
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

    // Track real-time playback position
    if (controller.value.isPlaying) {
      _persistCurrentPosition(force: false);
    }

    // Autoplay next part when finished
    if (!_isAutoAdvancing && controller.value.duration > const Duration(seconds: 2)) {
      final isFinished = controller.value.isCompleted ||
          (controller.value.position >= controller.value.duration - const Duration(milliseconds: 700));

      if (isFinished) {
        // Offer quick cleanup for offline downloaded file once watched to completion
        final parts = widget.episode.parts;
        final finishedPart = parts.isNotEmpty && _currentPartIndex < parts.length ? parts[_currentPartIndex] : null;
        if (finishedPart != null && _downloadManager.isDownloaded(widget.episode.id, finishedPart.label)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已看完「${finishedPart.label}」，可清理離線檔以節省空間'),
              duration: const Duration(seconds: 4),
              backgroundColor: const Color(0xFF1E1E1E),
              action: SnackBarAction(
                label: '刪除檔案',
                textColor: const Color(0xFFE50914),
                onPressed: () => _downloadManager.deleteDownload(widget.episode.id, finishedPart.label),
              ),
            ),
          );
        }

        final nextPart = _currentPartIndex + 1;
        if (nextPart < widget.episode.parts.length) {
          _isAutoAdvancing = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.playlist_play, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('分段播放完畢，自動為您播放：${widget.episode.parts[nextPart].label}'),
                ],
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFFE50914),
            ),
          );
          _switchPart(nextPart);
          return;
        }
      }
    }
    setState(() {});
  }

  void _switchPart(int newIndex) {
    if (newIndex == _currentPartIndex && _controller != null) return;
    _persistCurrentPosition(force: true);
    setState(() {
      _currentPartIndex = newIndex;
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

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _persistCurrentPosition(force: true);
    _pipManager.setAutoPip(false);
    _pipManager.isInPipMode.removeListener(_onPipUpdate);
    _downloadManager.removeListener(_onDownloadUpdate);
    _osdTimer?.cancel();
    _controller?.removeListener(_videoPlayerListener);
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
    setState(() {});
  }

  void _seekRelative(int seconds) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final target = c.value.position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > c.value.duration ? c.value.duration : target);
    c.seekTo(clamped);
    _resetOsdTimer();
  }

  void _triggerDownloadCurrentPart() {
    final parts = widget.episode.parts;
    if (parts.isEmpty || _currentPartIndex >= parts.length) return;
    final part = parts[_currentPartIndex];

    if (_downloadManager.isDownloaded(widget.episode.id, part.label)) {
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

    if (_downloadManager.isDownloading(widget.episode.id, part.label)) {
      final item = _downloadManager.getItem(widget.episode.id, part.label);
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

    _downloadManager.startDownload(widget.episode, part);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('開始下載 ${widget.episode.title} - ${part.label}'),
        backgroundColor: const Color(0xFFE50914),
        action: SnackBarAction(
          label: '查看進度',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DownloadsScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.episode.parts;
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
        _downloadManager.isDownloaded(widget.episode.id, currentPart.label);
    final isCurPartDownloading = currentPart != null &&
        _downloadManager.isDownloading(widget.episode.id, currentPart.label);
    final downloadItem = currentPart != null
        ? _downloadManager.getItem(widget.episode.id, currentPart.label)
        : null;

    if (_pipManager.isInPipMode.value) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: isInitialized
              ? AspectRatio(
                  aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9,
                  child: VideoPlayer(controller),
                )
              : const SizedBox(),
        ),
      );
    }

    return Scaffold(
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
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
          const SingleActivator(LogicalKeyboardKey.gameButtonB): () => Navigator.of(context).pop(),
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleOsd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video Surface View (Backed by native Android Media3 ExoPlayer)
                Center(
                  child: isInitialized
                      ? AspectRatio(
                          aspectRatio: controller.value.aspectRatio > 0
                              ? controller.value.aspectRatio
                              : 16 / 9,
                          child: VideoPlayer(controller),
                        )
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
                          : Container(color: Colors.black)),
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
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: () => _initPlayerForPart(_currentPartIndex, forceLiveResolve: true),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('重新解析並重試 (Self-Healing Retry)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Animated OSD Controls
                AnimatedOpacity(
                  opacity: _showOsd ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_showOsd,
                    child: Stack(
                      children: [
                        // Top Gradient Header
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: SafeArea(
                              bottom: false,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.episode.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (currentPart != null)
                                          Text(
                                            '${currentPart.label} • ${isCurPartDownloaded ? '本機離線播放' : 'ExoPlayer 1080p Engine'}',
                                            style: TextStyle(
                                              color: isCurPartDownloaded ? const Color(0xFF46D369) : const Color(0xFFE50914),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

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
                                ],
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
                                    Row(
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
                                          _controller?.seekTo(Duration(milliseconds: targetMs));
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
                                      Text(
                                        '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
                                      ),
                                      const Spacer(),
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
              ],
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
