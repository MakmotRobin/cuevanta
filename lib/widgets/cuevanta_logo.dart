import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The Cuevanta mark: an open champagne-gold ring (a "C", and a lens)
/// with a single cue dot resting in its opening.
class CuevantaMark extends StatelessWidget {
  final double size;

  /// 0 → nothing drawn, 1 → full mark. Lets the splash draw the ring in.
  final double progress;

  const CuevantaMark({super.key, this.size = 48, this.progress = 1});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CuevantaMarkPainter(progress: progress.clamp(0, 1))),
    );
  }
}

class _CuevantaMarkPainter extends CustomPainter {
  // Geometry in a 100×100 design box, shared with the launcher icon generator.
  static const double _ringRadius = 34;
  static const double _strokeWidth = 5.5;
  static const double _gapHalfAngle = 38 * math.pi / 180;
  static const double _dotRadius = 5.5;
  static const double _opticalShiftX = -2.5; // recentres ring + dot as one shape

  final double progress;

  _CuevantaMarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    final center = size.center(Offset.zero) + Offset(_opticalShiftX * scale, 0);
    final radius = _ringRadius * scale;
    final ringRect = Rect.fromCircle(center: center, radius: radius);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth * scale
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [AppTheme.goldLight, AppTheme.gold, AppTheme.goldDeep, AppTheme.gold, AppTheme.goldLight],
      ).createShader(ringRect);

    const fullSweep = 2 * math.pi - 2 * _gapHalfAngle;
    canvas.drawArc(ringRect, _gapHalfAngle, fullSweep * progress, false, ringPaint);

    final dotOpacity = ((progress - 0.75) / 0.25).clamp(0.0, 1.0);
    if (dotOpacity > 0) {
      canvas.drawCircle(
        center + Offset(radius, 0),
        _dotRadius * scale,
        Paint()..color = AppTheme.goldLight.withValues(alpha: dotOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CuevantaMarkPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Thin, widely tracked wordmark.
class CuevantaWordmark extends StatelessWidget {
  final double fontSize;
  final Color color;

  const CuevantaWordmark({super.key, this.fontSize = 22, this.color = AppTheme.textPrimary});

  @override
  Widget build(BuildContext context) {
    return Text(
      'CUEVANTA',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        letterSpacing: fontSize * 0.42,
        color: color,
      ),
    );
  }
}

/// Mark on the ink tile, used where a contained app icon reads better (e.g. app bar).
class CuevantaAppIcon extends StatelessWidget {
  final double size;

  const CuevantaAppIcon({super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35), width: 0.8),
      ),
      alignment: Alignment.center,
      child: CuevantaMark(size: size * 0.78),
    );
  }
}
