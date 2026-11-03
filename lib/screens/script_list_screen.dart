import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/script.dart';
import '../services/storage_service.dart';
import 'recordings_screen.dart';
import 'script_editor_screen.dart';
import 'studio_recording_screen.dart';
import 'prompter_screen.dart';
import '../widgets/prompter_settings_sheet.dart';

class ScriptListScreen extends StatefulWidget {
  const ScriptListScreen({super.key});

  @override
  State<ScriptListScreen> createState() => _ScriptListScreenState();
}

class _ScriptListScreenState extends State<ScriptListScreen> {
  final StorageService _storageService = StorageService();
  List<Script> _allScripts = [];
  List<Script> _filteredScripts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadScripts();
  }

  Future<void> _loadScripts() async {
    final list = await _storageService.getScripts();
    if (mounted) {
      setState(() {
        _allScripts = list;
        _filterScripts();
        _isLoading = false;
      });
    }
  }

  void _filterScripts() {
    if (_searchQuery.trim().isEmpty) {
      _filteredScripts = List.from(_allScripts);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredScripts = _allScripts.where((s) {
        return s.title.toLowerCase().contains(q) ||
            s.content.toLowerCase().contains(q);
      }).toList();
    }
  }

  Future<void> _createNewScript() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ScriptEditorScreen(),
      ),
    );
    _loadScripts();
  }

  Future<void> _openScript(Script script) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScriptEditorScreen(script: script),
      ),
    );
    _loadScripts();
  }

  Future<void> _duplicateScript(Script script) async {
    final copy = script.copyWith(
      id: 'script_${DateTime.now().millisecondsSinceEpoch}',
      title: '${script.title} (Copy)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _storageService.addOrUpdateScript(copy);
    _loadScripts();
  }

  Future<void> _deleteScript(Script script) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Script?'),
        content: Text('Are you sure you want to delete "${script.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storageService.deleteScript(script.id);
      _loadScripts();
    }
  }

  Future<void> _openGlobalSettings() async {
    final currentSettings = await _storageService.getSettings();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PrompterSettingsSheet(
        settings: currentSettings,
        onSettingsChanged: (updated) {
          _storageService.saveSettings(updated);
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_external_on, color: Color(0xFF6366F1), size: 24),
            SizedBox(width: 8),
            Text('Teleprompter Studio'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_library_outlined),
            tooltip: 'Recorded Takes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecordingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Prompter Settings',
            onPressed: _openGlobalSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewScript,
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Script', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Quick Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _filterScripts();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search scripts or markers...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _filterScripts();
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // Script list
                Expanded(
                  child: _filteredScripts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: _filteredScripts.length,
                          itemBuilder: (context, index) {
                            final script = _filteredScripts[index];
                            return _buildScriptCard(script);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildScriptCard(Script script) {
    final updatedStr = DateFormat('MMM d, yyyy').format(script.updatedAt);
    final markers = script.markers;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openScript(script),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Context Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      script.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
                    color: const Color(0xFF1E293B),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: Colors.white70),
                            SizedBox(width: 8),
                            Text('Edit Script'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 18, color: Colors.white70),
                            SizedBox(width: 8),
                            Text('Duplicate'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Color(0xFFEF4444)),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (val) {
                      if (val == 'edit') {
                        _openScript(script);
                      } else if (val == 'duplicate') {
                        _duplicateScript(script);
                      } else if (val == 'delete') {
                        _deleteScript(script);
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Snippet Preview
              Text(
                script.content.replaceAll('\n', ' '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 12),

              // Cues / Markers chips
              if (markers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: markers.take(4).map((m) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          m.title,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amberAccent,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Stats & Action Buttons
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: const Color(0xFF6366F1)),
                  const SizedBox(width: 4),
                  Text(
                    script.formattedEstimatedTime(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${script.wordCount} words',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• $updatedStr',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  const Spacer(),

                  // Prompter Only Launch
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline, color: Colors.white70),
                    tooltip: 'Prompter Fullscreen',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PrompterScreen(script: script),
                        ),
                      );
                    },
                  ),

                  // Video Recording Studio Launch
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.videocam, size: 18),
                    tooltip: 'Record Studio',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudioRecordingScreen(script: script),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 48,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Scripts Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap "+ New Script" below to start reading!',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
