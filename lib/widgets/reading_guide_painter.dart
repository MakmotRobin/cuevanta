import 'package:flutter/material.dart';
import '../models/teleprompter_settings.dart';

class ReadingGuidePainter extends CustomPainter {
  final double guidePositionPercent; // 0.0 to 1.0
  final ReadingGuideStyle style;
  final Color color;
  final double bandHeight;

  ReadingGuidePainter({
    required this.guidePositionPercent,
    required this.style,
    required this.color,
    this.bandHeight = 54.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (style == ReadingGuideStyle.none) return;

    final centerY = size.height * guidePositionPercent.clamp(0.05, 0.95);
    final topY = centerY - (bandHeight / 2);
    final bottomY = centerY + (bandHeight / 2);

    if (style == ReadingGuideStyle.dimEdges) {
      // Dim upper portion
      final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, topY), dimPaint);
      // Dim lower portion
      canvas.drawRect(
        Rect.fromLTWH(0, bottomY, size.width, size.height - bottomY),
        dimPaint,
      );
    }

    if (style == ReadingGuideStyle.band || style == ReadingGuideStyle.dimEdges) {
      // Highlight band
      final bandPaint = Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8, topY, size.width - 16, bandHeight),
          const Radius.circular(8),
        ),
        bandPaint,
      );

      // Subtle border for band
      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(8, topY), Offset(size.width - 8, topY), borderPaint);
      canvas.drawLine(Offset(8, bottomY), Offset(size.width - 8, bottomY), borderPaint);
    }

    if (style == ReadingGuideStyle.line || style == ReadingGuideStyle.band) {
      // Guide arrows / chevrons on margins
      final markerPaint = Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;

      // Left pointer triangle
      final leftPath = Path()
        ..moveTo(0, centerY - 8)
        ..lineTo(14, centerY)
        ..lineTo(0, centerY + 8)
        ..close();
      canvas.drawPath(leftPath, markerPaint);

      // Right pointer triangle
      final rightPath = Path()
        ..moveTo(size.width, centerY - 8)
        ..lineTo(size.width - 14, centerY)
        ..lineTo(size.width, centerY + 8)
        ..close();
      canvas.drawPath(rightPath, markerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ReadingGuidePainter oldDelegate) {
    return oldDelegate.guidePositionPercent != guidePositionPercent ||
        oldDelegate.style != style ||
        oldDelegate.color != color ||
        oldDelegate.bandHeight != bandHeight;
  }
}
