import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/script.dart';
import '../models/teleprompter_settings.dart';
import 'reading_guide_painter.dart';

class PrompterView extends StatefulWidget {
  final Script script;
  final TeleprompterSettings settings;
  final bool isTransparentOverlay;
  final VoidCallback? onFinished;
  final ValueChanged<bool>? onPlayStateChanged;
  final VoidCallback? onCountdownFinished;
  final Function(PrompterViewController controller)? onControllerReady;

  const PrompterView({
    super.key,
    required this.script,
    required this.settings,
    this.isTransparentOverlay = false,
    this.onFinished,
    this.onPlayStateChanged,
    this.onCountdownFinished,
    this.onControllerReady,
  });

  @override
  State<PrompterView> createState() => _PrompterViewState();
}

class PrompterViewController {
  final VoidCallback play;
  final VoidCallback pause;
  final VoidCallback togglePlayPause;
  final VoidCallback restart;
  final ValueChanged<double> setSpeed;
  final ValueChanged<double> setFontSize;
  final Function(int markerIndex) jumpToMarker;
  final bool Function() isPlaying;
  final double Function() currentSpeed;

  PrompterViewController({
    required this.play,
    required this.pause,
    required this.togglePlayPause,
    required this.restart,
    required this.setSpeed,
    required this.setFontSize,
    required this.jumpToMarker,
    required this.isPlaying,
    required this.currentSpeed,
  });
}

