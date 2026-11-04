import 'package:flutter/material.dart';
import '../models/script.dart';
import '../models/teleprompter_settings.dart';
import '../theme/app_theme.dart';
import 'prompter_view.dart';

/// Floating control panel shown over the prompter.
///
/// Laid out in two rows so it fits on narrow phone screens:
/// speed · play/pause · text size on top, secondary tools underneath.
class PrompterHudControls extends StatelessWidget {
  static const double minSpeed = 5.0;
  static const double maxSpeed = 150.0;
  static const double speedStep = 4.0;
  static const double minFontSize = 16.0;
  static const double maxFontSize = 72.0;
  static const double fontSizeStep = 2.0;

  final PrompterViewController? controller;
  final Script script;
  final TeleprompterSettings settings;
  final bool isPlaying;
  final double currentSpeed;
  final double currentFontSize;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onFontSizeChanged;
  final VoidCallback onToggleMirror;
  final VoidCallback onOpenSettings;

  const PrompterHudControls({
    super.key,
    required this.controller,
    required this.script,
    required this.settings,
    required this.isPlaying,
    required this.currentSpeed,
    required this.currentFontSize,
    required this.onSpeedChanged,
    required this.onFontSizeChanged,
    required this.onToggleMirror,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        decoration: BoxDecoration(
          color: AppTheme.hudBackground,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.surfaceDark),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPrimaryRow(),
            const SizedBox(height: 6),
            _buildSecondaryRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperPill(
          label: 'SPEED',
          value: '${currentSpeed.round()}',
          decreaseIcon: Icons.remove_rounded,
          increaseIcon: Icons.add_rounded,
          decreaseTooltip: 'Slower',
          increaseTooltip: 'Faster',
          onDecrease: () => onSpeedChanged((currentSpeed - speedStep).clamp(minSpeed, maxSpeed)),
          onIncrease: () => onSpeedChanged((currentSpeed + speedStep).clamp(minSpeed, maxSpeed)),
        ),
        const SizedBox(width: 14),
        _PlayPauseButton(
          isPlaying: isPlaying,
          onTap: () => controller?.togglePlayPause(),
        ),
        const SizedBox(width: 14),
        _StepperPill(
          label: 'SIZE',
          value: '${currentFontSize.round()}',
          decreaseIcon: Icons.text_decrease_rounded,
          increaseIcon: Icons.text_increase_rounded,
          decreaseTooltip: 'Smaller text',
          increaseTooltip: 'Larger text',
          onDecrease: () =>
              onFontSizeChanged((currentFontSize - fontSizeStep).clamp(minFontSize, maxFontSize)),
          onIncrease: () =>
              onFontSizeChanged((currentFontSize + fontSizeStep).clamp(minFontSize, maxFontSize)),
        ),
      ],
    );
  }

  Widget _buildSecondaryRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HudIconButton(
          icon: Icons.replay_rounded,
          tooltip: 'Back to top',
          onTap: () => controller?.restart(),
        ),
        if (script.markers.isNotEmpty) _buildSectionMenu(),
        _HudIconButton(
          icon: Icons.flip_rounded,
          tooltip: settings.mirrorHorizontal ? 'Mirror off' : 'Mirror for glass rig',
          color: settings.mirrorHorizontal ? Colors.amber : Colors.white70,
          onTap: onToggleMirror,
        ),
        _HudIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'Prompter settings',
          onTap: onOpenSettings,
        ),
      ],
    );
  }

  Widget _buildSectionMenu() {
    return PopupMenuButton<int>(
      tooltip: 'Jump to section',
      icon: const Icon(Icons.bookmarks_outlined, color: Colors.amberAccent, size: 22),
      itemBuilder: (context) => [
        for (final marker in script.markers)
          PopupMenuItem<int>(
            value: marker.index,
            child: Row(
              children: [
                const Icon(Icons.label_important_rounded, color: Colors.amberAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    marker.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
      onSelected: (markerIndex) => controller?.jumpToMarker(markerIndex),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = isPlaying
        ? const [Color(0xFFF59E0B), Color(0xFFD97706)]
        : const [Color(0xFF10B981), Color(0xFF059669)];

    return Tooltip(
      message: isPlaying ? 'Pause' : 'Play',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
      ),
    );
  }
}

class _StepperPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData decreaseIcon;
  final IconData increaseIcon;
  final String decreaseTooltip;
  final String increaseTooltip;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _StepperPill({
    required this.label,
    required this.value,
    required this.decreaseIcon,
    required this.increaseIcon,
    required this.decreaseTooltip,
    required this.increaseTooltip,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HudIconButton(icon: decreaseIcon, tooltip: decreaseTooltip, onTap: onDecrease, size: 18),
          SizedBox(
            width: 38,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _HudIconButton(icon: increaseIcon, tooltip: increaseTooltip, onTap: onIncrease, size: 18),
        ],
      ),
    );
  }
}

class _HudIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final double size;

  const _HudIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.white70,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }
}
