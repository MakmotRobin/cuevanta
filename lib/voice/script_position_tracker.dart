/// A spoken word in the script and where it sits in the prompter's text.
class ScriptWord {
  /// Index of the line (as split on '\n') the word belongs to.
  final int paragraphIndex;

  /// Character offset of the word's first letter within that line.
  final int charOffset;

  /// Lowercase, punctuation-free form used for matching.
  final String normalized;

  const ScriptWord({
    required this.paragraphIndex,
    required this.charOffset,
    required this.normalized,
  });
}

/// Follows a reader through the script from speech-recognition transcripts.
///
/// Each update compares the last few heard words with the script around the
/// current position and moves to the best-matching place. Common words count
/// for less, so "and the" alone never causes a jump. Moving backwards needs a
/// stronger match than moving forwards, so recognition noise can't drag the
/// text back up.
class ScriptPositionTracker {
  static const int _wordsCompared = 4;
  static const int _lookBehind = 15;
  static const int _lookAhead = 30;
  static const double _minimumForwardScore = 1.5;
  static const double _minimumBackwardScore = 3.0;
  static const double _commonWordWeight = 0.5;

  static const Set<String> _commonWords = {
    'a', 'an', 'and', 'are', 'as', 'at', 'be', 'but', 'by', 'for', 'from', 'i', 'if', 'in',
    'is', 'it', 'its', 'of', 'on', 'or', 'so', 'that', 'the', 'this', 'to', 'was', 'we',
    'with', 'you', 'your',
  };

  static const Map<String, String> _numberWords = {
    'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5',
    'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10', 'eleven': '11',
    'twelve': '12', 'twenty': '20', 'hundred': '100',
  };

  final List<ScriptWord> words;

  /// Index into [words] of the last word the reader said, or -1 before the start.
  int _currentIndex = -1;

  ScriptPositionTracker(String content) : words = _indexWords(content);

  int get currentIndex => _currentIndex;

  ScriptWord? get currentWord => _currentIndex >= 0 ? words[_currentIndex] : null;

  bool get isAtEnd => words.isNotEmpty && _currentIndex == words.length - 1;

  /// Updates the position from the recogniser's running transcript.
  /// Returns true when the position changed.
  bool updateWithTranscript(String transcript) {
    final heard = normalizeWords(transcript);
    if (heard.isEmpty || words.isEmpty) return false;

    final tail = heard.sublist(heard.length > _wordsCompared ? heard.length - _wordsCompared : 0);
    final match = _bestMatch(tail);
    if (match == null || match == _currentIndex) return false;
    _currentIndex = match;
    return true;
  }

  /// Moves to just before the first spoken word of [paragraphIndex] (after a manual jump).
  void moveToParagraph(int paragraphIndex) {
    final firstWord = words.indexWhere((w) => w.paragraphIndex >= paragraphIndex);
    _currentIndex = firstWord < 0 ? words.length - 1 : firstWord - 1;
  }

  void reset() => _currentIndex = -1;

  int? _bestMatch(List<String> tail) {
    final first = (_currentIndex - _lookBehind).clamp(0, words.length - 1);
    final last = (_currentIndex + _lookAhead).clamp(0, words.length - 1);

    int? bestIndex;
    var bestScore = 0.0;
    var bestDistance = 1 << 30;
    for (var end = first; end <= last; end++) {
      final score = _alignmentScore(tail, end);
      final isBackward = end < _currentIndex;
      final threshold = isBackward ? _minimumBackwardScore : _minimumForwardScore;
      if (score < _requiredScore(tail, threshold)) continue;

      final distance = (end - _currentIndex).abs();
      final isBetter = score > bestScore || (score == bestScore && distance < bestDistance);
      if (isBetter) {
        bestIndex = end;
        bestScore = score;
        bestDistance = distance;
      }
    }
    return bestIndex;
  }

  /// A single heard word can only confirm the very next word or two.
  double _requiredScore(List<String> tail, double threshold) =>
      tail.length == 1 ? 1.0 : threshold;

  /// Scores the heard tail against the script words ending at [endIndex].
  double _alignmentScore(List<String> tail, int endIndex) {
    final isOutsideSingleWordReach = endIndex <= _currentIndex || endIndex > _currentIndex + 2;
    if (tail.length == 1 && isOutsideSingleWordReach) return 0;
    var score = 0.0;
    for (var offset = 0; offset < tail.length; offset++) {
      final scriptIndex = endIndex - offset;
      if (scriptIndex < 0) break;
      final heardWord = tail[tail.length - 1 - offset];
      if (_wordsMatch(heardWord, words[scriptIndex].normalized)) {
        score += _commonWords.contains(heardWord) ? _commonWordWeight : 1.0;
      }
    }
    return score;
  }

  /// Exact, or one typo apart for longer words (recognisers often slip a letter).
  static bool _wordsMatch(String heard, String scripted) {
    if (heard == scripted) return true;
    if (heard.length < 5 || scripted.length < 5) return false;
    return _isWithinOneEdit(heard, scripted);
  }

  static bool _isWithinOneEdit(String a, String b) {
    if ((a.length - b.length).abs() > 1) return false;
    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > 1) return false;
      if (a.length > b.length) {
        i++;
      } else if (b.length > a.length) {
        j++;
      } else {
        i++;
        j++;
      }
    }
    return edits + (a.length - i) + (b.length - j) <= 1;
  }

  /// Lowercases, drops punctuation and apostrophes, and writes small numbers as digits.
  static List<String> normalizeWords(String text) => RegExp(r"[A-Za-z0-9'’]+")
      .allMatches(text)
      .map((m) => _normalizeWord(m.group(0)!))
      .where((w) => w.isNotEmpty)
      .toList();

  static String _normalizeWord(String word) {
    final plain = word.toLowerCase().replaceAll(RegExp(r"['’]"), '');
    return _numberWords[plain] ?? plain;
  }

  static List<ScriptWord> _indexWords(String content) {
    final result = <ScriptWord>[];
    final paragraphs = content.split('\n');
    for (var p = 0; p < paragraphs.length; p++) {
      final line = paragraphs[p];
      if (_isMarkerLine(line)) continue;
      for (final match in RegExp(r"[A-Za-z0-9'’]+").allMatches(line)) {
        final normalized = _normalizeWord(match.group(0)!);
        if (normalized.isEmpty) continue;
        result.add(ScriptWord(paragraphIndex: p, charOffset: match.start, normalized: normalized));
      }
    }
    return result;
  }

  static bool _isMarkerLine(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('[') && trimmed.endsWith(']');
  }
}
