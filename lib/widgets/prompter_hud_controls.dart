import 'package:flutter/material.dart';
import '../models/script.dart';
import '../models/teleprompter_settings.dart';
import 'prompter_view.dart';

class PrompterHudControls extends StatelessWidget {
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
  final bool isRecording;
  final VoidCallback? onToggleRecording;

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
    this.isRecording = false,
    this.onToggleRecording,
  });

  @override
  Widget build(BuildContext context) {
    final markers = script.markers;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xE60F172A), // Dark slate frosted background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rewind / Restart to Top
          _buildIconButton(
            icon: Icons.replay,
            tooltip: 'Restart to Top',
            onTap: () => controller?.restart(),
          ),

          const SizedBox(width: 8),

          // Speed Control Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSmallButton(
                  icon: Icons.remove,
                  tooltip: 'Decrease Speed',
                  onTap: () => onSpeedChanged((currentSpeed - 4).clamp(5.0, 150.0)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${currentSpeed.round()}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'SPEED',
                        style: TextStyle(
                          fontSize: 8,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSmallButton(
                  icon: Icons.add,
                  tooltip: 'Increase Speed',
                  onTap: () => onSpeedChanged((currentSpeed + 4).clamp(5.0, 150.0)),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Main Play / Pause Button
          GestureDetector(
            onTap: () => controller?.togglePlayPause(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPlaying
                      ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                      : [const Color(0xFF10B981), const Color(0xFF059669)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isPlaying ? Colors.red : Colors.green).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Font Size Adjust
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSmallButton(
                  icon: Icons.text_fields,
                  tooltip: 'Smaller Text',
                  iconSize: 14,
                  onTap: () =>
                      onFontSizeChanged((currentFontSize - 2).clamp(16.0, 72.0)),
                ),
                _buildSmallButton(
                  icon: Icons.text_fields,
                  tooltip: 'Larger Text',
                  iconSize: 20,
                  onTap: () =>
                      onFontSizeChanged((currentFontSize + 2).clamp(16.0, 72.0)),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Markers / Cue Jump Menu
          if (markers.isNotEmpty)
            PopupMenuButton<int>(
              tooltip: 'Jump to Section',
              icon: const Icon(Icons.bookmark_border_rounded, color: Colors.amberAccent),
              color: const Color(0xFF1E293B),
              itemBuilder: (context) => markers.map((m) {
                return PopupMenuItem<int>(
                  value: m.index,
                  child: Row(
                    children: [
                      const Icon(Icons.label_important_rounded,
                          color: Colors.amberAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onSelected: (markerIndex) {
                controller?.jumpToMarker(markerIndex);
              },
            ),

          // Mirror Toggle Button
          _buildIconButton(
            icon: Icons.flip,
            tooltip: 'Mirror Flip',
            color: settings.mirrorHorizontal ? Colors.amber : Colors.white70,
            onTap: onToggleMirror,
          ),

          // Settings Button
          _buildIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Prompter Settings',
            onTap: onOpenSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    double iconSize = 16,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}
