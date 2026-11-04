import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../models/recorded_video.dart';

/// Sends takes to the system share sheet (Quick Share, Drive, Phone Link…)
/// so they can be moved to a computer for editing.
class TakeSharing {
  const TakeSharing._();

  static const String _videoMimeType = 'video/mp4';

  /// Shares the takes whose files still exist. Returns false when none do.
  static Future<bool> share(List<RecordedVideo> takes) async {
    final available = takes.where((take) => File(take.filePath).existsSync()).toList();
    if (available.isEmpty) return false;

    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final take in available)
            XFile(take.filePath, name: take.exportFileName, mimeType: _videoMimeType),
        ],
        subject: _subjectFor(available),
      ),
    );
    return true;
  }

  static String _subjectFor(List<RecordedVideo> takes) =>
      takes.length == 1 ? takes.single.displayName : '${takes.length} Cuevanta takes';
}
