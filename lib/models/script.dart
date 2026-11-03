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

  Script({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.customSpeed,
    this.customFontSize,
    this.notes,
  });

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
