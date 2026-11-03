import 'package:flutter/material.dart';
import '../models/script.dart';
import '../services/storage_service.dart';
import 'studio_recording_screen.dart';
import 'prompter_screen.dart';

class ScriptEditorScreen extends StatefulWidget {
  final Script? script;

  const ScriptEditorScreen({super.key, this.script});

  @override
  State<ScriptEditorScreen> createState() => _ScriptEditorScreenState();
}

class _ScriptEditorScreenState extends State<ScriptEditorScreen> {
  final StorageService _storageService = StorageService();

  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late String _scriptId;
  late DateTime _createdAt;
  double? _customSpeed;
  double? _customFontSize;

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
    } else {
      _scriptId = 'script_${DateTime.now().millisecondsSinceEpoch}';
      _titleController = TextEditingController(text: 'Untitled Script');
      _contentController = TextEditingController();
      _createdAt = DateTime.now();
    }

    _contentController.addListener(() {
      setState(() {});
    });
  }

  Script _buildCurrentScript() {
    return Script(
      id: _scriptId,
      title: _titleController.text.trim().isEmpty
          ? 'Untitled Script'
          : _titleController.text.trim(),
      content: _contentController.text,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      customSpeed: _customSpeed,
      customFontSize: _customFontSize,
    );
  }

  Future<void> _saveScript() async {
    final script = _buildCurrentScript();
    await _storageService.addOrUpdateScript(script);
  }

  void _insertMarker(String markerTitle) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final markerText = '\n[$markerTitle]\n';

    final newText = selection.start >= 0
        ? text.replaceRange(selection.start, selection.end, markerText)
        : '$text$markerText';

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (selection.start >= 0 ? selection.start : text.length) + markerText.length,
      ),
    );
  }

  void _showAddMarkerDialog() {
    final suggestions = [
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

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final customController = TextEditingController();
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Insert Section Marker',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Markers format as [TAG] in your script and allow quick navigation during prompting.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((tag) {
                  return ActionChip(
                    label: Text(tag),
                    backgroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFF334155)),
                    labelStyle: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _insertMarker(tag);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: customController,
                      decoration: const InputDecoration(
                        hintText: 'Custom marker name...',
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (customController.text.trim().isNotEmpty) {
                        Navigator.of(ctx).pop();
                        _insertMarker(customController.text.trim().toUpperCase());
                      }
                    },
                    child: const Text('Insert'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _saveScript();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Script'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined, color: Colors.amberAccent),
              tooltip: 'Insert Marker',
              onPressed: _showAddMarkerDialog,
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFF10B981)),
              tooltip: 'Save',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                await _saveScript();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Script saved!'),
                    duration: Duration(seconds: 1),
                  ),
                );
                navigator.pop();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Stats bar (word count, reading time)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Color(0xFF818CF8)),
                  const SizedBox(width: 6),
                  Text(
                    'Time: ${currentScript.formattedEstimatedTime()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.notes, size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    '${currentScript.wordCount} words  •  ${currentScript.markers.length} markers',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Title input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                decoration: const InputDecoration(
                  hintText: 'Script Title...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            const Divider(color: Color(0xFF2E3E55), height: 1),

            // Content text area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: Color(0xFFE2E8F0),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type or paste your script here...\n\nTip: You can use [INTRO], [HOOK], or [KEY POINT] to create section markers!',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),

            // Bottom Action Bar (Launch Studio Video Recording / Launch Prompter)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(
                  top: BorderSide(color: Color(0xFF2E3E55)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Glass Prompter Button
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Prompter Only'),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final currentScript = _buildCurrentScript();
                          await _saveScript();
                          if (!mounted) return;
                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => PrompterScreen(
                                script: currentScript,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Video Studio Recording Button
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.videocam),
                        label: const Text('Record Studio'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                        ),
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final currentScript = _buildCurrentScript();
                          await _saveScript();
                          if (!mounted) return;
                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => StudioRecordingScreen(
                                script: currentScript,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
