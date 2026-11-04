import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Champagne-gold gradient call-to-action with a tracked uppercase label.
class GoldButton extends StatelessWidget {
  final String label;
  /// Null shows the button dimmed and ignores taps.
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height * 0.3);
    final button = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppTheme.ink, size: 20),
                  const SizedBox(width: 10),
                ],
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: onPressed == null ? 0.6 : 1,
      child: button,
    );
  }
}
