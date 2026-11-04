import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/script.dart';
import '../models/teleprompter_settings.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/prompter_hud_controls.dart';
import '../widgets/prompter_settings_sheet.dart';
import '../voice/voice_follow_host.dart';
import '../widgets/prompter_view.dart';

class PrompterScreen extends StatefulWidget {
  final Script script;

  const PrompterScreen({
    super.key,
    required this.script,
  });

  @override
  State<PrompterScreen> createState() => _PrompterScreenState();
}

class _PrompterScreenState extends State<PrompterScreen> with VoiceFollowHost {
  static const Duration _autoHideDelay = Duration(seconds: 4);
  static const Duration _fadeDuration = Duration(milliseconds: 250);

  final StorageService _storageService = StorageService();

  late TeleprompterSettings _settings;
  bool _isLoading = true;
  PrompterViewController? _prompterController;
  bool _isPlaying = false;
  double _currentSpeed = 38.0;
  double _currentFontSize = 28.0;

  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settings = await _storageService.getSettings();
    _currentSpeed = widget.script.customSpeed ?? _settings.scrollSpeed;
    _currentFontSize = widget.script.customFontSize ?? _settings.fontSize;
    prepareVoiceFollow(widget.script, _settings);

    if (mounted) {
      setState(() => _isLoading = false);
      _scheduleControlsAutoHide();
    }
  }

  void _scheduleControlsAutoHide() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(_autoHideDelay, () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _revealControls() {
    if (!_showControls) setState(() => _showControls = true);
    _scheduleControlsAutoHide();
  }

  void _handlePlayStateChanged(bool playing) {
    setState(() {
      _isPlaying = playing;
      if (!playing) _showControls = true;
    });
    if (playing) _scheduleControlsAutoHide();
  }

  @override
  int currentParagraphAtGuide() => _prompterController?.paragraphAtGuide() ?? 0;

  void _toggleMirror() {
    setState(() => _settings.mirrorHorizontal = !_settings.mirrorHorizontal);
    _storageService.saveSettings(_settings);
  }

  void _openSettings() {
    _hideControlsTimer?.cancel();
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
          applyVoiceFollowSetting(widget.script, updated);
        },
      ),
    ).whenComplete(_scheduleControlsAutoHide);
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    disposeVoiceFollow();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: _settings.backgroundColor,
      body: Listener(
        // Listener (not GestureDetector) so taps still reach the prompter's play/pause.
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _revealControls(),
        child: Stack(
          children: [
            Positioned.fill(
              child: PrompterView(
                script: widget.script,
                settings: _settings,
                onControllerReady: (controller) => _prompterController = controller,
                onPlayStateChanged: _handlePlayStateChanged,
                onCountdownFinished: () => startVoiceFollow(_settings),
                voiceFollow: voiceFollow,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _fadingControls(
                offsetWhenHidden: const Offset(0, -1),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _buildHeader(),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _fadingControls(
                offsetWhenHidden: const Offset(0, 1),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: Center(child: _buildHud()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fadingControls({required Offset offsetWhenHidden, required Widget child}) {
    return IgnorePointer(
      ignoring: !_showControls,
      child: AnimatedSlide(
        duration: _fadeDuration,
        curve: Curves.easeOut,
        offset: _showControls ? Offset.zero : offsetWhenHidden,
        child: AnimatedOpacity(
          duration: _fadeDuration,
          opacity: _showControls ? 1 : 0,
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isMirrored = _settings.mirrorHorizontal || _settings.mirrorVertical;
    return Row(
      children: [
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
          ),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.surfaceDark),
            ),
            child: Text(
              widget.script.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (isMirrored) const _MirrorBadge() else const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildHud() {
    return PrompterHudControls(
      controller: _prompterController,
      script: widget.script,
      settings: _settings,
      isPlaying: _isPlaying,
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
      onToggleMirror: _toggleMirror,
      onOpenSettings: _openSettings,
      onToggleVoiceFollow: () => toggleVoiceFollow(widget.script, _settings),
      voiceFollowState: voiceFollow?.state,
    );
  }
}

class _MirrorBadge extends StatelessWidget {
  const _MirrorBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold),
      ),
      child: const Text(
        'MIRROR',
        style: TextStyle(color: AppTheme.gold, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
