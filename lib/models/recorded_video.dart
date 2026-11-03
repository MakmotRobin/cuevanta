import 'dart:convert';

class RecordedVideo {
  final String id;
  final String filePath;
  final String scriptId;
  final String scriptTitle;
  final DateTime recordedAt;
  final int durationSeconds;
  final int fileSizeBytes;

  RecordedVideo({
    required this.id,
    required this.filePath,
    required this.scriptId,
    required this.scriptTitle,
    required this.recordedAt,
    required this.durationSeconds,
    required this.fileSizeBytes,
  });

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'scriptId': scriptId,
      'scriptTitle': scriptTitle,
      'recordedAt': recordedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'fileSizeBytes': fileSizeBytes,
    };
  }

  factory RecordedVideo.fromMap(Map<String, dynamic> map) {
    return RecordedVideo(
      id: map['id'] ?? '',
      filePath: map['filePath'] ?? '',
      scriptId: map['scriptId'] ?? '',
      scriptTitle: map['scriptTitle'] ?? 'Untitled Video',
      recordedAt: DateTime.tryParse(map['recordedAt'] ?? '') ?? DateTime.now(),
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      fileSizeBytes: map['fileSizeBytes'] as int? ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory RecordedVideo.fromJson(String source) =>
      RecordedVideo.fromMap(json.decode(source));
}
