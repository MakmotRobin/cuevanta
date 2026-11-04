import 'package:flutter/material.dart';
import '../models/teleprompter_settings.dart';
import '../services/storage_service.dart';

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

  late TeleprompterSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings.copyWith();
  }

  void _notifyChange() {
    widget.onSettingsChanged(_settings);
    StorageService().saveSettings(_settings);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * _maxHeightFraction,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Prompter Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. SCROLL SPEED
              _buildSectionTitle('Scroll Pace & Speed'),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _settings.scrollSpeed.clamp(10.0, 150.0),
                      min: 10.0,
                      max: 150.0,
                      divisions: 28,
                      label: '${_settings.scrollSpeed.round()} px/s',
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        setState(() => _settings.scrollSpeed = val);
                        _notifyChange();
                      },
                    ),
                  ),
                  Text(
                    '${_settings.scrollSpeed.round()} px/s',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              // 2. FONT SIZE & LINE HEIGHT
              _buildSectionTitle('Typography & Size'),
              Row(
                children: [
                  const Icon(Icons.text_fields, size: 18, color: Colors.white70),
                  const SizedBox(width: 8),
                  const Text('Size:'),
                  Expanded(
                    child: Slider(
                      value: _settings.fontSize.clamp(18.0, 64.0),
                      min: 18.0,
                      max: 64.0,
                      divisions: 23,
                      label: '${_settings.fontSize.round()} pt',
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        setState(() => _settings.fontSize = val);
                        _notifyChange();
                      },
                    ),
                  ),
                  Text('${_settings.fontSize.round()} pt'),
                ],
              ),

              Row(
                children: [
                  const Icon(Icons.format_line_spacing, size: 18, color: Colors.white70),
                  const SizedBox(width: 8),
                  const Text('Spacing:'),
                  Expanded(
                    child: Slider(
                      value: _settings.lineSpacing.clamp(1.2, 2.6),
                      min: 1.2,
                      max: 2.6,
                      divisions: 14,
                      label: _settings.lineSpacing.toStringAsFixed(1),
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        setState(() => _settings.lineSpacing = val);
                        _notifyChange();
                      },
                    ),
                  ),
                  Text(_settings.lineSpacing.toStringAsFixed(1)),
                ],
              ),

              // 3. TEXT ALIGNMENT
              _buildSectionTitle('Text Alignment'),
              Row(
                children: [
                  _buildSegmentButton(
                    title: 'Left',
                    icon: Icons.format_align_left,
                    selected: _settings.textAlign == TextAlign.left,
                    onTap: () {
                      setState(() => _settings.textAlign = TextAlign.left);
                      _notifyChange();
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildSegmentButton(
                    title: 'Center',
                    icon: Icons.format_align_center,
                    selected: _settings.textAlign == TextAlign.center,
                    onTap: () {
                      setState(() => _settings.textAlign = TextAlign.center);
                      _notifyChange();
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildSegmentButton(
                    title: 'Right',
                    icon: Icons.format_align_right,
                    selected: _settings.textAlign == TextAlign.right,
                    onTap: () {
                      setState(() => _settings.textAlign = TextAlign.right);
                      _notifyChange();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. EYE-LEVEL READING GUIDE
              _buildSectionTitle('Eye-Level Reading Guide'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show Eye-Level Guide'),
                subtitle: const Text(
                  'Keeps your eyes locked on the front camera lens',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
                value: _settings.showGuideLine,
                activeThumbColor: const Color(0xFF6366F1),
                onChanged: (val) {
                  setState(() => _settings.showGuideLine = val);
                  _notifyChange();
                },
              ),

              if (_settings.showGuideLine) ...[
                Row(
                  children: [
                    const Text('Guide Vertical Position:'),
                    Expanded(
                      child: Slider(
                        value: _settings.guidePositionPercent.clamp(0.1, 0.8),
                        min: 0.1,
                        max: 0.8,
                        divisions: 14,
                        label: '${(_settings.guidePositionPercent * 100).round()}%',
                        activeColor: Colors.amber,
                        onChanged: (val) {
                          setState(() => _settings.guidePositionPercent = val);
                          _notifyChange();
                        },
                      ),
                    ),
                    Text(
                      _settings.guidePositionPercent < 0.35
                          ? 'Camera Top'
                          : '${(_settings.guidePositionPercent * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildSegmentButton(
                      title: 'Band',
                      icon: Icons.view_headline,
                      selected: _settings.guideStyle == ReadingGuideStyle.band,
                      onTap: () {
                        setState(() => _settings.guideStyle = ReadingGuideStyle.band);
                        _notifyChange();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentButton(
                      title: 'Line',
                      icon: Icons.horizontal_rule,
                      selected: _settings.guideStyle == ReadingGuideStyle.line,
                      onTap: () {
                        setState(() => _settings.guideStyle = ReadingGuideStyle.line);
                        _notifyChange();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentButton(
                      title: 'Focus Dim',
                      icon: Icons.highlight,
                      selected: _settings.guideStyle == ReadingGuideStyle.dimEdges,
                      onTap: () {
                        setState(() => _settings.guideStyle = ReadingGuideStyle.dimEdges);
                        _notifyChange();
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // 5. MIRRORING (FOR GLASS RIGS)
              _buildSectionTitle('Mirror Options (Glass Rig Prompters)'),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mirror Horizontal (Flip X)', style: TextStyle(fontSize: 13)),
                      value: _settings.mirrorHorizontal,
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        setState(() => _settings.mirrorHorizontal = val ?? false);
                        _notifyChange();
                      },
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mirror Vertical (Flip Y)', style: TextStyle(fontSize: 13)),
                      value: _settings.mirrorVertical,
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        setState(() => _settings.mirrorVertical = val ?? false);
                        _notifyChange();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 6. CAMERA OVERLAY OPACITY & EYE MARGIN
              _buildSectionTitle('Reading Comfort in Video Studio'),
              Row(
                children: [
                  const Text('Backdrop Opacity:'),
                  Expanded(
                    child: Slider(
                      value: _settings.overlayOpacity.clamp(0.1, 0.95),
                      min: 0.1,
                      max: 0.95,
                      divisions: 17,
                      label: '${(_settings.overlayOpacity * 100).round()}%',
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        setState(() => _settings.overlayOpacity = val);
                        _notifyChange();
                      },
                    ),
                  ),
                  Text('${(_settings.overlayOpacity * 100).round()}%'),
                ],
              ),
              Row(
                children: [
                  const Text('Side Eye Margins:'),
                  Expanded(
                    child: Slider(
                      value: _settings.textHorizontalMargin.clamp(8.0, 72.0),
                      min: 8.0,
                      max: 72.0,
                      divisions: 16,
                      label: '${_settings.textHorizontalMargin.round()} px',
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        setState(() => _settings.textHorizontalMargin = val);
                        _notifyChange();
                      },
                    ),
                  ),
                  Text('${_settings.textHorizontalMargin.round()} px'),
                ],
              ),

              // 7. COUNTDOWN DURATION
              _buildSectionTitle('Countdown Timer'),
              Wrap(
                spacing: 8,
                children: [0, 3, 5, 10].map((sec) {
                  final selected = _settings.countdownDuration == sec;
                  return ChoiceChip(
                    label: Text(sec == 0 ? 'Off' : '${sec}s'),
                    selected: selected,
                    selectedColor: const Color(0xFF6366F1),
                    onSelected: (val) {
                      setState(() => _settings.countdownDuration = sec);
                      _notifyChange();
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF6366F1) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF818CF8) : const Color(0xFF334155),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : Colors.white70),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
