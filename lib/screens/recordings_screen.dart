import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recorded_video.dart';
import '../models/take_library.dart';
import '../services/device_video_library.dart';
import '../services/storage_service.dart';
import '../services/take_sharing.dart';
import '../theme/app_theme.dart';
import '../widgets/gold_button.dart';
import '../widgets/gold_ring_icon.dart';
import 'video_player_screen.dart';

class RecordingsScreen extends StatefulWidget {
  /// Where takes are copied outside the app; defaults to this phone's.
  final DeviceVideoLibrary? deviceLibrary;

  const RecordingsScreen({super.key, this.deviceLibrary});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final StorageService _storageService = StorageService();
  List<RecordedVideo> _recordings = [];
  bool _isLoading = true;
  late final DeviceVideoLibrary _deviceLibrary = widget.deviceLibrary ?? DeviceVideoLibrary.forThisDevice();

  /// Progress while copying older takes, e.g. (2, 5); null when idle.
  (int, int)? _copyProgress;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    final list = await _storageService.getRecordings();
    if (mounted) {
      setState(() {
        _recordings = list;
        _isLoading = false;
      });
    }
  }

  List<RecordedVideo> get _bestTakes => TakeLibrary.bestTakes(_recordings);

  /// Takes that only exist inside the app (and whose files are still here).
  List<RecordedVideo> get _takesOnlyInApp => _recordings
      .where((take) => !take.isSavedToDevice && File(take.filePath).existsSync())
      .toList();

  Future<void> _copyTakesToDevice(List<RecordedVideo> takes) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = <String>{};
    var permissionDenied = false;
    for (var i = 0; i < takes.length && !permissionDenied; i++) {
      setState(() => _copyProgress = (i + 1, takes.length));
      final outcome = await _deviceLibrary.save(takes[i]);
      if (outcome == DeviceSaveOutcome.saved) copied.add(takes[i].id);
      permissionDenied = outcome == DeviceSaveOutcome.permissionDenied;
    }
    final updated = await _storageService.markSavedToDevice(copied);
    if (!mounted) return;
    setState(() {
      _recordings = updated;
      _copyProgress = null;
    });
    final failed = takes.length - copied.length;
    messenger.showSnackBar(SnackBar(
      content: Text(failed == 0
          ? 'Copied ${copied.length} to ${_deviceLibrary.locationLabel}'
          : 'Copied ${copied.length}; $failed could not be copied${permissionDenied ? ' (permission not given)' : ''}.'),
    ));
  }

  /// Takes grouped by script: most recently recorded script first, newest take first.
  List<List<RecordedVideo>> get _takesByScript {
    final groups = <String, List<RecordedVideo>>{};
    for (final take in _recordings) {
      groups.putIfAbsent(take.scriptId, () => []).add(take);
    }
    final ordered = groups.values.map((takes) => takes..sort((a, b) => b.takeNumber.compareTo(a.takeNumber))).toList()
      ..sort((a, b) => _latest(b).compareTo(_latest(a)));
    return ordered;
  }

  static DateTime _latest(List<RecordedVideo> takes) =>
      takes.map((t) => t.recordedAt).reduce((a, b) => a.isAfter(b) ? a : b);

  Future<void> _playVideo(RecordedVideo video) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video)),
    );
    _loadRecordings();
  }

  Future<void> _toggleBest(RecordedVideo video) async {
    final updated = await _storageService.toggleBestTake(video.id);
    if (mounted) setState(() => _recordings = updated);
  }

  Future<void> _share(List<RecordedVideo> takes) async {
    final messenger = ScaffoldMessenger.of(context);
    final shared = await TakeSharing.share(takes);
    if (!shared) {
      messenger.showSnackBar(const SnackBar(content: Text('Those video files are no longer on this device.')));
    }
  }

  Future<void> _deleteRecording(RecordedVideo video) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this take?'),
        content: Text(video.isSavedToDevice
            ? '${video.displayName} will be removed from Cuevanta. '
                'The copy in ${_deviceLibrary.locationLabel} is kept.'
            : '${video.displayName} (${video.formattedDuration}) will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.recordingRed,
              foregroundColor: AppTheme.textPrimary,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final file = File(video.filePath);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      debugPrint('Could not delete ${video.filePath}: ${error.message}');
    }
    await _storageService.deleteRecording(video.id);
    _loadRecordings();
  }

  @override
  Widget build(BuildContext context) {
    final bestTakes = _bestTakes;
    return Scaffold(
      appBar: AppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(bestTakes.length)),
                if (_deviceLibrary.isAvailable && _takesOnlyInApp.isNotEmpty)
                  SliverToBoxAdapter(child: _buildCopyToDeviceBanner(_takesOnlyInApp)),
                if (bestTakes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: GoldButton(
                        label: 'Share best takes (${bestTakes.length})',
                        icon: Icons.ios_share_rounded,
                        onPressed: () => _share(bestTakes),
                      ),
                    ),
                  ),
                if (_recordings.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
                else
                  for (final takes in _takesByScript) ..._buildScriptGroup(takes),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildHeader(int bestCount) {
    final takeLabel = _recordings.length == 1 ? 'TAKE' : 'TAKES';
    final bestLabel = bestCount == 0 ? '' : '  ·  $bestCount BEST';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_recordings.length} $takeLabel$bestLabel', style: AppTheme.eyebrow),
          const SizedBox(height: 10),
          const Text(
            'Recorded takes',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w300, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScriptGroup(List<RecordedVideo> takes) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          child: Text(
            takes.first.scriptDisplayName.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.eyebrow.copyWith(fontSize: 10, letterSpacing: 2, height: 1.5),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.separated(
          itemCount: takes.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _buildTakeCard(takes[index]),
        ),
      ),
    ];
  }

  Widget _buildTakeCard(RecordedVideo video) {
    final recordedAt = DateFormat('d MMM · h:mm a').format(video.recordedAt);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: BorderSide(color: video.isBest ? AppTheme.gold.withValues(alpha: 0.6) : AppTheme.border),
      ),
      child: InkWell(
        onTap: () => _playVideo(video),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 4, 10),
          child: Row(
            children: [
              _BestTakeStar(isBest: video.isBest, onPressed: () => _toggleBest(video)),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Take ${video.takeNumber}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle),
                        children: [
                          TextSpan(
                            text: video.formattedDuration,
                            style: const TextStyle(color: AppTheme.goldLight, fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: '   ${video.formattedSize}   $recordedAt'),
                          if (video.isSavedToDevice)
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(Icons.download_done_rounded, size: 14, color: AppTheme.gold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: 'Share take',
                onPressed: () => _share([video]),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.textSubtle),
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete take',
                onPressed: () => _deleteRecording(video),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopyToDeviceBanner(List<RecordedVideo> takesOnlyInApp) {
    final progress = _copyProgress;
    final noun = takesOnlyInApp.length == 1 ? 'take is' : 'takes are';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppTheme.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              progress == null
                  ? '${takesOnlyInApp.length} $noun only inside Cuevanta and would be lost if the app is removed.'
                  : 'Copying ${progress.$1} of ${progress.$2} to ${_deviceLibrary.locationLabel}…',
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textBody),
            ),
          ),
          if (progress == null)
            TextButton(
              onPressed: () => _copyTakesToDevice(takesOnlyInApp),
              child: const Text('Save copies'),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, 96),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GoldRingIcon(icon: Icons.videocam_outlined),
          SizedBox(height: 24),
          Text('No takes yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300)),
          SizedBox(height: 10),
          Text(
            'Open a script and tap the record button to read and film at the same time.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Gold star when this is the script's chosen take; tap to choose or clear it.
class _BestTakeStar extends StatelessWidget {
  final bool isBest;
  final VoidCallback onPressed;

  const _BestTakeStar({required this.isBest, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isBest ? 'Best take (tap to clear)' : 'Mark as best take',
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(
        isBest ? Icons.star_rounded : Icons.star_outline_rounded,
        color: isBest ? AppTheme.gold : AppTheme.textSubtle,
        size: 26,
      ),
    );
  }
}
