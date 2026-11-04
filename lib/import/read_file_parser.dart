/// One script section parsed from a weekly READ markdown file.
class ParsedReadScript {
  /// Stable across re-imports of the same week, so re-importing updates
  /// existing scripts instead of duplicating them.
  final String id;
  final String title;
  final String content;
  final List<String> backupOpenings;

  const ParsedReadScript({
    required this.id,
    required this.title,
    required this.content,
    required this.backupOpenings,
  });
}

/// Parses the "READ" files written by the weekly script task.
///
/// Format: a `# READ — <week>` title and intro line, then `## N · DAY · SLOT · TOPIC`
/// sections of one spoken sentence per line, each optionally followed by an italic
/// `*Backup opening lines:*` block of `*— …*` lines. Sections are separated by `---`,
/// and other `#` headings (like `# SPARE SCRIPTS`) only group sections.
class ReadFileParser {
  static const String _sectionPrefix = '## ';
  static const String _headingSeparator = '·';
  static final RegExp _backupHeader = RegExp(r'^\*+\s*backup opening lines?\s*:?\s*\*+$', caseSensitive: false);
  static final RegExp _backupLine = RegExp(r'^\*+\s*[—–-]\s*(.+?)\s*\*+$');
  static final RegExp _horizontalRule = RegExp(r'^(-{3,}|\*{3,}|_{3,})$');
  static final RegExp _documentTitle = RegExp(r'^#\s+READ\s*[—–-]\s*(.+)$', caseSensitive: false);

  /// [sourceName] (usually the file name) identifies the week when the file has no title line.
  List<ParsedReadScript> parse(String markdown, {required String sourceName}) {
    final lines = _normalizeLineEndings(markdown).split('\n').map((l) => l.trim()).toList();
    final weekKey = _slugify(_documentTitleOf(lines) ?? sourceName);
    return _splitIntoSections(lines)
        .map((section) => _parseSection(section, weekKey))
        .whereType<ParsedReadScript>()
        .toList();
  }

