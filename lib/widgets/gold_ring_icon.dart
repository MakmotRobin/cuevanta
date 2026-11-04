import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// An icon inside a hairline gold ring with a soft inner glow.
class GoldRingIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const GoldRingIcon({super.key, required this.icon, this.size = 84});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.55), width: 1.2),
        gradient: RadialGradient(
          colors: [AppTheme.gold.withValues(alpha: 0.14), Colors.transparent],
        ),
      ),
      child: Icon(icon, color: AppTheme.goldLight, size: size * 0.4),
    );
  }
}
