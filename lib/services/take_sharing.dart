import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recorded_video.dart';
import 'storage_service.dart';

enum ShareAttempt { opened, nothingToShare, alreadyInProgress }

/// Returns the latest stored version of each take (e.g. once its public copy is saved).
typedef TakeRefresher = Future<List<RecordedVideo>> Function(List<RecordedVideo> takes);

/// One way of putting takes in front of the system share sheet.
abstract class VideoShareSheet {
  Future<void> open(List<RecordedVideo> takes, String subject);
}

/// The public copy that a take was shared from has gone (e.g. deleted in Gallery).
class MissingPublicCopyException implements Exception {
  final String? detail;

  const MissingPublicCopyException([this.detail]);
}

/// Sends takes to the share sheet (Quick Share, Drive, Phone Link…) to move
/// them to a computer for editing.
///
/// Takes that already have a public copy are shared straight from it, so the
/// sheet opens at once. Other takes go through share_plus, which first copies
/// each whole video into its cache — seconds for large files — so callers can
/// show [isPreparing] meanwhile.
class TakeSharing {
  static final TakeSharing instance = TakeSharing();

  final VideoShareSheet? _directSheet;
  final VideoShareSheet _copyingSheet;
  final TakeRefresher _refresh;

  /// True from a tap until the share sheet has been handed the videos.
  final ValueNotifier<bool> isPreparing = ValueNotifier(false);

  TakeSharing({VideoShareSheet? directSheet, VideoShareSheet? copyingSheet, TakeRefresher? refresh})
      : _directSheet = directSheet ?? (_isAndroid ? const PublicCopyShareSheet() : null),
        _copyingSheet = copyingSheet ?? const SharePlusShareSheet(),
        _refresh = refresh ?? _latestStoredVersions;

  static Future<List<RecordedVideo>> _latestStoredVersions(List<RecordedVideo> takes) async {
    final storedById = {for (final take in await StorageService().getRecordings()) take.id: take};
    return [for (final take in takes) storedById[take.id] ?? take];
  }

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Future<ShareAttempt> share(List<RecordedVideo> requested) async {
    if (isPreparing.value) return ShareAttempt.alreadyInProgress;
    isPreparing.value = true;
    try {
      final takes = await _refresh(requested);
      final subject = _subjectFor(takes);
      if (await _openDirectly(takes, subject)) return ShareAttempt.opened;
      final appCopies = takes.where((take) => File(take.filePath).existsSync()).toList();
      if (appCopies.isEmpty) return ShareAttempt.nothingToShare;
      await _copyingSheet.open(appCopies, subject);
      return ShareAttempt.opened;
    } finally {
      isPreparing.value = false;
    }
  }

  /// Shares straight from the public copies when every take has one.
  Future<bool> _openDirectly(List<RecordedVideo> takes, String subject) async {
    final directSheet = _directSheet;
    if (directSheet == null || takes.isEmpty || !takes.every(_hasShareablePublicCopy)) return false;
    try {
      await directSheet.open(takes, subject);
      return true;
    } on MissingPublicCopyException catch (error) {
      debugPrint('Public copy missing, sharing the app copy instead: ${error.detail}');
      return false;
    }
  }

  static bool _hasShareablePublicCopy(RecordedVideo take) =>
      take.publicCopyUri?.startsWith('content://') ?? false;

  static String _subjectFor(List<RecordedVideo> takes) =>
      takes.length == 1 ? takes.single.displayName : '${takes.length} Cuevanta takes';
}

/// Android: shares the Movies/Cuevanta copies by URI (see PublicVideoSharer.kt).
class PublicCopyShareSheet implements VideoShareSheet {
  static const MethodChannel _channel = MethodChannel('cuevanta/public_videos');

  const PublicCopyShareSheet();

  @override
  Future<void> open(List<RecordedVideo> takes, String subject) async {
    try {
      await _channel.invokeMethod<void>('shareVideos', {
        'uris': [for (final take in takes) take.publicCopyUri],
        'subject': subject,
      });
    } on PlatformException catch (error) {
      if (error.code == 'missing_public_copy') throw MissingPublicCopyException(error.message);
      rethrow;
    }
  }
}

/// share_plus: works everywhere, but copies each file before the sheet opens.
class SharePlusShareSheet implements VideoShareSheet {
  static const String _videoMimeType = 'video/mp4';

  const SharePlusShareSheet();

  @override
  Future<void> open(List<RecordedVideo> takes, String subject) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final take in takes) XFile(take.filePath, name: take.exportFileName, mimeType: _videoMimeType),
        ],
        subject: subject,
      ),
    );
  }
}