  String _normalizeLineEndings(String text) =>
      text.replaceAll('﻿', '').replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  String? _documentTitleOf(List<String> lines) {
    for (final line in lines) {
      final match = _documentTitle.firstMatch(line);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// Groups lines under each `## ` heading; the heading is the first line of each group.
  List<List<String>> _splitIntoSections(List<String> lines) {
    final sections = <List<String>>[];
    List<String>? currentSection;
    for (final line in lines) {
      if (line.startsWith(_sectionPrefix)) {
        currentSection = [line];
        sections.add(currentSection);
      } else if (_isTopLevelHeading(line)) {
        currentSection = null;
      } else {
        currentSection?.add(line);
      }
    }
    return sections;
  }

  bool _isTopLevelHeading(String line) => line.startsWith('# ');

  ParsedReadScript? _parseSection(List<String> section, String weekKey) {
    final heading = section.first.substring(_sectionPrefix.length).trim();
    final body = section.skip(1).where((l) => l.isNotEmpty && !_horizontalRule.hasMatch(l));

    final spokenLines = <String>[];
    final backupOpenings = <String>[];
    var inBackupBlock = false;
    for (final line in body) {
      if (_backupHeader.hasMatch(line)) {
        inBackupBlock = true;
        continue;
      }
      final backup = _backupLine.firstMatch(line);
      if (inBackupBlock && backup != null) {
        backupOpenings.add(_stripInlineMarkdown(backup.group(1)!));
      } else {
        inBackupBlock = false;
        spokenLines.add(_stripInlineMarkdown(line));
      }
    }
    if (spokenLines.isEmpty) return null;

    final headingParts = heading.split(_headingSeparator).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    final sectionNumber = headingParts.length > 1 ? headingParts.first : '';
    final content = spokenLines.join('\n');

    return ParsedReadScript(
      id: 'read-$weekKey-${_slugify(sectionNumber.isEmpty ? heading : sectionNumber)}',
      title: _buildTitle(headingParts, content),
      content: content,
      backupOpenings: backupOpenings,
    );
  }

  /// "1 · WED · AM · CHATGPT IS …" → "01 · WED AM · ChatGPT is …"
  String _buildTitle(List<String> headingParts, String spokenText) {
    final topic = HeadingCaseRestorer(spokenText).restore(headingParts.last);
    if (headingParts.length == 1) return topic;

    final number = _padSectionNumber(headingParts.first);
    final labels = headingParts.sublist(1, headingParts.length - 1).join(' ');
    return [number, if (labels.isNotEmpty) labels, topic].join(' · ');
  }

  String _padSectionNumber(String number) =>
      int.tryParse(number) != null ? number.padLeft(2, '0') : number;

  /// Removes bold/italic markers while keeping backslash-escaped characters literally.
  String _stripInlineMarkdown(String text) {
    final escaped = <String>[];
    final protected = text.replaceAllMapped(RegExp(r'\\([\\`*_{}\[\]()#+\-.!])'), (m) {
      escaped.add(m.group(1)!);
      return '\u0000${escaped.length - 1}\u0000';
    });
    final unstyled = protected
        .replaceAllMapped(RegExp(r'(\*\*|__)(.+?)\1'), (m) => m.group(2)!)
        .replaceAllMapped(RegExp(r'(?<!\w)[*_](.+?)[*_](?!\w)'), (m) => m.group(1)!);
    return unstyled
        .replaceAllMapped(RegExp('\u0000(\\d+)\u0000'), (m) => escaped[int.parse(m.group(1)!)])
        .trim();
  }

  String _slugify(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Turns an ALL-CAPS heading into sentence case, borrowing each word's
/// casing from the script body so names survive ("CHATGPT" → "ChatGPT", "AI" → "AI").
class HeadingCaseRestorer {
  final Map<String, String> _casingByLowercaseWord;

  HeadingCaseRestorer(String bodyText) : _casingByLowercaseWord = _learnCasing(bodyText);

  String restore(String heading) {
    final words = heading.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final restored = [for (final word in words) _restoreWord(word)];
    if (restored.isNotEmpty) restored[0] = _capitalizeFirstLetter(restored[0]);
    return restored.join(' ');
  }

  String _restoreWord(String word) {
    final core = _wordCore(word);
    if (core.isEmpty) return word.toLowerCase();
    final learned = _casingByLowercaseWord[core.toLowerCase()];
    return word.replaceFirst(core, learned ?? core.toLowerCase());
  }

  static String _capitalizeFirstLetter(String word) {
    final index = word.indexOf(RegExp(r'[A-Za-z]'));
    if (index < 0) return word;
    return word.substring(0, index) + word[index].toUpperCase() + word.substring(index + 1);
  }

  static bool _isOnlyInitialCapital(String word) =>
      word.length < 2 || word.substring(1) == word.substring(1).toLowerCase();

  static String _wordCore(String word) =>
      RegExp(r"[A-Za-z0-9][A-Za-z0-9'’]*[A-Za-z0-9]|[A-Za-z0-9]").firstMatch(word)?.group(0) ?? '';

  /// Ignores plain "Capitalised" words at sentence starts, where the capital
  /// says nothing about the word itself. Mixed case like "ChatGPT" counts anywhere.
  static Map<String, String> _learnCasing(String bodyText) {
    final counts = <String, Map<String, int>>{};
    for (final sentence in bodyText.split(RegExp(r'(?<=[.!?:])\s+|\n'))) {
      final words = sentence.split(RegExp(r'\s+')).map(_wordCore).where((w) => w.isNotEmpty).toList();
      for (var i = 0; i < words.length; i++) {
        if (i == 0 && _isOnlyInitialCapital(words[i])) continue;
        final variants = counts.putIfAbsent(words[i].toLowerCase(), () => {});
        variants[words[i]] = (variants[words[i]] ?? 0) + 1;
      }
    }
    return {
      for (final entry in counts.entries)
        entry.key: entry.value.entries.reduce((a, b) => b.value > a.value ? b : a).key,
    };
  }
}
