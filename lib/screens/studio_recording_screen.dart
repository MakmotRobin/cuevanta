import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_orientations.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recorded_video.dart';
import '../models/script.dart';
import '../models/teleprompter_settings.dart';
import '../services/camera_service.dart';
import '../services/recording_format.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/prompter_hud_controls.dart';
import '../widgets/prompter_settings_sheet.dart';
import '../voice/voice_follow_host.dart';
import '../widgets/prompter_view.dart';
import 'video_player_screen.dart';

class StudioRecordingScreen extends StatefulWidget {
  final Script script;

  const StudioRecordingScreen({
    super.key,
    required this.script,
  });

  @override
  State<StudioRecordingScreen> createState() => _StudioRecordingScreenState();
}

class _StudioRecordingScreenState extends State<StudioRecordingScreen>
    with WidgetsBindingObserver, VoiceFollowHost {
  static const double _compactPrompterHeightFraction = 0.40;
  static const double _expandedPrompterHeightFraction = 0.55;
  static const double _gapBelowLens = 6;

  final CameraService _cameraService = CameraService();
  final StorageService _storageService = StorageService();

  late TeleprompterSettings _settings;
  bool _isLoading = true;
  bool _isRecording = false;
  bool _isSavingTake = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  PrompterViewController? _prompterController;
  bool _isPrompterPlaying = false;
  double _currentSpeed = 38.0;
  double _currentFontSize = 28.0;

  bool _isCompactPrompter = true;
  RecordingQuality? _openedQuality;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(studioOrientations);
    _loadSettingsAndCamera();
  }

  Future<void> _loadSettingsAndCamera() async {
    _settings = await _storageService.getSettings();
    _currentSpeed = widget.script.customSpeed ?? _settings.scrollSpeed;
    _currentFontSize = widget.script.customFontSize ?? _settings.fontSize;

    await _openCamera();
    prepareVoiceFollow(widget.script, _settings);

    if (mounted) setState(() => _isLoading = false);
  }

  /// Releases the camera when the app is backgrounded so other apps can use it,
  /// and re-acquires it on return. An in-progress take is saved first.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isLoading) return;
    if (state == AppLifecycleState.inactive) {
      _releaseCameraForBackground();
    } else if (state == AppLifecycleState.resumed && !_cameraService.isInitialized) {
      _reacquireCamera();
    }
  }

  Future<void> _releaseCameraForBackground() async {
    await voiceFollow?.suspend();
    if (_isRecording) await _finishTake();
    await _cameraService.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _reacquireCamera() async {
    await _openCamera();
    if (mounted) setState(() {});
    await startVoiceFollow(_settings);
  }

  Future<void> _openCamera() {
    _openedQuality = _settings.recordingQuality;
    return _cameraService.initialize(
        preferFront: _settings.preferFrontCamera,
        quality: _settings.recordingQuality,
      );
  }

  Future<void> _reopenCameraForQuality(RecordingQuality quality) async {
    if (_isRecording || quality == _openedQuality) return;
    await _openCamera();
    if (mounted) setState(() {});
  }

  @override
  int currentParagraphAtGuide() => _prompterController?.paragraphAtGuide() ?? 0;

  void _onCountdownFinished() {
    if (_settings.autoRecordVideo) {
      _startRecordingVideo();
    } else {
      startVoiceFollow(_settings);
    }
  }

  /// Voice-follow gives up the microphone first: on Android the camera's
  /// recording would otherwise leave the speech recogniser hearing silence.
  Future<void> _startRecordingVideo() async {
    if (_isRecording) return;
    await voiceFollow?.suspend();
    final started = await _cameraService.startRecording();
    if (!mounted) return;
    if (!started) {
      _showCameraUnavailableMessage();
      await startVoiceFollow(_settings);
      return;
    }

    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  void _showCameraUnavailableMessage() {
    final reason = _cameraService.errorMessage ?? 'Camera is not ready.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Not recording: $reason'),
          action: _cameraService.isPermissionDenied
              ? SnackBarAction(label: 'Settings', onPressed: _cameraService.openPermissionSettings)
              : null,
        ),
      );
  }

  /// Stops the camera and stores the take. Returns null if nothing was saved.
  Future<RecordedVideo?> _finishTake() async {
    if (!_isRecording) return null;
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isSavingTake = true;
    });

    final savedFile = await _cameraService.stopRecording();
    RecordedVideo? video;
    if (savedFile != null) {
      video = RecordedVideo(
        id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
        filePath: savedFile.path,
        scriptId: widget.script.id,
        scriptTitle: widget.script.title,
        recordedAt: DateTime.now(),
        durationSeconds: _recordSeconds,
        fileSizeBytes: await savedFile.length(),
      );
      await _storageService.addRecording(video);
    }

    if (mounted) setState(() => _isSavingTake = false);
    await startVoiceFollow(_settings);
    return video;
  }

  Future<void> _stopRecordingAndShowSummary() async {
    _prompterController?.pause();
    final video = await _finishTake();
    if (!mounted) return;
    if (video == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The take could not be saved.')),
      );
      return;
    }
    _showTakeCompletedDialog(video);
  }

  Future<void> _closeStudio() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final video = await _finishTake();
    if (video != null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Take saved to Recorded Takes')),
      );
    }
    navigator.pop();
  }

  Future<void> _toggleRecording() async {
    if (_isSavingTake) return;
    if (_isRecording) {
      await _stopRecordingAndShowSummary();
      return;
    }
    await _startRecordingVideo();
    if (_isRecording && !_isPrompterPlaying) _prompterController?.play();
  }

  Future<void> _switchCamera() async {
    await _cameraService.toggleCamera();
    if (mounted) setState(() {});
  }

  void _recordAnotherTake() {
    _prompterController?.restart();
  }

  void _shareTake(RecordedVideo video) {
    if (!File(video.filePath).existsSync()) return;
    SharePlus.instance.share(
      ShareParams(
        files: [XFile(video.filePath)],
        subject: 'Recorded Take: ${video.scriptTitle}',
      ),
    );
  }

  void _showTakeCompletedDialog(RecordedVideo video) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 40),
          title: const Text('Take recorded'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                video.scriptTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatChip(icon: Icons.timer_outlined, label: video.formattedDuration),
                  const SizedBox(width: 8),
                  _StatChip(icon: Icons.sd_storage_outlined, label: video.formattedSize),
                ],
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsOverflowAlignment: OverflowBarAlignment.center,
          actionsOverflowDirection: VerticalDirection.down,
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Watch'),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video)),
                );
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('Share'),
              onPressed: () => _shareTake(video),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('New take'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _recordAnotherTake();
              },
            ),
            TextButton(
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

  void _toggleVoiceFollowUnlessRecording() {
    if (_isRecording) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Voice follow comes back when the take stops. The camera has the microphone.'),
        ));
      return;
    }
    toggleVoiceFollow(widget.script, _settings);
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PrompterSettingsSheet(
        settings: _settings,
        onSettingsChanged: (updated) {
          _reopenCameraForQuality(updated.recordingQuality);
          setState(() {
            _settings = updated;
            _currentSpeed = updated.scrollSpeed;
            _currentFontSize = updated.fontSize;
          });
          _prompterController?.setSpeed(updated.scrollSpeed);
          _prompterController?.setFontSize(updated.fontSize);
          if (!_isRecording) applyVoiceFollowSetting(widget.script, updated);
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(allAppOrientations);
    _recordTimer?.cancel();
    disposeVoiceFollow();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _StudioLoadingView();

    final media = MediaQuery.of(context);
    final prompterTop = media.padding.top + _gapBelowLens;
    final heightFraction =
        _isCompactPrompter ? _compactPrompterHeightFraction : _expandedPrompterHeightFraction;

    return PopScope(
      canPop: !_isRecording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeStudio();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _buildCameraPreview()),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              top: prompterTop,
              left: 10,
              right: 10,
              height: media.size.height * heightFraction,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                child: PrompterView(
                  script: widget.script,
                  settings: _settings,
                  isTransparentOverlay: true,
                  onControllerReady: (controller) => _prompterController = controller,
                  onPlayStateChanged: (playing) => setState(() => _isPrompterPlaying = playing),
                  onCountdownFinished: _onCountdownFinished,
                  voiceFollow: voiceFollow,
                  onFinished: () {
                    if (_isRecording) _stopRecordingAndShowSummary();
                  },
                ),
              ),
            ),
            Positioned(
              bottom: media.padding.bottom + 16,
              left: 12,
              right: 12,
              child: _buildBottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _isRecording
            ? _RecordingIndicator(seconds: _recordSeconds, isVoiceFollowPaused: voiceFollow != null)
            : _FormatChip(quality: _settings.recordingQuality),
        const SizedBox(height: 12),
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
            setState(() => _settings.mirrorHorizontal = !_settings.mirrorHorizontal);
            _storageService.saveSettings(_settings);
          },
          onOpenSettings: _openSettings,
          onToggleVoiceFollow: _toggleVoiceFollowUnlessRecording,
          voiceFollowState: voiceFollow?.state,
        ),
        const SizedBox(height: 16),
        _buildShutterRow(),
      ],
    );
  }

  /// Camera-app layout: close on the left, shutter centred, camera tools on the right.
  Widget _buildShutterRow() {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _OverlayIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close studio',
              onPressed: _closeStudio,
            ),
          ),
        ),
        _ShutterButton(isRecording: _isRecording, isBusy: _isSavingTake, onTap: _toggleRecording),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _OverlayIconButton(
                icon: _isCompactPrompter ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
                tooltip: _isCompactPrompter ? 'Taller prompter' : 'Shorter prompter',
                onPressed: () => setState(() => _isCompactPrompter = !_isCompactPrompter),
              ),
              const SizedBox(width: 8),
              _OverlayIconButton(
                icon: Icons.flip_camera_ios_rounded,
                tooltip: _isRecording ? 'Can\'t switch while recording' : 'Switch camera',
                onPressed: _cameraService.canSwitchCamera && !_isRecording ? _switchCamera : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraService.controller;
    if (_cameraService.isInitialized && controller != null && !_cameraService.isSimulated) {
      return _RecordedFramePreview(controller: controller);
    }
    return _CameraUnavailableView(
      message: _cameraService.errorMessage ?? 'Starting camera…',
      onOpenSettings:
          _cameraService.isPermissionDenied ? _cameraService.openPermissionSettings : null,
    );
  }
}

