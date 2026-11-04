import 'package:flutter/material.dart';
import '../models/script.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'studio_recording_screen.dart';
import 'prompter_screen.dart';

class ScriptEditorScreen extends StatefulWidget {
  final Script? script;

  const ScriptEditorScreen({super.key, this.script});

  @override
  State<ScriptEditorScreen> createState() => _ScriptEditorScreenState();
}

class _ScriptEditorScreenState extends State<ScriptEditorScreen> {
  static const String _untitled = 'Untitled Script';
  static const List<String> _suggestedMarkers = [
    'HOOK',
    'INTRO',
    'PROBLEM',
    'SOLUTION',
    'TIP 1',
    'TIP 2',
    'KEY TAKEAWAY',
    'CALL TO ACTION',
    'OUTRO',
  ];

  final StorageService _storageService = StorageService();

  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _scriptId;
  late DateTime _createdAt;
  late final bool _isNewScript = widget.script == null;
  double? _customSpeed;
  double? _customFontSize;
  String? _notes;
  List<String> _backupOpenings = [];
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    final script = widget.script;
    if (script != null) {
      _scriptId = script.id;
      _titleController = TextEditingController(text: script.title);
      _contentController = TextEditingController(text: script.content);
      _createdAt = script.createdAt;
      _customSpeed = script.customSpeed;
      _customFontSize = script.customFontSize;
      _notes = script.notes;
      _backupOpenings = List.of(script.backupOpenings);
    } else {
      _scriptId = 'script_${DateTime.now().millisecondsSinceEpoch}';
      _titleController = TextEditingController();
      _contentController = TextEditingController();
      _createdAt = DateTime.now();
    }

