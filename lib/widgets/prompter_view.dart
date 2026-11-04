import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/script.dart';
import '../models/teleprompter_settings.dart';
import 'reading_guide_painter.dart';
import '../theme/app_theme.dart';

class PrompterView extends StatefulWidget {
  final Script script;
  final TeleprompterSettings settings;
  final bool isTransparentOverlay;
  final VoidCallback? onFinished;
  final ValueChanged<bool>? onPlayStateChanged;

  /// Called once the pre-roll countdown ends (immediately when the countdown is off).
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
  static const double _minSpeed = 5.0;
  static const double _maxSpeed = 150.0;
  static const double _keyboardSpeedStep = 3.0;
  static const double _bottomSpacerFraction = 0.7;

  late ScrollController _scrollController;
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  bool _isPlaying = false;
  int _countdownNumber = 0;
  Timer? _countdownTimer;

  late double _speed;
  late double _fontSize;
  double _topSpacerHeight = 0;

  late final List<String> _paragraphs;
  late final List<int> _paragraphStartOffsets;
  late final List<GlobalKey> _paragraphKeys;
  final GlobalKey _contentColumnKey = GlobalKey();
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _speed = widget.script.customSpeed ?? widget.settings.scrollSpeed;
    _fontSize = widget.script.customFontSize ?? widget.settings.fontSize;
    _indexParagraphs();

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.settings.countdownDuration > 0) {
        _startCountdown();
      } else {
        _finishCountdown();
      }
    });
  }

  void _indexParagraphs() {
    _paragraphs = widget.script.content.split('\n');
    _paragraphStartOffsets = [];
    var offset = 0;
    for (final paragraph in _paragraphs) {
      _paragraphStartOffsets.add(offset);
      offset += paragraph.length + 1; // +1 for the newline removed by split
    }
    _paragraphKeys = List.generate(_paragraphs.length, (_) => GlobalKey());
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

    final maxScroll = _scrollController.position.maxScrollExtent;
    final newOffset = _scrollController.offset + (_speed * delta);

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
        setState(() => _countdownNumber--);
      } else {
        timer.cancel();
        _finishCountdown();
      }
    });
  }

  void _finishCountdown() {
    if (!mounted) return;
    _countdownTimer?.cancel();
    setState(() => _countdownNumber = 0);
    widget.onCountdownFinished?.call();
    _startScrolling();
  }

  void _startScrolling() {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);
    _lastElapsed = Duration.zero;
    if (!_ticker.isTicking) {
      _ticker.start();
    }
    widget.onPlayStateChanged?.call(true);
  }

  void _pauseScrolling() {
    if (!_isPlaying) return;
    setState(() => _isPlaying = false);
    if (_ticker.isTicking) {
      _ticker.stop();
    }
    widget.onPlayStateChanged?.call(false);
  }

  void _togglePlayPause() {
    if (_countdownNumber > 0) {
      _finishCountdown();
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
    setState(() => _speed = newSpeed.clamp(_minSpeed, _maxSpeed));
  }

  /// Scrolls so the marker sits just above the reading guide and the
  /// section's first line lands on it.
  void _jumpToMarker(int markerCharIndex) {
    if (!_scrollController.hasClients) return;
    final markerBottomY = _paragraphBottomY(_paragraphIndexAt(markerCharIndex));
    if (markerBottomY == null) return;

    final guideBandTop = _topSpacerHeight - _bandHeight / 2;
    final target = (markerBottomY - guideBandTop).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
    _lastElapsed = Duration.zero;
  }

  int _paragraphIndexAt(int charIndex) {
    for (var i = _paragraphStartOffsets.length - 1; i >= 0; i--) {
      if (_paragraphStartOffsets[i] <= charIndex) return i;
    }
    return 0;
  }

  double? _paragraphBottomY(int paragraphIndex) {
    final paragraphBox =
        _paragraphKeys[paragraphIndex].currentContext?.findRenderObject() as RenderBox?;
    final columnBox = _contentColumnKey.currentContext?.findRenderObject() as RenderBox?;
    if (paragraphBox == null || columnBox == null) return null;
    final bottomLeft = Offset(0, paragraphBox.size.height);
    return paragraphBox.localToGlobal(bottomLeft, ancestor: columnBox).dy;
  }

  double get _bandHeight => _fontSize * widget.settings.lineSpacing * 1.5;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      _togglePlayPause();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _updateSpeed(_speed + _keyboardSpeedStep);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _updateSpeed(_speed - _keyboardSpeedStep);
    } else if (key == LogicalKeyboardKey.home) {
      _restartToTop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
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
      onKeyEvent: _handleKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePlayPause,
        child: Container(
          color: bgColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _topSpacerHeight = constraints.maxHeight * settings.guidePositionPercent;
              final bandHeight = _bandHeight;
              final guideBandTop = _topSpacerHeight - bandHeight / 2;

              return Stack(
                children: [
                  _buildMirroredScrollingText(constraints),
                  if (settings.showGuideLine)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: ReadingGuidePainter(
                            guidePositionPercent: settings.guidePositionPercent,
                            style: settings.guideStyle,
                            color: settings.guideColor,
                            bandHeight: bandHeight,
                          ),
                        ),
                      ),
                    ),
                  if (!_isPlaying && _countdownNumber == 0)
                    Positioned(
                      // Above the guide band, over text that has already been read.
                      bottom: constraints.maxHeight - guideBandTop + 8,
                      left: 0,
                      right: 0,
                      child: const IgnorePointer(child: Center(child: _PausedBadge())),
                    ),
                  if (_countdownNumber > 0) _CountdownOverlay(number: _countdownNumber),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMirroredScrollingText(BoxConstraints constraints) {
    final settings = widget.settings;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(
        settings.mirrorHorizontal ? -1.0 : 1.0,
        settings.mirrorVertical ? -1.0 : 1.0,
        1.0,
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is UserScrollNotification) {
            _lastElapsed = Duration.zero;
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: settings.textHorizontalMargin),
          child: Column(
            key: _contentColumnKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: _topSpacerHeight),
              _buildFormattedContent(),
              SizedBox(height: constraints.maxHeight * _bottomSpacerFraction),
            ],
          ),
        ),
      ),
    );
  }

  CrossAxisAlignment get _crossAxisAlignmentForText {
    switch (widget.settings.textAlign) {
      case TextAlign.center:
        return CrossAxisAlignment.center;
      case TextAlign.right:
      case TextAlign.end:
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.start;
    }
  }

  /// Renders paragraphs, highlighting whole-line cues like [INTRO].
  Widget _buildFormattedContent() {
    return Column(
      crossAxisAlignment: _crossAxisAlignmentForText,
      children: [
        for (var i = 0; i < _paragraphs.length; i++)
          KeyedSubtree(key: _paragraphKeys[i], child: _buildParagraph(_paragraphs[i])),
      ],
    );
  }

  Widget _buildParagraph(String paragraph) {
    final trimmed = paragraph.trim();
    if (trimmed.isEmpty) {
      return SizedBox(height: _fontSize * 0.8);
    }
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      return _buildMarkerChip(trimmed.substring(1, trimmed.length - 1));
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _fontSize * 0.2),
      child: Text(
        paragraph,
        textAlign: widget.settings.textAlign,
        style: TextStyle(
          fontSize: _fontSize,
          height: widget.settings.lineSpacing,
          color: widget.settings.textColor,
          fontWeight: FontWeight.w600,
          shadows: const [
            Shadow(blurRadius: 4, color: Colors.black, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerChip(String markerText) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Text(
        markerText,
        textAlign: widget.settings.textAlign,
        style: TextStyle(
          fontSize: _fontSize * 0.6,
          fontWeight: FontWeight.w800,
          color: AppTheme.goldLight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _PausedBadge extends StatelessWidget {
  const _PausedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.8), width: 1.2),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause, size: 14, color: AppTheme.gold),
          SizedBox(width: 6),
          Text(
            'PAUSED · TAP TO RESUME',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  final int number;

  const _CountdownOverlay({required this.number});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween(begin: 1.4, end: 1.0).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Text(
                  '$number',
                  key: ValueKey(number),
                  style: const TextStyle(
                    fontSize: 108,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.gold,
                    shadows: [
                      Shadow(blurRadius: 24, color: Colors.black, offset: Offset(0, 4)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Get ready…  tap to skip',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
