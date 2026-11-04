import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../import/read_file_importer.dart';
import '../models/script.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cuevanta_logo.dart';
import '../widgets/gold_button.dart';
import '../widgets/gold_ring_icon.dart';
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: GoldButton(
        label: 'New script',
        icon: Icons.add_rounded,
        onPressed: () => _pushAndReload(const ScriptEditorScreen()),
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadScripts,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildBrandBar()),
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildSearchField()),
                    if (_filteredScripts.isEmpty)
                      SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        sliver: SliverList.separated(
                          itemCount: _filteredScripts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                          itemBuilder: (context, index) =>
                              _buildScriptCard(_filteredScripts[index]),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBrandBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
      child: Row(
        children: [
          const CuevantaMark(size: 26),
          const SizedBox(width: 10),
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CuevantaWordmark(fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
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
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalSeconds =
        _allScripts.fold<int>(0, (sum, s) => sum + s.estimatedReadingTimeSeconds());
    final totalMinutes = (totalSeconds / 60).ceil();
    final scriptLabel = _allScripts.length == 1 ? 'SCRIPT' : 'SCRIPTS';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_allScripts.length} $scriptLabel  ·  $totalMinutes MIN', style: AppTheme.eyebrow),
          const SizedBox(height: 10),
          const Text(
            'Your scripts',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.5,
              height: 1.15,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final pill = BorderRadius.circular(30);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: TextField(
        controller: _searchController,
        onChanged: _updateSearch,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search',
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: pill,
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: pill,
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: pill,
            borderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.6)),
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
    return Card(
      child: InkWell(
        onTap: () => _pushAndReload(ScriptEditorScreen(script: script)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        script.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  _buildScriptMenu(script),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  _previewText(script),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.55),
                ),
              ),
              if (script.markers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    _markerSummary(script),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.eyebrow.copyWith(fontSize: 9.5, letterSpacing: 1.8),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Divider(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildScriptStats(script)),
                  _CircleAction(
                    tooltip: 'Prompt fullscreen',
                    onPressed: () => _pushAndReload(PrompterScreen(script: script)),
                    child: const Icon(Icons.play_arrow_rounded, color: AppTheme.gold, size: 22),
                  ),
                  const SizedBox(width: 10),
                  _CircleAction(
                    tooltip: 'Record with prompter',
                    onPressed: () => _pushAndReload(StudioRecordingScreen(script: script)),
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppTheme.recordingRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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

  String _markerSummary(Script script) =>
      script.markers.map((m) => m.title.toUpperCase()).join('  ·  ');

  Widget _buildScriptStats(Script script) {
    final updated = DateFormat('MMM d').format(script.updatedAt);
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle, letterSpacing: 0.2),
        children: [
          TextSpan(
            text: script.formattedEstimatedTime(),
            style: const TextStyle(color: AppTheme.goldLight, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: '   ${script.wordCount} words   $updated'),
        ],
      ),
    );
  }

  Widget _buildScriptMenu(Script script) {
    return PopupMenuButton<VoidCallback>(
      icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.textSubtle),
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
    Color color = AppTheme.textPrimary,
  }) {
    return PopupMenuItem<VoidCallback>(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color.withValues(alpha: 0.85)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 140),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GoldRingIcon(
            icon: isSearching ? Icons.search_off_rounded : Icons.auto_stories_outlined,
          ),
          const SizedBox(height: 24),
          Text(
            isSearching ? 'No matches' : 'Nothing to read yet',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w300),
          ),
          const SizedBox(height: 10),
          Text(
            isSearching
                ? 'Nothing matches "${_searchQuery.trim()}".'
                : 'Write a new script, or import this week\'s READ file.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          if (isSearching)
            TextButton(onPressed: _clearSearch, child: const Text('Clear search'))
          else
            OutlinedButton.icon(
              onPressed: _importReadFile,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('IMPORT READ FILE'),
            ),
        ],
      ),
    );
  }
}

/// Quiet circular action with a hairline gold ring.
class _CircleAction extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  const _CircleAction({required this.tooltip, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 26,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
          ),
          child: child,
        ),
      ),
    );
  }
}
