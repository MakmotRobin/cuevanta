import 'package:flutter/material.dart';
import '../models/teleprompter_settings.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class PrompterSettingsSheet extends StatefulWidget {
  final TeleprompterSettings settings;
  final ValueChanged<TeleprompterSettings> onSettingsChanged;

  const PrompterSettingsSheet({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<PrompterSettingsSheet> createState() => _PrompterSettingsSheetState();
}

class _PrompterSettingsSheetState extends State<PrompterSettingsSheet> {
  static const double _maxHeightFraction = 0.85;
  static const List<int> _countdownChoices = [0, 3, 5, 10];

  late TeleprompterSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings.copyWith();
  }

  /// Applies [change] to the working copy, then publishes and persists it.
  void _update(void Function(TeleprompterSettings settings) change) {
    setState(() => change(_settings));
    widget.onSettingsChanged(_settings);
    StorageService().saveSettings(_settings);
  }

  @override
  Widget build(BuildContext context) {
    // Material (not a coloured Container) so list tiles can paint their ripples.
    return Material(
      color: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * _maxHeightFraction,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                ..._buildSpeedSection(),
                ..._buildTypographySection(),
                ..._buildGuideSection(),
                ..._buildMirrorSection(),
                ..._buildStudioSection(),
                ..._buildCountdownSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PROMPTER', style: AppTheme.eyebrow),
                  SizedBox(height: 6),
                  Text('Settings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w300)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildSpeedSection() => [
        const _SectionTitle('Scrolling'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Follow my voice', style: TextStyle(fontSize: 15)),
          subtitle: const Text(
            'Scrolls as you speak and waits when you pause. '
            'While the camera records, timed scrolling takes over: '
            'Android gives the microphone to the camera.',
            style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textMuted),
          ),
          value: _settings.followVoice,
          onChanged: (value) => _update((s) => s.followVoice = value),
        ),
        const SizedBox(height: 4),
        Text(
          _settings.followVoice ? 'TIMED SPEED (USED WHILE RECORDING)' : 'SPEED',
          style: AppTheme.eyebrow.copyWith(fontSize: 9, color: AppTheme.textSubtle),
        ),
        _SliderRow(
          value: _settings.scrollSpeed,
          min: 10,
          max: 150,
          divisions: 28,
          valueLabel: '${_settings.scrollSpeed.round()} px/s',
          onChanged: (value) => _update((s) => s.scrollSpeed = value),
        ),
      ];

  List<Widget> _buildTypographySection() => [
        const _SectionTitle('Typography'),
        _SliderRow(
          label: 'Size',
          value: _settings.fontSize,
          min: 18,
          max: 64,
          divisions: 23,
          valueLabel: '${_settings.fontSize.round()} pt',
          onChanged: (value) => _update((s) => s.fontSize = value),
        ),
        _SliderRow(
          label: 'Spacing',
          value: _settings.lineSpacing,
          min: 1.2,
          max: 2.6,
          divisions: 14,
          valueLabel: _settings.lineSpacing.toStringAsFixed(1),
          onChanged: (value) => _update((s) => s.lineSpacing = value),
        ),
        const SizedBox(height: 8),
        _SegmentedChoice<TextAlign>(
          selected: _settings.textAlign,
          options: const {
            TextAlign.left: (Icons.format_align_left_rounded, 'Left'),
            TextAlign.center: (Icons.format_align_center_rounded, 'Center'),
            TextAlign.right: (Icons.format_align_right_rounded, 'Right'),
          },
          onSelected: (align) => _update((s) => s.textAlign = align),
        ),
      ];

  List<Widget> _buildGuideSection() => [
        const _SectionTitle('Reading guide'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show guide', style: TextStyle(fontSize: 15)),
          subtitle: const Text(
            'Keeps your eyes level with the lens',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          value: _settings.showGuideLine,
          onChanged: (value) => _update((s) => s.showGuideLine = value),
        ),
        if (_settings.showGuideLine) ...[
          _SliderRow(
            label: 'Position',
            value: _settings.guidePositionPercent,
            min: 0.1,
            max: 0.8,
            divisions: 14,
            valueLabel: _settings.guidePositionPercent < 0.35
                ? 'Near lens'
                : '${(_settings.guidePositionPercent * 100).round()}%',
            onChanged: (value) => _update((s) => s.guidePositionPercent = value),
          ),
          const SizedBox(height: 8),
          _SegmentedChoice<ReadingGuideStyle>(
            selected: _settings.guideStyle,
            options: const {
              ReadingGuideStyle.band: (Icons.view_headline_rounded, 'Band'),
              ReadingGuideStyle.line: (Icons.horizontal_rule_rounded, 'Line'),
              ReadingGuideStyle.dimEdges: (Icons.highlight_rounded, 'Focus'),
            },
            onSelected: (style) => _update((s) => s.guideStyle = style),
          ),
        ],
      ];

  List<Widget> _buildMirrorSection() => [
        const _SectionTitle('Mirror for glass rigs'),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Flip horizontally', style: TextStyle(fontSize: 15)),
          value: _settings.mirrorHorizontal,
          onChanged: (value) => _update((s) => s.mirrorHorizontal = value ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Flip vertically', style: TextStyle(fontSize: 15)),
          value: _settings.mirrorVertical,
          onChanged: (value) => _update((s) => s.mirrorVertical = value ?? false),
        ),
      ];

  List<Widget> _buildStudioSection() => [
        const _SectionTitle('Recording studio'),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Vertical 9:16 at 30 fps, front camera by default.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ),
        _SegmentedChoice<RecordingQuality>(
          selected: _settings.recordingQuality,
          options: {for (final quality in RecordingQuality.values) quality: (null, quality.label)},
          onSelected: (quality) => _update((s) => s.recordingQuality = quality),
        ),
        const SizedBox(height: 8),
        _SliderRow(
          label: 'Backdrop',
          value: _settings.overlayOpacity,
          min: 0.1,
          max: 0.95,
          divisions: 17,
          valueLabel: '${(_settings.overlayOpacity * 100).round()}%',
          onChanged: (value) => _update((s) => s.overlayOpacity = value),
        ),
        _SliderRow(
          label: 'Margins',
          value: _settings.textHorizontalMargin,
          min: 8,
          max: 72,
          divisions: 16,
          valueLabel: '${_settings.textHorizontalMargin.round()} px',
          onChanged: (value) => _update((s) => s.textHorizontalMargin = value),
        ),
      ];

  List<Widget> _buildCountdownSection() => [
        const _SectionTitle('Countdown'),
        _SegmentedChoice<int>(
          selected: _settings.countdownDuration,
          options: {
            for (final seconds in _countdownChoices)
              seconds: (null, seconds == 0 ? 'Off' : '${seconds}s'),
          },
          onSelected: (seconds) => _update((s) => s.countdownDuration = seconds),
        ),
      ];
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 6),
      child: Text(title.toUpperCase(), style: AppTheme.eyebrow.copyWith(fontSize: 10)),
    );
  }
}

class _SliderRow extends StatelessWidget {
  static const double _labelWidth = 80;
  static const double _valueWidth = 72;

  final String? label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (label != null)
          SizedBox(
            width: _labelWidth,
            child: Text(label!, style: const TextStyle(fontSize: 14, color: AppTheme.textBody)),
          ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: _valueWidth,
          child: Text(
            valueLabel,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.goldLight),
          ),
        ),
      ],
    );
  }
}

/// Row of equal-width options; the selected one is filled gold.
class _SegmentedChoice<T> extends StatelessWidget {
  final T selected;
  final Map<T, (IconData?, String)> options;
  final ValueChanged<T> onSelected;

  const _SegmentedChoice({required this.selected, required this.options, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(child: _buildOption(entry.key, entry.value.$1, entry.value.$2)),
        ],
      ),
    );
  }

  Widget _buildOption(T value, IconData? icon, String label) {
    final isSelected = value == selected;
    final color = isSelected ? AppTheme.ink : AppTheme.textMuted;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.goldGradient : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
