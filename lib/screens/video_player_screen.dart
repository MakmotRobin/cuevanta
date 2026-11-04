import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/recorded_video.dart';
import '../services/storage_service.dart';
import '../widgets/share_action.dart';
import '../theme/app_theme.dart';

class VideoPlayerScreen extends StatefulWidget {
  final RecordedVideo video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = true;
  late bool _isBest = widget.video.isBest;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final file = File(widget.video.filePath);
    if (!await file.exists()) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Video file does not exist on disk.\n${widget.video.filePath}';
      });
      return;
    }

    try {
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {
        _controller = controller;
        _isInitialized = true;
      });
      controller.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Could not load video player: $e';
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      if (_controller!.value.position >= _controller!.value.duration) {
        _controller!.seekTo(Duration.zero);
      }
      _controller!.play();
    }
    setState(() => _showControls = true);
  }

  Future<void> _toggleBest() async {
    await StorageService().toggleBestTake(widget.video.id);
    if (mounted) setState(() => _isBest = !_isBest);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.video.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              _isBest ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isBest ? AppTheme.gold : null,
            ),
            tooltip: _isBest ? 'Best take (tap to clear)' : 'Mark as best take',
            onPressed: _toggleBest,
          ),
          ShareAction(
            takes: [widget.video],
            builder: (context, isPreparing, onPressed) => IconButton(
              icon: isPreparing ? const SharePreparingIndicator() : const Icon(Icons.ios_share_rounded),
              tooltip: isPreparing ? 'Preparing to share…' : 'Share take',
              onPressed: onPressed,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _hasError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 56, color: AppTheme.recordingRed),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to play video',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage ?? 'Unknown error occurred.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            : !_isInitialized
                ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() => _showControls = !_showControls);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Video Frame
                        Center(
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio > 0
                                ? _controller!.value.aspectRatio
                                : 9 / 16,
                            child: VideoPlayer(_controller!),
                          ),
                        ),

                        // Center Play / Pause Indicator
                        if (_showControls || !_controller!.value.isPlaying)
                          GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _controller!.value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 54,
                                color: Colors.white,
                              ),
                            ),
                          ),

                        // Bottom Scrub & Time Controls
                        if (_showControls)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.hudBackground,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Scrub bar
                                  VideoProgressIndicator(
                                    _controller!,
                                    allowScrubbing: true,
                                    colors: const VideoProgressColors(
                                      playedColor: AppTheme.gold,
                                      bufferedColor: AppTheme.border,
                                      backgroundColor: Colors.white24,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  // Time and replay row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(_controller!.value.position),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.replay_10, color: Colors.white70, size: 20),
                                            tooltip: 'Rewind 10s',
                                            onPressed: () {
                                              final newPos = _controller!.value.position - const Duration(seconds: 10);
                                              _controller!.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                              color: Colors.white,
                                            ),
                                            onPressed: _togglePlayPause,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.forward_10, color: Colors.white70, size: 20),
                                            tooltip: 'Forward 10s',
                                            onPressed: () {
                                              final newPos = _controller!.value.position + const Duration(seconds: 10);
                                              _controller!.seekTo(newPos > _controller!.value.duration ? _controller!.value.duration : newPos);
                                            },
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _formatDuration(_controller!.value.duration),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
