import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/script.dart';
import '../models/teleprompter_settings.dart';
import '../services/storage_service.dart';
import '../widgets/prompter_hud_controls.dart';
import '../widgets/prompter_settings_sheet.dart';
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

class _PrompterScreenState extends State<PrompterScreen> {
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
    // Keep device screen awake & enter immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _currentSpeed = widget.script.customSpeed ?? 38.0;
    _currentFontSize = widget.script.customFontSize ?? 28.0;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
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

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _startHideControlsTimer();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls && _isPlaying) {
      _startHideControlsTimer();
    }
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
        },
      ),
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _settings.backgroundColor,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _toggleControlsVisibility();
          _prompterController?.togglePlayPause();
        },
        child: Stack(
          children: [
            // Fullscreen Prompter View
            Positioned.fill(
              child: PrompterView(
                script: widget.script,
                settings: _settings,
                onControllerReady: (controller) {
                  _prompterController = controller;
                },
                onPlayStateChanged: (playing) {
                  setState(() => _isPlaying = playing);
                  if (playing) {
                    _startHideControlsTimer();
                  } else {
                    setState(() => _showControls = true);
                  }
                },
              ),
            ),

            // Top Header Bar (Back button, Title, Marker Count)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              top: _showControls ? 24 : -80,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          widget.script.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_settings.mirrorHorizontal || _settings.mirrorVertical)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: const Text(
                          'MIRROR ON',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // Bottom HUD Controls
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              bottom: _showControls ? 28 : -100,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Center(
                  child: PrompterHudControls(
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
                    onToggleMirror: () {
                      setState(() {
                        _settings.mirrorHorizontal = !_settings.mirrorHorizontal;
                      });
                      _storageService.saveSettings(_settings);
                    },
                    onOpenSettings: _openSettings,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
