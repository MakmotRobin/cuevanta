import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/recorded_video.dart';
import '../models/script.dart';
import '../models/teleprompter_settings.dart';
import '../services/camera_service.dart';
import '../services/storage_service.dart';
import '../widgets/prompter_hud_controls.dart';
import '../widgets/prompter_settings_sheet.dart';
import '../widgets/prompter_view.dart';

class StudioRecordingScreen extends StatefulWidget {
  final Script script;

  const StudioRecordingScreen({
    super.key,
    required this.script,
  });

  @override
  State<StudioRecordingScreen> createState() => _StudioRecordingScreenState();
}

class _StudioRecordingScreenState extends State<StudioRecordingScreen> {
  final CameraService _cameraService = CameraService();
  final StorageService _storageService = StorageService();

  late TeleprompterSettings _settings;
  bool _isLoading = true;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  PrompterViewController? _prompterController;
  bool _isPrompterPlaying = false;
  double _currentSpeed = 38.0;
  double _currentFontSize = 28.0;

  // Prompter box area mode (top 45% near selfie lens, or full screen)
  bool _isTopEyeContactMode = true;

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.script.customSpeed ?? 38.0;
    _currentFontSize = widget.script.customFontSize ?? 28.0;
    _loadSettingsAndCamera();
  }

  Future<void> _loadSettingsAndCamera() async {
    _settings = await _storageService.getSettings();
    if (widget.script.customSpeed != null) {
      _currentSpeed = widget.script.customSpeed!;
    } else {
      _currentSpeed = _settings.scrollSpeed;
    }

    if (widget.script.customFontSize != null) {
      _currentFontSize = widget.script.customFontSize!;
    } else {
      _currentFontSize = _settings.fontSize;
    }

    await _cameraService.initialize(preferFront: _settings.preferFrontCamera);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onCountdownFinished() {
    // If auto-record enabled, start recording when prompter starts
    if (_settings.autoRecordVideo && !_isRecording) {
      _startRecordingVideo();
    }
  }

  Future<void> _startRecordingVideo() async {
    if (_isRecording) return;
    final success = await _cameraService.startRecording();
    if (success && mounted) {
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordSeconds++;
          });
        }
      });
    }
  }

  Future<void> _stopRecordingVideo() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();

    final savedFile = await _cameraService.stopRecording();
    if (mounted) {
      setState(() {
        _isRecording = false;
      });

      if (savedFile != null) {
        final fileSize = await savedFile.length();
        final video = RecordedVideo(
          id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
          filePath: savedFile.path,
          scriptId: widget.script.id,
          scriptTitle: widget.script.title,
          recordedAt: DateTime.now(),
          durationSeconds: _recordSeconds,
          fileSizeBytes: fileSize,
        );

        await _storageService.addRecording(video);
        _showTakeCompletedDialog(video);
      }
    }
  }

  void _showTakeCompletedDialog(RecordedVideo video) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
              SizedBox(width: 10),
              Text('Take Recorded!', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Script: ${video.scriptTitle}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                'Duration: ${video.formattedDuration}  •  Size: ${video.formattedSize}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.video_file, color: Color(0xFF818CF8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        video.filePath.split(Platform.pathSeparator).last,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _prompterController?.restart();
              },
              child: const Text('Record Another Take'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PrompterSettingsSheet(
        settings: _settings,
        onSettingsChanged: (updated) {
          setState(() {
            _settings = updated;
            _currentSpeed = updated.scrollSpeed;
            _currentFontSize = updated.fontSize;
          });
          _prompterController?.setSpeed(updated.scrollSpeed);
          _prompterController?.setFontSize(updated.fontSize);
        },
      ),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF6366F1)),
              SizedBox(height: 16),
              Text(
                'Initializing Video Studio...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. LIVE CAMERA PREVIEW BACKGROUND
          Positioned.fill(
            child: _buildCameraPreview(size),
          ),

          // 2. TELEPROMPTER OVERLAY
          Positioned(
            top: topPadding + 64, // Positioned near selfie lens
            left: 0,
            right: 0,
            height: _isTopEyeContactMode ? size.height * 0.44 : size.height * 0.70,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PrompterView(
                script: widget.script,
                settings: _settings,
                isTransparentOverlay: true,
                onControllerReady: (controller) {
                  _prompterController = controller;
                },
                onPlayStateChanged: (playing) {
                  setState(() => _isPrompterPlaying = playing);
                },
                onCountdownFinished: _onCountdownFinished,
                onFinished: () {
                  if (_isRecording) {
                    _stopRecordingVideo();
                  }
                },
              ),
            ),
          ),

          // 3. TOP STATUS BAR (Eye contact indicator, Camera Flip, Close)
          Positioned(
            top: topPadding + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close Studio
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    if (_isRecording) {
                      _stopRecordingVideo();
                    }
                    Navigator.of(context).pop();
                  },
                ),

                // Eye Contact Badge (Points towards camera lens)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward, color: Colors.amberAccent, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'LOOK HERE (CAMERA)',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),

                // Toggle Box Area (Top Eye Contact vs Full Screen) & Flip Camera
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: _isTopEyeContactMode ? 'Expand Prompter' : 'Shrink to Camera Area',
                      icon: Icon(
                        _isTopEyeContactMode ? Icons.fullscreen : Icons.fullscreen_exit,
                      ),
                      onPressed: () {
                        setState(() {
                          _isTopEyeContactMode = !_isTopEyeContactMode;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Switch Camera',
                      icon: const Icon(Icons.flip_camera_ios),
                      onPressed: () async {
                        await _cameraService.toggleCamera();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. RECORDING STATUS PILL (When recording)
          if (_isRecording)
            Positioned(
              top: topPadding + 64,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'REC',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatRecordDuration(_recordSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. BOTTOM STUDIO CONTROLS (Record button + Prompter HUD)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Prompter Navigation & Speed HUD
                PrompterHudControls(
                  controller: _prompterController,
                  script: widget.script,
                  settings: _settings,
                  isPlaying: _isPrompterPlaying,
                  currentSpeed: _currentSpeed,
                  currentFontSize: _currentFontSize,
                  onSpeedChanged: (speed) {
                    setState(() => _currentSpeed = speed);
                    _prompterController?.setSpeed(speed);
                  },
                  onFontSizeChanged: (size) {
                    setState(() => _currentFontSize = size);
                    _prompterController?.setFontSize(size);
                  },
                  onToggleMirror: () {
                    setState(() {
                      _settings.mirrorHorizontal = !_settings.mirrorHorizontal;
                    });
                    _storageService.saveSettings(_settings);
                  },
                  onOpenSettings: _openSettings,
                ),

                const SizedBox(height: 16),

                // Video Record Shutter Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_isRecording) {
                          _stopRecordingVideo();
                        } else {
                          _startRecordingVideo();
                          if (!_isPrompterPlaying) {
                            _prompterController?.play();
                          }
                        }
                      },
                      child: Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(_isRecording ? 10 : 36),
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.videocam,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview(Size size) {
    if (_cameraService.isInitialized && _cameraService.controller != null) {
      return CameraPreview(_cameraService.controller!);
    }

    // Simulated Camera Preview Fallback (For emulator/preview environments)
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0A0F1D),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'Camera Studio Active',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _cameraService.errorMessage ?? 'Ready to read & record',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRecordDuration(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
