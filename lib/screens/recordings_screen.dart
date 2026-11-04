import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recorded_video.dart';
import '../services/storage_service.dart';
import 'video_player_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/gold_ring_icon.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final StorageService _storageService = StorageService();
  List<RecordedVideo> _recordings = [];
  bool _isLoading = true;

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

  void _playVideo(RecordedVideo video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(video: video),
      ),
    );
  }

  void _shareVideo(RecordedVideo video) {
    final file = File(video.filePath);
    if (file.existsSync()) {
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(video.filePath)],
          subject: 'Recorded take from ${video.scriptTitle}',
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found to share.')),
      );
    }
  }

  Future<void> _deleteRecording(RecordedVideo video) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: const Text('Delete Recording?'),
        content: Text('Delete this take (${video.formattedDuration})?'),
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

    if (confirm == true) {
      try {
        final file = File(video.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
      await _storageService.deleteRecording(video.id);
      _loadRecordings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                if (_recordings.isEmpty)
                  SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: _recordings.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildTakeCard(_recordings[index]),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final takeLabel = _recordings.length == 1 ? 'TAKE' : 'TAKES';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_recordings.length} $takeLabel', style: AppTheme.eyebrow),
          const SizedBox(height: 10),
          const Text(
            'Recorded takes',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w300, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTakeCard(RecordedVideo video) {
    final recordedAt = DateFormat('EEE d MMM · h:mm a').format(video.recordedAt);
    return Card(
      child: InkWell(
        onTap: () => _playVideo(video),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
          child: Row(
            children: [
              const GoldRingIcon(icon: Icons.play_arrow_rounded, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.scriptTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSubtle),
                        children: [
                          TextSpan(
                            text: video.formattedDuration,
                            style: const TextStyle(color: AppTheme.goldLight, fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: '   ${video.formattedSize}   $recordedAt'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                tooltip: 'Share take',
                onPressed: () => _shareVideo(video),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.textSubtle),
                tooltip: 'Delete take',
                onPressed: () => _deleteRecording(video),
              ),
            ],
          ),
        ),
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