class _PrompterViewState extends State<PrompterView>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  bool _isPlaying = false;
  int _countdownNumber = 0;
  Timer? _countdownTimer;

  late double _speed;
  late double _fontSize;
  late double _lineSpacing;
  late bool _mirrorX;
  late bool _mirrorY;

  final GlobalKey _contentKey = GlobalKey();
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _speed = widget.script.customSpeed ?? widget.settings.scrollSpeed;
    _fontSize = widget.script.customFontSize ?? widget.settings.fontSize;
    _lineSpacing = widget.settings.lineSpacing;
    _mirrorX = widget.settings.mirrorHorizontal;
    _mirrorY = widget.settings.mirrorVertical;

    _scrollController = ScrollController();

    _ticker = createTicker(_onTick);

    widget.onControllerReady?.call(
      PrompterViewController(
        play: _startScrolling,
        pause: _pauseScrolling,
        togglePlayPause: _togglePlayPause,
        restart: _restartToTop,
        setSpeed: _updateSpeed,
        setFontSize: (size) => setState(() => _fontSize = size),
        jumpToMarker: _jumpToMarker,
        isPlaying: () => _isPlaying,
        currentSpeed: () => _speed,
      ),
    );

    // If countdown is configured, start countdown immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.settings.countdownDuration > 0) {
        _startCountdown();
      } else {
        _startScrolling();
      }
    });
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying || !_scrollController.hasClients) {
      _lastElapsed = elapsed;
      return;
    }

    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }

    final delta = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    if (delta <= 0) return;

    final currentOffset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final newOffset = currentOffset + (_speed * delta);

    if (newOffset >= maxScroll) {
      _scrollController.jumpTo(maxScroll);
      _pauseScrolling();
      widget.onFinished?.call();
    } else {
      _scrollController.jumpTo(newOffset);
    }
  }

  void _startCountdown() {
    setState(() {
      _countdownNumber = widget.settings.countdownDuration;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownNumber > 1) {
        setState(() {
          _countdownNumber--;
        });
      } else {
        timer.cancel();
        setState(() {
          _countdownNumber = 0;
        });
        widget.onCountdownFinished?.call();
        _startScrolling();
      }
    });
  }

  void _startScrolling() {
    if (_isPlaying) return;
    setState(() {
      _isPlaying = true;
    });
    _lastElapsed = Duration.zero;
    if (!_ticker.isTicking) {
      _ticker.start();
    }
    widget.onPlayStateChanged?.call(true);
  }

  void _pauseScrolling() {
    if (!_isPlaying) return;
    setState(() {
      _isPlaying = false;
    });
    if (_ticker.isTicking) {
      _ticker.stop();
    }
    widget.onPlayStateChanged?.call(false);
  }

  void _togglePlayPause() {
    if (_countdownNumber > 0) {
      _countdownTimer?.cancel();
      setState(() => _countdownNumber = 0);
      _startScrolling();
      return;
    }

    if (_isPlaying) {
      _pauseScrolling();
    } else {
      _startScrolling();
    }
  }

  void _restartToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
    _lastElapsed = Duration.zero;
  }

  void _updateSpeed(double newSpeed) {
    setState(() {
      _speed = newSpeed.clamp(5.0, 150.0);
    });
  }

  void _jumpToMarker(int markerCharIndex) {
    if (!_scrollController.hasClients) return;
    final totalLength = widget.script.content.length;
    if (totalLength == 0) return;
    final ratio = (markerCharIndex / totalLength).clamp(0.0, 1.0);
    final targetOffset = _scrollController.position.maxScrollExtent * ratio;
    _scrollController.jumpTo(targetOffset);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _ticker.dispose();
    _scrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final bgColor = widget.isTransparentOverlay
        ? settings.backgroundColor.withValues(alpha: settings.overlayOpacity)
        : settings.backgroundColor;

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _togglePlayPause();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _updateSpeed(_speed + 3);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _updateSpeed(_speed - 3);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.home) {
            _restartToTop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePlayPause,
        child: Container(
          color: bgColor,
          child: Stack(
            children: [
              // Mirrored scrolling script content
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(
                  _mirrorX ? -1.0 : 1.0,
                  _mirrorY ? -1.0 : 1.0,
                  1.0,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final topSpacerHeight =
                        constraints.maxHeight * settings.guidePositionPercent;
                    final bottomSpacerHeight = constraints.maxHeight * 0.7;

                    return NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is UserScrollNotification) {
                          _lastElapsed = Duration.zero;
                        }
                        return false;
                      },
                      child: SingleChildScrollView(
                        key: _contentKey,
                        controller: _scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: settings.textHorizontalMargin,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: topSpacerHeight),
                            _buildFormattedContent(),
                            SizedBox(height: bottomSpacerHeight),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Professional Reading Guide Overlay
              if (settings.showGuideLine)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: ReadingGuidePainter(
                        guidePositionPercent: settings.guidePositionPercent,
                        style: settings.guideStyle,
                        color: settings.guideColor,
                        bandHeight: _fontSize * _lineSpacing * 1.5,
                      ),
                    ),
                  ),
                ),

              // Paused watermark badge
              if (!_isPlaying && _countdownNumber == 0)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.8),
                        width: 1.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pause, size: 14, color: Colors.amber),
                        SizedBox(width: 6),
                        Text(
                          'PAUSED',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Countdown Display
              if (_countdownNumber > 0)
                Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_countdownNumber',
                        style: const TextStyle(
                          fontSize: 108,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber,
                          shadows: [
                            Shadow(
                              blurRadius: 24,
                              color: Colors.black,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Get ready...',
                        style: TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Parses text with high contrast cues like [INTRO] highlighted nicely
  Widget _buildFormattedContent() {
    final rawText = widget.script.content;
    final paragraphs = rawText.split('\n');

    return Column(
      crossAxisAlignment: widget.settings.textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : (widget.settings.textAlign == TextAlign.right
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start),
      children: paragraphs.map((para) {
        final trimmed = para.trim();
        if (trimmed.isEmpty) {
          return SizedBox(height: _fontSize * 0.8);
        }

        // Section Marker Bracket like [INTRO - HOOK]
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
          final markerText = trimmed.substring(1, trimmed.length - 1);
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: Text(
              markerText,
              textAlign: widget.settings.textAlign,
              style: TextStyle(
                fontSize: _fontSize * 0.75,
                fontWeight: FontWeight.w800,
                color: Colors.amberAccent,
                letterSpacing: 1.2,
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(vertical: _fontSize * 0.2),
          child: Text(
            para,
            textAlign: widget.settings.textAlign,
            style: TextStyle(
              fontSize: _fontSize,
              height: _lineSpacing,
              color: widget.settings.textColor,
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
