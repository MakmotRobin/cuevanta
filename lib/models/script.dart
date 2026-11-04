import 'dart:convert';

/// Represents a teleprompter script with metadata, content, and section markers.
class Script {
  final String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  double? customSpeed; // optional script-specific scroll speed
  double? customFontSize; // optional script-specific font size
  String? notes;

  /// Alternative first lines (e.g. from an imported READ file) that can be swapped in.
  List<String> backupOpenings;

  Script({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.customSpeed,
    this.customFontSize,
    this.notes,
    List<String>? backupOpenings,
  }) : backupOpenings = backupOpenings ?? [];

  /// Approximate word count
  int get wordCount {
    if (content.trim().isEmpty) return 0;
    return content.trim().split(RegExp(r'\s+')).length;
  }

  /// Character count excluding linebreaks
  int get charCount => content.replaceAll(RegExp(r'\s'), '').length;

  /// Estimated speaking time in seconds at standard speaking rate (130 words per minute)
  int estimatedReadingTimeSeconds({int wordsPerMinute = 130}) {
    if (wordCount == 0) return 0;
    return ((wordCount / wordsPerMinute) * 60).round();
  }

  /// Formatted duration string e.g. "2m 15s"
  String formattedEstimatedTime({int wordsPerMinute = 130}) {
    final seconds = estimatedReadingTimeSeconds(wordsPerMinute: wordsPerMinute);
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes == 0) return '${remainingSeconds}s';
    return '${minutes}m ${remainingSeconds.toString().padLeft(2, '0')}s';
  }

  /// The first spoken line: the first non-blank line that isn't a [MARKER].
  String? get openingLine {
    final index = _openingLineIndex(content.split('\n'));
    return index == null ? null : content.split('\n')[index].trim();
  }

  /// Puts backup opening [backupIndex] in place of the current opening line,
  /// and stores the replaced line in its slot so the swap can be undone.
  Script withOpeningSwapped(int backupIndex) {
    final lines = content.split('\n');
    final openingIndex = _openingLineIndex(lines);
    if (openingIndex == null || backupIndex < 0 || backupIndex >= backupOpenings.length) {
      return copyWith();
    }

    final swappedBackups = List.of(backupOpenings);
    swappedBackups[backupIndex] = lines[openingIndex].trim();
    lines[openingIndex] = backupOpenings[backupIndex];
    return copyWith(content: lines.join('\n'), backupOpenings: swappedBackups);
  }

  static int? _openingLineIndex(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      final isMarker = trimmed.startsWith('[') && trimmed.endsWith(']');
      if (trimmed.isNotEmpty && !isMarker) return i;
    }
    return null;
  }

  /// Extract bookmarks / cue tags formatted like [INTRO], [POINT 1], etc.
  List<ScriptMarker> get markers {
    final regex = RegExp(r'\[([A-Za-z0-9 _\-:]{2,30})\]');
    final matches = regex.allMatches(content);
    return matches.map((m) {
      return ScriptMarker(
        title: m.group(1) ?? '',
        index: m.start,
        fullMatch: m.group(0) ?? '',
      );
    }).toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'customSpeed': customSpeed,
      'customFontSize': customFontSize,
      'notes': notes,
      'backupOpenings': backupOpenings,
    };
  }

  factory Script.fromMap(Map<String, dynamic> map) {
    return Script(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Untitled Script',
      content: map['content'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      customSpeed: (map['customSpeed'] as num?)?.toDouble(),
      customFontSize: (map['customFontSize'] as num?)?.toDouble(),
      notes: map['notes'],
      backupOpenings: (map['backupOpenings'] as List?)?.whereType<String>().toList(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Script.fromJson(String source) => Script.fromMap(json.decode(source));

  Script copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? customSpeed,
    double? customFontSize,
    String? notes,
    List<String>? backupOpenings,
  }) {
    return Script(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customSpeed: customSpeed ?? this.customSpeed,
      customFontSize: customFontSize ?? this.customFontSize,
      notes: notes ?? this.notes,
      backupOpenings: backupOpenings ?? List.of(this.backupOpenings),
    );
  }
}

class ScriptMarker {
  final String title;
  final int index;
  final String fullMatch;

  const ScriptMarker({
    required this.title,
    required this.index,
    required this.fullMatch,
  });
}
