import 'dart:convert';

class RecordedVideo {
  final String id;
  final String filePath;
  final String scriptId;
  final String scriptTitle;
  final DateTime recordedAt;
  final int durationSeconds;
  final int fileSizeBytes;

  /// 1 for the first take of a script, 2 for the next, and so on.
  final int takeNumber;

  /// The take chosen for editing; at most one per script.
  final bool isBest;

  /// A copy is in the phone's public videos (Movies/Cuevanta or the Photos album).
  final bool isSavedToDevice;

  RecordedVideo({
    required this.id,
    required this.filePath,
    required this.scriptId,
    required this.scriptTitle,
    required this.recordedAt,
    required this.durationSeconds,
    required this.fileSizeBytes,
    this.takeNumber = 1,
    this.isBest = false,
    this.isSavedToDevice = false,
  });

  /// "03 · Glasses that read silent words · take 2"
  String get displayName => takeDisplayName(scriptTitle: scriptTitle, takeNumber: takeNumber);

  /// "03 · Glasses that read silent words" — the script part of [displayName].
  String get scriptDisplayName => _shortScriptName(scriptTitle);

  /// Name of the recording file, readable once copied to a computer.
  String get exportFileName =>
      takeFileName(scriptTitle: scriptTitle, takeNumber: takeNumber, recordedAt: recordedAt);

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

  RecordedVideo copyWith({int? takeNumber, bool? isBest, bool? isSavedToDevice}) {
    return RecordedVideo(
      id: id,
      filePath: filePath,
      scriptId: scriptId,
      scriptTitle: scriptTitle,
      recordedAt: recordedAt,
      durationSeconds: durationSeconds,
      fileSizeBytes: fileSizeBytes,
      takeNumber: takeNumber ?? this.takeNumber,
      isBest: isBest ?? this.isBest,
      isSavedToDevice: isSavedToDevice ?? this.isSavedToDevice,
    );
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
      'takeNumber': takeNumber,
      'isBest': isBest,
      'isSavedToDevice': isSavedToDevice,
    };
  }

  /// Takes saved before numbering existed have no 'takeNumber' (stored as 0);
  /// StorageService numbers them by recording time.
  factory RecordedVideo.fromMap(Map<String, dynamic> map) {
    return RecordedVideo(
      id: map['id'] ?? '',
      filePath: map['filePath'] ?? '',
      scriptId: map['scriptId'] ?? '',
      scriptTitle: map['scriptTitle'] ?? 'Untitled Video',
      recordedAt: DateTime.tryParse(map['recordedAt'] ?? '') ?? DateTime.now(),
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      fileSizeBytes: map['fileSizeBytes'] as int? ?? 0,
      takeNumber: map['takeNumber'] as int? ?? 0,
      isBest: map['isBest'] as bool? ?? false,
      isSavedToDevice: map['isSavedToDevice'] as bool? ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory RecordedVideo.fromJson(String source) =>
      RecordedVideo.fromMap(json.decode(source));
}

const String _titleSeparator = '·';

/// Keeps the script number and topic from an imported title like
/// "03 · THU AM · Glasses that read silent words"; other titles are used as-is.
String _shortScriptName(String scriptTitle) {
  final parts = scriptTitle
      .split(_titleSeparator)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length < 3) return parts.join(' $_titleSeparator ');
  return '${parts.first} $_titleSeparator ${parts.last}';
}

String takeDisplayName({required String scriptTitle, required int takeNumber}) =>
    '${_shortScriptName(scriptTitle)} $_titleSeparator take $takeNumber';

/// "2026-11-04_03-glasses-that-read-silent-words_take-2.mp4" — sorts by date,
/// then script, and is safe on Windows, macOS and Android file systems.
String takeFileName({
  required String scriptTitle,
  required int takeNumber,
  required DateTime recordedAt,
}) {
  final date = '${recordedAt.year.toString().padLeft(4, '0')}-'
      '${recordedAt.month.toString().padLeft(2, '0')}-'
      '${recordedAt.day.toString().padLeft(2, '0')}';
  final script = _slug(_shortScriptName(scriptTitle));
  return '${date}_${script.isEmpty ? 'take' : script}_take-$takeNumber.mp4';
}

String _slug(String text) {
  const maxLength = 60;
  final slug = text
      .toLowerCase()
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length <= maxLength) return slug;
  return slug.substring(0, maxLength).replaceAll(RegExp(r'-+$'), '');
}