    _contentController.addListener(() => setState(() {}));
  }

  Script _buildCurrentScript() {
    final title = _titleController.text.trim();
    return Script(
      id: _scriptId,
      title: title.isEmpty ? _untitled : title,
      content: _contentController.text,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      customSpeed: _customSpeed,
      customFontSize: _customFontSize,
      notes: _notes,
      backupOpenings: _backupOpenings,
    );
  }

  void _swapOpening(int backupIndex) {
    final swapped = _buildCurrentScript().withOpeningSwapped(backupIndex);
    setState(() => _backupOpenings = swapped.backupOpenings);
    _contentController.text = swapped.content;
  }

  void _showBackupOpeningsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BackupOpeningsSheet(
        currentOpening: _buildCurrentScript().openingLine ?? '',
        backupOpenings: _backupOpenings,
        onChosen: (index) {
          Navigator.of(ctx).pop();
          _swapOpening(index);
        },
      ),
    );
  }

  bool get _isBlankNewScript =>
      _isNewScript &&
      _titleController.text.trim().isEmpty &&
      _contentController.text.trim().isEmpty;

  Future<void> _saveScript() async {
    if (_isBlankNewScript) return;
    await _storageService.addOrUpdateScript(_buildCurrentScript());
  }

  /// Saves before leaving so the script list never reloads stale data.
  Future<void> _saveAndClose() async {
    if (_isClosing) return;
    _isClosing = true;
    final navigator = Navigator.of(context);
    await _saveScript();
    navigator.pop();
  }

  Future<void> _saveAndOpen(Widget Function(Script script) screenBuilder) async {
    final navigator = Navigator.of(context);
    final script = _buildCurrentScript();
    await _storageService.addOrUpdateScript(script);
    if (!mounted) return;
    navigator.push(MaterialPageRoute(builder: (_) => screenBuilder(script)));
  }

  void _insertMarker(String markerTitle) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final insertAt = selection.isValid ? selection.start : text.length;
    final replaceEnd = selection.isValid ? selection.end : text.length;
    final needsLeadingBreak = insertAt > 0 && text[insertAt - 1] != '\n';
    final markerText = '${needsLeadingBreak ? '\n' : ''}[$markerTitle]\n';

    _contentController.value = TextEditingValue(
      text: text.replaceRange(insertAt, replaceEnd, markerText),
      selection: TextSelection.collapsed(offset: insertAt + markerText.length),
    );
  }

  void _insertMarkerAndClose(BuildContext sheetContext, String markerTitle) {
    final cleaned = markerTitle.trim().toUpperCase();
    if (cleaned.isEmpty) return;
    Navigator.of(sheetContext).pop();
    _insertMarker(cleaned);
  }

  void _showAddMarkerSheet() {
    final customController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Insert section marker',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Markers appear as [TAG] in your script and let you jump between sections while prompting.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _suggestedMarkers)
                      ActionChip(
                        label: Text(tag),
                        labelStyle: const TextStyle(
                          color: AppTheme.goldLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onPressed: () => _insertMarkerAndClose(ctx, tag),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customController,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (value) => _insertMarkerAndClose(ctx, value),
                        decoration: const InputDecoration(
                          hintText: 'Custom marker name',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _insertMarkerAndClose(ctx, customController.text),
                      child: const Text('Insert'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(customController.dispose);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentScript = _buildCurrentScript();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _saveAndClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNewScript ? 'New Script' : 'Edit Script'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined, color: AppTheme.goldLight),
              tooltip: 'Insert marker',
              onPressed: _showAddMarkerSheet,
            ),
            IconButton(
              icon: const Icon(Icons.check_rounded, color: AppTheme.accent),
              tooltip: 'Save',
              onPressed: _saveAndClose,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  _EditorStatChip(
                    icon: Icons.schedule_rounded,
                    label: currentScript.formattedEstimatedTime(),
                    color: AppTheme.primaryLight,
                  ),
                  const SizedBox(width: 8),
                  _EditorStatChip(
                    icon: Icons.notes_rounded,
                    label: '${currentScript.wordCount} words',
                  ),
                  const SizedBox(width: 8),
                  _EditorStatChip(
                    icon: Icons.bookmark_outline_rounded,
                    label: '${currentScript.markers.length} markers',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _titleController,
                autofocus: _isNewScript,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLines: null,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300, height: 1.3),
                decoration: const InputDecoration(
                  hintText: 'Script title',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_backupOpenings.isNotEmpty)
              _OpeningBar(
                openingLine: currentScript.openingLine ?? '',
                alternativeCount: _backupOpenings.length,
                onSwap: _showBackupOpeningsSheet,
              ),
            const Divider(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 16, height: 1.6, color: AppTheme.textBody),
                  decoration: const InputDecoration(
                    hintText:
                        'Type or paste your script here…\n\nTip: lines like [INTRO], [HOOK] or [KEY POINT] become section markers you can jump to.',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
            _buildLaunchBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildLaunchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppTheme.cardDark,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.slideshow_rounded),
                label: const Text('Prompt'),
                onPressed: () => _saveAndOpen((script) => PrompterScreen(script: script)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Record'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.recordingRed,
                  foregroundColor: AppTheme.textPrimary,
                ),
                onPressed: () =>
                    _saveAndOpen((script) => StudioRecordingScreen(script: script)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _EditorStatChip({
    required this.icon,
    required this.label,
    this.color = AppTheme.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Shows the current first line and offers the imported backup openings.
class _OpeningBar extends StatelessWidget {
  final String openingLine;
  final int alternativeCount;
  final VoidCallback onSwap;

  const _OpeningBar({
    required this.openingLine,
    required this.alternativeCount,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: AppTheme.goldLight, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              openingLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppTheme.textBody, height: 1.35),
            ),
          ),
          TextButton.icon(
            onPressed: onSwap,
            icon: const Icon(Icons.swap_vert_rounded, size: 18),
            label: Text('$alternativeCount hooks'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.goldLight),
          ),
        ],
      ),
    );
  }
}

class _BackupOpeningsSheet extends StatelessWidget {
  final String currentOpening;
  final List<String> backupOpenings;
  final ValueChanged<int> onChosen;

  const _BackupOpeningsSheet({
    required this.currentOpening,
    required this.backupOpenings,
    required this.onChosen,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Swap the opening line', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'The line you replace moves into this list, so you can always swap back.',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            const Text('NOW', style: TextStyle(fontSize: 11, color: AppTheme.textSubtle, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(currentOpening, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
            const SizedBox(height: 14),
            for (var i = 0; i < backupOpenings.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.bolt_rounded, color: AppTheme.goldLight),
                  title: Text(backupOpenings[i], style: const TextStyle(fontSize: 14, height: 1.4)),
                  trailing: const Icon(Icons.swap_vert_rounded, color: AppTheme.textMuted),
                  onTap: () => onChosen(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