/// Shows exactly the frame that is recorded (9:16), pinned just below the
/// status bar so the script overlay sits right under the lens.
class _RecordedFramePreview extends StatelessWidget {
  final CameraController controller;

  const _RecordedFramePreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.ink,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Align(
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _CameraUnavailableView extends StatelessWidget {
  final String message;
  final VoidCallback? onOpenSettings;

  const _CameraUnavailableView({required this.message, this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          radius: 1.2,
          colors: [AppTheme.cardDark, AppTheme.ink],
        ),
      ),
      alignment: const Alignment(0, 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
          ),
          if (onOpenSettings != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Open settings'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudioLoadingView extends StatelessWidget {
  const _StudioLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text('Starting camera…', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _OverlayIconButton({required this.icon, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      style: IconButton.styleFrom(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black26,
        disabledForegroundColor: Colors.white30,
      ),
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

/// Shows the recording format before a take ("9:16 · 1080P · 30 FPS").
class _FormatChip extends StatelessWidget {
  final RecordingQuality quality;

  const _FormatChip({required this.quality});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.ink.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.45)),
      ),
      child: Text(
        '9:16  ·  ${quality.label.toUpperCase()}  ·  ${RecordingFormat.framesPerSecond} FPS',
        style: AppTheme.eyebrow.copyWith(fontSize: 9.5, letterSpacing: 2),
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  final int seconds;
  final bool isVoiceFollowPaused;

  const _RecordingIndicator({required this.seconds, required this.isVoiceFollowPaused});

  String get _formattedDuration {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dotVisible = seconds.isEven;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.recordingRed.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: dotVisible ? 1 : 0.25,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'REC  $_formattedDuration',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.8,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    if (!isVoiceFollowPaused) return pill;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill,
        const SizedBox(height: 6),
        Text(
          'TIMED SCROLL WHILE RECORDING',
          style: AppTheme.eyebrow.copyWith(fontSize: 8.5, letterSpacing: 1.6),
        ),
      ],
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final bool isRecording;
  final bool isBusy;
  final VoidCallback onTap;

  const _ShutterButton({required this.isRecording, required this.isBusy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isRecording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        onTap: isBusy ? null : onTap,
        child: Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isRecording ? 30 : 62,
              height: isRecording ? 30 : 62,
              decoration: BoxDecoration(
                color: AppTheme.recordingRed,
                borderRadius: BorderRadius.circular(isRecording ? 8 : 31),
              ),
              child: isBusy
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryLight),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
