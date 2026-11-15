import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../catalog/parser.dart';

class NativePlayerScreen extends StatefulWidget {
  final CatalogEpisode episode;
  final int initialPartIndex;

  const NativePlayerScreen({
    super.key,
    required this.episode,
    this.initialPartIndex = 0,
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

  @override
  void initState() {
    super.initState();
    _currentPartIndex = widget.initialPartIndex;
    _initPlayerForPart(_currentPartIndex);
  }

  Future<void> _initPlayerForPart(int partIndex) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await _controller?.dispose();
    _controller = null;

    final parts = widget.episode.parts;
    final part = parts.isNotEmpty && partIndex < parts.length ? parts[partIndex] : null;
    String? streamUrl = part?.streamUrl.isNotEmpty == true
        ? part!.streamUrl
        : (part?.fallbackStreamUrl.isNotEmpty == true ? part!.fallbackStreamUrl : null);

    // Dynamic resolution of Part stream URL if not pre-populated (Pure Native Dart parser)
    if ((streamUrl == null || streamUrl.isEmpty) && part != null && part.url.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(part.url)).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final parsed = CatalogParser.parseStreamUrl(res.body);
          if (parsed != null && parsed.isNotEmpty) {
            streamUrl = parsed;
          }
        }
      } catch (_) {
        // Fallback or network error handled below
      }
    }

    if (streamUrl == null || streamUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '此分段尚未取得串流播放網址 (No stream URL resolved)';
        });
      }
      return;
    }

    try {
      final uri = Uri.parse(streamUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      controller.addListener(_videoPlayerListener);
      await controller.play();

      if (mounted) {
        setState(() {
          _controller = controller;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '無法播放此串流格式：$e\n(若為網路受限，支援手動切換 Part 或重試)';
        });
      }
    }
  }

  void _videoPlayerListener() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    // Auto-advance to next part when completed
    if (controller.value.isInitialized &&
        controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      final nextPart = _currentPartIndex + 1;
      if (nextPart < widget.episode.parts.length) {
        _switchPart(nextPart);
      }
    }
    setState(() {});
  }

  void _switchPart(int newIndex) {
    if (newIndex == _currentPartIndex) return;
    setState(() => _currentPartIndex = newIndex);
    _initPlayerForPart(newIndex);
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoPlayerListener);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.space): _togglePlayPause,
          const SingleActivator(LogicalKeyboardKey.select): _togglePlayPause,
          const SingleActivator(LogicalKeyboardKey.enter): _togglePlayPause,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _seekRelative(-10),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _seekRelative(10),
          const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            onTap: () => setState(() => _showOsd = !_showOsd),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video Surface View (Backed by native Android ExoPlayer)
                Center(
                  child: isInitialized
                      ? AspectRatio(
                          aspectRatio: controller.value.aspectRatio > 0
                              ? controller.value.aspectRatio
                              : 16 / 9,
                          child: VideoPlayer(controller),
                        )
                      : (_isLoading
                          ? const CircularProgressIndicator(color: Color(0xFFE50914))
                          : Image.network(
                              widget.episode.backdrop,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(color: Colors.black),
                            )),
                ),

                // Error Overlay
                if (_errorMessage != null)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                            ),
                            onPressed: () => _initPlayerForPart(_currentPartIndex),
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: const Text('重試播放', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),

                // OSD Overlay
                if (_showOsd) ...[
                  // Top Gradient & Header
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (currentPart != null)
                                  Text(
                                    '${currentPart.label} • ExoPlayer Native Engine',
                                    style: const TextStyle(
                                      color: Color(0xFFE50914),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Gradient & Controls
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Part Selection
                          if (parts.length > 1) ...[
                            const Text(
                              '分段 (Parts):',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: List.generate(parts.length, (idx) {
                                final p = parts[idx];
                                final isSelected = idx == _currentPartIndex;
                                return ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected
                                        ? const Color(0xFFE50914)
                                        : Colors.white.withValues(alpha: 0.2),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                  ),
                                  onPressed: () => _switchPart(idx),
                                  child: Text(p.label),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Progress bar
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
                          ),
                          const SizedBox(height: 8),

                          // Timing & Controls
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                onPressed: _togglePlayPause,
                              ),
                              IconButton(
                                icon: const Icon(Icons.replay_10, color: Colors.white),
                                onPressed: () => _seekRelative(-10),
                              ),
                              IconButton(
                                icon: const Icon(Icons.forward_10, color: Colors.white),
                                onPressed: () => _seekRelative(10),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white30),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'HD',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
