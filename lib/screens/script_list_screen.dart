import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../import/read_file_importer.dart';
import '../models/script.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cuevanta_logo.dart';
import '../widgets/prompter_settings_sheet.dart';
import 'prompter_screen.dart';
import 'recordings_screen.dart';
import 'script_editor_screen.dart';
import 'studio_recording_screen.dart';

class ScriptListScreen extends StatefulWidget {
  const ScriptListScreen({super.key});

  @override
  State<ScriptListScreen> createState() => _ScriptListScreenState();
}

class _ScriptListScreenState extends State<ScriptListScreen> {
  static const int _maxMarkerChips = 4;

  final StorageService _storageService = StorageService();
  final TextEditingController _searchController = TextEditingController();
  List<Script> _allScripts = [];
  List<Script> _filteredScripts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadScripts();
  }

  Future<void> _loadScripts() async {
    final list = await _storageService.getScripts();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (mounted) {
      setState(() {
        _allScripts = list;
        _filterScripts();
        _isLoading = false;
      });
    }
  }

  void _filterScripts() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredScripts = query.isEmpty
        ? List.of(_allScripts)
        : _allScripts
            .where((s) =>
                s.title.toLowerCase().contains(query) ||
                s.content.toLowerCase().contains(query))
            .toList();
  }

  void _updateSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filterScripts();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _updateSearch('');
  }

  Future<void> _pushAndReload(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _loadScripts();
  }

  Future<void> _duplicateScript(Script script) async {
    final now = DateTime.now();
    final copy = script.copyWith(
      id: 'script_${now.millisecondsSinceEpoch}',
      title: '${script.title} (Copy)',
      createdAt: now,
      updatedAt: now,
    );
    await _storageService.addOrUpdateScript(copy);
    _loadScripts();
  }

  /// Deletes immediately and offers an undo, instead of a blocking confirm dialog.
  Future<void> _deleteScript(Script script) async {
    final messenger = ScaffoldMessenger.of(context);
    await _storageService.deleteScript(script.id);
    await _loadScripts();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${script.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _storageService.addOrUpdateScript(script);
              _loadScripts();
            },
          ),
        ),
      );
  }

  /// Lets the user pick a weekly READ .md file and turns each section into a script.
  Future<void> _importReadFile() async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await FilePicker.pickFile(dialogTitle: 'Choose a READ .md file');
    if (file == null) return;

    try {
      final markdown = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      final summary = await ReadFileImporter().importMarkdown(markdown, sourceName: file.name);
      await _loadScripts();
      _showMessage(messenger, _describeImport(summary));
    } on FormatException catch (error) {
      _showMessage(messenger, 'Couldn\'t import ${file.name}: ${error.message}');
    }
  }

  String _describeImport(ReadImportSummary summary) {
    final noun = summary.total == 1 ? 'script' : 'scripts';
    final parts = [
      if (summary.added > 0) '${summary.added} new',
      if (summary.updated > 0) '${summary.updated} updated',
    ];
    return 'Imported ${summary.total} $noun (${parts.join(', ')})';
  }

  void _showMessage(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        onSettingsChanged: _storageService.saveSettings,
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
        titleSpacing: 20,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CuevantaAppIcon(),
            SizedBox(width: 10),
            Flexible(child: Text('Cuevanta', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Import READ file',
            onPressed: _importReadFile,
          ),
          IconButton(
            icon: const Icon(Icons.video_library_outlined),
            tooltip: 'Recorded takes',
            onPressed: () => _pushAndReload(const RecordingsScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Prompter settings',
            onPressed: _openGlobalSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pushAndReload(const ScriptEditorScreen()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Script'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadScripts,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildLibrarySummary()),
                  SliverToBoxAdapter(child: _buildSearchField()),
                  if (_filteredScripts.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverList.separated(
                        itemCount: _filteredScripts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _buildScriptCard(_filteredScripts[index]),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildLibrarySummary() {
    final totalSeconds =
        _allScripts.fold<int>(0, (sum, s) => sum + s.estimatedReadingTimeSeconds());
    final totalMinutes = (totalSeconds / 60).ceil();
    final scriptLabel = _allScripts.length == 1 ? 'script' : 'scripts';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Text(
        '${_allScripts.length} $scriptLabel  ·  ~$totalMinutes min of reading',
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _searchController,
        onChanged: _updateSearch,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search scripts',
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Clear search',
                  onPressed: _clearSearch,
                ),
        ),
      ),
    );
  }

  Widget _buildScriptCard(Script script) {
    final markers = script.markers;

    return Card(
      child: InkWell(
        onTap: () => _pushAndReload(ScriptEditorScreen(script: script)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        script.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  _buildScriptMenu(script),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _previewText(script),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.45),
                ),
              ),
              if (markers.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final marker in markers.take(_maxMarkerChips)) _MarkerChip(marker.title),
                    if (markers.length > _maxMarkerChips)
                      _MarkerChip('+${markers.length - _maxMarkerChips}'),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildScriptStats(script)),
                  IconButton.filledTonal(
                    tooltip: 'Prompt fullscreen',
                    icon: const Icon(Icons.slideshow_rounded, size: 20),
                    onPressed: () => _pushAndReload(PrompterScreen(script: script)),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.recordingRed,
                      foregroundColor: Colors.white,
                    ),
                    tooltip: 'Record with prompter',
                    icon: const Icon(Icons.videocam_rounded, size: 20),
                    onPressed: () => _pushAndReload(StudioRecordingScreen(script: script)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Script body without cue tags, for the card preview.
  String _previewText(Script script) {
    final withoutMarkers = script.content.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    final collapsed = withoutMarkers.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.isEmpty ? 'Empty script — tap to start writing' : collapsed;
  }

  Widget _buildScriptStats(Script script) {
    const subtleStyle = TextStyle(fontSize: 12, color: AppTheme.textSubtle);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.primaryLight),
            const SizedBox(width: 4),
            Text(
              script.formattedEstimatedTime(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryLight,
              ),
            ),
          ],
        ),
        Text('${script.wordCount} words', style: subtleStyle),
        Text(DateFormat('MMM d').format(script.updatedAt), style: subtleStyle),
      ],
    );
  }

  Widget _buildScriptMenu(Script script) {
    return PopupMenuButton<VoidCallback>(
      icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted),
      tooltip: 'More',
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        _menuItem(
          icon: Icons.edit_outlined,
          label: 'Edit',
          action: () => _pushAndReload(ScriptEditorScreen(script: script)),
        ),
        _menuItem(
          icon: Icons.copy_rounded,
          label: 'Duplicate',
          action: () => _duplicateScript(script),
        ),
        _menuItem(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          action: () => _deleteScript(script),
          color: AppTheme.recordingRed,
        ),
      ],
    );
  }

  PopupMenuItem<VoidCallback> _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback action,
    Color color = Colors.white,
  }) {
    return PopupMenuItem<VoidCallback>(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color.withValues(alpha: 0.85)),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSearching ? Icons.search_off_rounded : Icons.description_outlined,
              size: 44,
              color: AppTheme.primaryLight,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isSearching ? 'No matches' : 'No scripts yet',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Nothing matches "${_searchQuery.trim()}".'
                : 'Tap "New Script" to write your first one.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
          ),
          if (isSearching) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: _clearSearch, child: const Text('Clear search')),
          ] else ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _importReadFile,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Import a READ file'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MarkerChip extends StatelessWidget {
  final String label;

  const _MarkerChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.amberAccent,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
